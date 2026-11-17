begin;
alter table public.households add column cat_daily_target integer not null default 20 check(cat_daily_target between 1 and 10000);
alter table public.households add column cat_enabled_at timestamptz;
update public.households set cat_enabled_at=now() where reward_scheme='cats';
create table app_private.cat_weeks(
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households on delete cascade,
 user_id uuid not null references auth.users on delete cascade,week_start date not null,eligible_from date not null,
 variant smallint not null check(variant between 0 and 27),targets integer[] not null check(cardinality(targets)=7),
 timezone text not null,earned_at timestamptz,finalized_at timestamptz,unique(household_id,user_id,week_start)
);
create index cat_weeks_user on app_private.cat_weeks(user_id);
create index cat_weeks_unsettled on app_private.cat_weeks(household_id,week_start) where finalized_at is null;
create table app_private.cat_care(
 week_id uuid not null references app_private.cat_weeks on delete cascade,day date not null,
 actions text[] not null default '{}',primary key(week_id,day)
);
alter table app_private.cat_weeks enable row level security;
alter table app_private.cat_care enable row level security;
revoke all on app_private.cat_weeks,app_private.cat_care from public,anon,authenticated;

create function app_private.ensure_cat_week(p_household uuid,p_user uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare h public.households;m public.household_members;d date;w date;result uuid;
begin
 select * into h from public.households where id=p_household;
 if h.reward_scheme<>'cats' then return null;end if;
 select * into m from public.household_members where household_id=p_household and user_id=p_user;
 if not found then return null;end if;
 d:=(now() at time zone h.timezone)::date;w:=date_trunc('week',d::timestamp)::date;
 insert into app_private.cat_weeks(household_id,user_id,week_start,eligible_from,variant,targets,timezone)
 values(p_household,p_user,w,greatest(w,(m.joined_at at time zone h.timezone)::date,(coalesce(h.cat_enabled_at,now()) at time zone h.timezone)::date),floor(random()*28)::smallint,array_fill(h.cat_daily_target,array[7]),h.timezone)
 on conflict(household_id,user_id,week_start) do nothing;
 select id into result from app_private.cat_weeks where household_id=p_household and user_id=p_user and week_start=w;
 return result;
end $$;
create function app_private.cat_day_points(p_household uuid,p_user uuid,p_day date) returns bigint
language sql stable security definer set search_path='' as $$
 select greatest(0,coalesce(sum(points),0))::bigint from public.chore_completions where household_id=p_household and user_id=p_user and chore_date=p_day
$$;
create function app_private.cat_satisfied_days(p_week app_private.cat_weeks) returns integer
language sql stable security definer set search_path='' as $$
 select count(*)::integer from generate_series(0,6) i where p_week.week_start+i>=p_week.eligible_from
 and app_private.cat_day_points(p_week.household_id,p_week.user_id,p_week.week_start+i)>=p_week.targets[i+1]
$$;
create function app_private.settle_cat_weeks(p_household uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 update app_private.cat_weeks w set earned_at=case when app_private.cat_satisfied_days(w)=7 then now() else null end,finalized_at=now()
 where household_id=p_household and finalized_at is null and week_start+7<=(now() at time zone timezone)::date;
end $$;
create function app_private.cat_mode_started() returns trigger
language plpgsql set search_path='' as $$begin
 if new.reward_scheme='cats' and (tg_op='INSERT' or old.reward_scheme is distinct from 'cats') then new.cat_enabled_at:=now();end if;
 return new;
end $$;
create trigger cat_mode_started before insert or update of reward_scheme on public.households for each row execute function app_private.cat_mode_started();
create function app_private.seed_cat_companions() returns trigger
language plpgsql security definer set search_path='' as $$declare h uuid;u uuid;begin
 if tg_table_name='households' then h:=new.id;else h:=new.household_id;end if;
 if tg_table_name='households' then
  for u in select user_id from public.household_members where household_id=h loop perform app_private.ensure_cat_week(h,u);end loop;
 else perform app_private.ensure_cat_week(h,new.user_id);end if;
 return null;
end $$;
create trigger seed_cat_household after update of reward_scheme on public.households for each row when(new.reward_scheme='cats') execute function app_private.seed_cat_companions();
create trigger seed_cat_member after insert on public.household_members for each row execute function app_private.seed_cat_companions();

create function app_private.set_cat_daily_target(p_household uuid,p_target integer) returns void
language plpgsql security definer set search_path='' as $$declare h public.households;u uuid;d date;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can set the cat target.';end if;
 if p_target is null or p_target not between 1 and 10000 then raise exception 'Choose a daily target from 1 to 10000 points.';end if;
 d:=(now() at time zone h.timezone)::date;
 for u in select user_id from public.household_members where household_id=p_household loop perform app_private.ensure_cat_week(p_household,u);end loop;
 update app_private.cat_weeks w set targets=array(select case when w.week_start+i-1>=d then p_target else w.targets[i] end from generate_series(1,7) i order by i)
 where household_id=p_household and week_start<=d and week_start+7>d and finalized_at is null;
 update public.households set cat_daily_target=p_target where id=p_household;
end $$;
create function app_private.cat_dashboard(p_household uuid) returns jsonb
language plpgsql security definer set search_path='' as $$declare h public.households;u uuid;d date;w date;result jsonb;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household to see its cats.';end if;
 if h.reward_scheme<>'cats' then raise exception 'Choose cat mode to care for cats.';end if;
 d:=(now() at time zone h.timezone)::date;w:=date_trunc('week',d::timestamp)::date;
 for u in select user_id from public.household_members where household_id=p_household loop perform app_private.ensure_cat_week(p_household,u);end loop;
 perform app_private.settle_cat_weeks(p_household);
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'user_id',c.user_id,'name',m.display_name,'variant',c.variant,'eligible_from',c.eligible_from,
 'points',app_private.cat_day_points(p_household,c.user_id,d),'target',c.targets[d-w+1],
 'actions',coalesce((select to_jsonb(actions) from app_private.cat_care where week_id=c.id and day=d),'[]'::jsonb),
 'days',(select jsonb_agg(jsonb_build_object('day',w+i,'eligible',w+i>=c.eligible_from,'points',app_private.cat_day_points(p_household,c.user_id,w+i),'target',c.targets[i+1],'satisfied',w+i>=c.eligible_from and w+i<=d and app_private.cat_day_points(p_household,c.user_id,w+i)>=c.targets[i+1]) order by i) from generate_series(0,6) i)) order by m.joined_at,c.user_id),'[]'::jsonb)
 into result from app_private.cat_weeks c join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household and c.week_start=w;
 return jsonb_build_object('day',d,'week_start',w,'target',h.cat_daily_target,'cats',result);
end $$;
create function app_private.care_for_cat(p_household uuid,p_action text) returns jsonb
language plpgsql security definer set search_path='' as $$declare h public.households;c app_private.cat_weeks;d date;required numeric;points bigint;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) or h.reward_scheme<>'cats' then raise exception 'Join this household in cat mode first.';end if;
 required:=case p_action when 'feed' then .25 when 'play' then .5 when 'cuddle' then .75 end;
 if required is null then raise exception 'Choose feed, play or cuddle.';end if;
 select * into c from app_private.cat_weeks where id=app_private.ensure_cat_week(p_household,auth.uid()) for update;
 d:=(now() at time zone h.timezone)::date;points:=app_private.cat_day_points(p_household,auth.uid(),d);
 if points>=c.targets[d-c.week_start+1] then raise exception 'Your cat is satisfied and sleeping until tomorrow.';end if;
 if points<c.targets[d-c.week_start+1]*required then raise exception 'Do more chores to unlock this activity.';end if;
 insert into app_private.cat_care(week_id,day,actions) values(c.id,d,array[p_action]) on conflict(week_id,day) do update set actions=case when p_action=any(app_private.cat_care.actions) then app_private.cat_care.actions else array_append(app_private.cat_care.actions,p_action) end;
 return app_private.cat_dashboard(p_household);
end $$;
create function public.cat_dashboard(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.cat_dashboard(p_household)$$;
create function public.care_for_cat(p_household uuid,p_action text) returns jsonb language sql security invoker set search_path='' as $$select app_private.care_for_cat(p_household,p_action)$$;
create function public.set_cat_daily_target(p_household uuid,p_target integer) returns void language sql security invoker set search_path='' as $$select app_private.set_cat_daily_target(p_household,p_target)$$;
revoke all on function app_private.ensure_cat_week(uuid,uuid),app_private.cat_day_points(uuid,uuid,date),app_private.cat_satisfied_days(app_private.cat_weeks),app_private.settle_cat_weeks(uuid),app_private.cat_mode_started(),app_private.seed_cat_companions(),app_private.cat_dashboard(uuid),app_private.care_for_cat(uuid,text),app_private.set_cat_daily_target(uuid,integer),public.cat_dashboard(uuid),public.care_for_cat(uuid,text),public.set_cat_daily_target(uuid,integer) from public,anon,authenticated;
grant execute on function app_private.cat_dashboard(uuid),app_private.care_for_cat(uuid,text),app_private.set_cat_daily_target(uuid,integer),public.cat_dashboard(uuid),public.care_for_cat(uuid,text),public.set_cat_daily_target(uuid,integer) to authenticated;
do $$declare member_row record;begin for member_row in select hm.household_id,hm.user_id from public.household_members hm join public.households h on h.id=hm.household_id where h.reward_scheme='cats' loop perform app_private.ensure_cat_week(member_row.household_id,member_row.user_id);end loop;end $$;
commit;
