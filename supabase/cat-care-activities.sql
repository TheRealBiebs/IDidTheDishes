begin;
alter table public.households add column cat_care_mode text not null default 'points' check(cat_care_mode in('points','chores'));
alter table public.households add column cat_activity_chores jsonb not null default '{}' check(jsonb_typeof(cat_activity_chores)='object');
alter table app_private.cat_weeks add column care_plans jsonb not null default '[{"mode":"points"},{"mode":"points"},{"mode":"points"},{"mode":"points"},{"mode":"points"},{"mode":"points"},{"mode":"points"}]' check(jsonb_typeof(care_plans)='array' and jsonb_array_length(care_plans)=7);

create function app_private.cat_day_progress(p_week app_private.cat_weeks,p_day date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare plan jsonb;mode text;points bigint;target integer;actions jsonb;all_done boolean;begin
 if p_day<p_week.week_start or p_day>=p_week.week_start+7 then raise exception 'Choose a day in this cat week.';end if;
 plan:=p_week.care_plans->(p_day-p_week.week_start);mode:=coalesce(plan->>'mode','points');
 points:=app_private.cat_day_points(p_week.household_id,p_week.user_id,p_day);target:=p_week.targets[p_day-p_week.week_start+1];
 select jsonb_agg(jsonb_build_object('action',action,'chore_id',case when mode='chores' then plan#>>array['chores',action] else null end,
 'chore',case when mode='chores' then coalesce((select chore from public.chore_tags where id=(plan#>>array['chores',action])::uuid),'Unavailable chore') else null end,
 'unlocked',case when mode='chores' then exists(select 1 from public.chore_completions c where c.household_id=p_week.household_id and c.user_id=p_week.user_id and c.chore_date=p_day and c.tag_id=(plan#>>array['chores',action])::uuid) else points>=target*fraction end) order by ord)
 into actions from(values('feed',.25,1),('play',.5,2),('cuddle',.75,3))v(action,fraction,ord);
 all_done:=case when mode='chores' then not exists(select 1 from jsonb_array_elements(actions)a where not (a->>'unlocked')::boolean) else points>=target end;
 return jsonb_build_object('care_mode',mode,'points',points,'target',target,'activities',actions,'satisfied',all_done);
end $$;
create or replace function app_private.cat_satisfied_days(p_week app_private.cat_weeks) returns integer
language sql stable security definer set search_path='' as $$
select count(*)::integer from generate_series(0,6)i where p_week.week_start+i>=p_week.eligible_from
and p_week.week_start+i<=(now() at time zone p_week.timezone)::date
and (app_private.cat_day_progress(p_week,p_week.week_start+i)->>'satisfied')::boolean
$$;
create or replace function app_private.cat_dashboard(p_household uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare h public.households;u uuid;d date;w date;result jsonb;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household to see its cats.';end if;
 if h.reward_scheme<>'cats' then raise exception 'Choose cat mode to care for cats.';end if;
 d:=(now() at time zone h.timezone)::date;w:=date_trunc('week',d::timestamp)::date;
 for u in select user_id from public.household_members where household_id=p_household loop perform app_private.ensure_cat_week(p_household,u);end loop;
 perform app_private.settle_cat_weeks(p_household);
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'user_id',c.user_id,'name',m.display_name,'variant',c.variant,'cat_name',c.cat_name,'required_days',c.required_days,'companion_id',c.companion_id,'eligible_from',c.eligible_from,
 'actions',coalesce((select to_jsonb(actions) from app_private.cat_care where week_id=c.id and day=d),'[]'::jsonb),
 'days',(select jsonb_agg(jsonb_build_object('day',w+i,'eligible',w+i>=c.eligible_from)||app_private.cat_day_progress(c,w+i)||jsonb_build_object('satisfied',w+i>=c.eligible_from and w+i<=d and (app_private.cat_day_progress(c,w+i)->>'satisfied')::boolean) order by i) from generate_series(0,6)i))||app_private.cat_day_progress(c,d)
 order by m.joined_at,c.user_id),'[]'::jsonb) into result from app_private.cat_weeks c join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household and c.week_start=w;
 return jsonb_build_object('day',d,'week_start',w,'timezone',h.timezone,'target',h.cat_daily_target,'required_days',h.cat_required_days,'care_mode',h.cat_care_mode,'cats',result);
end $$;
create or replace function app_private.care_for_cat(p_household uuid,p_action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare h public.households;c app_private.cat_weeks;d date;progress jsonb;unlocked boolean;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) or h.reward_scheme<>'cats' then raise exception 'Join this household in cat mode first.';end if;
 if p_action is null or p_action not in('feed','play','cuddle') then raise exception 'Choose feed, play or cuddle.';end if;
 select * into c from app_private.cat_weeks where id=app_private.ensure_cat_week(p_household,auth.uid()) for update;
 d:=(now() at time zone h.timezone)::date;progress:=app_private.cat_day_progress(c,d);
 select (a->>'unlocked')::boolean into unlocked from jsonb_array_elements(progress->'activities')a where a->>'action'=p_action;
 if unlocked is not true then raise exception 'Complete the required chores to unlock this activity.';end if;
 -- Optional activity clicks never affect whether a day or trophy is earned.
 insert into app_private.cat_care(week_id,day,actions) values(c.id,d,array[p_action]) on conflict(week_id,day) do update set actions=case when p_action=any(app_private.cat_care.actions) then app_private.cat_care.actions else array_append(app_private.cat_care.actions,p_action) end;
 return app_private.cat_dashboard(p_household);
end $$;
create function app_private.save_cat_care_settings(p_household uuid,p_target integer,p_days integer,p_mode text,p_chores jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare h public.households;d date;action text;plan jsonb;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can configure cat care.';end if;
 if p_mode is null or p_mode not in('points','chores') or p_chores is null or jsonb_typeof(p_chores)<>'object' then raise exception 'Choose a cat care mode.';end if;
 if exists(select 1 from jsonb_object_keys(p_chores)k where k not in('feed','play','cuddle')) then raise exception 'Choose feed, play and cuddle chores only.';end if;
 if p_mode='chores' then
  foreach action in array array['feed','play','cuddle'] loop
   if coalesce(p_chores->>action,'') !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' then raise exception 'Choose a household chore for each cat activity.';end if;
   if not exists(select 1 from public.chore_tags where id=(p_chores->>action)::uuid and household_id=p_household and deleted_at is null) then raise exception 'Each cat activity must use an available chore from this household.';end if;
  end loop;
 end if;
 perform app_private.set_cat_daily_target(p_household,p_target);
 perform app_private.set_cat_required_days(p_household,p_days);
 update public.households set cat_care_mode=p_mode,cat_activity_chores=case when p_mode='chores' then p_chores else cat_activity_chores end where id=p_household;
 d:=(now() at time zone h.timezone)::date;plan:=jsonb_build_object('mode',p_mode,'chores',p_chores);
 update app_private.cat_weeks c set care_plans=(select jsonb_agg(case when c.week_start+i>=d then plan else c.care_plans->i end order by i) from generate_series(0,6)i)
 where household_id=p_household and week_start<=d and week_start+7>d and finalized_at is null;
end $$;
create function public.save_cat_care_settings(p_household uuid,p_target integer,p_days integer,p_mode text,p_chores jsonb) returns void
language sql security invoker set search_path='' as $$select app_private.save_cat_care_settings(p_household,p_target,p_days,p_mode,p_chores)$$;
revoke all on function app_private.cat_day_progress(app_private.cat_weeks,date),app_private.save_cat_care_settings(uuid,integer,integer,text,jsonb),public.save_cat_care_settings(uuid,integer,integer,text,jsonb) from public,anon,authenticated;
grant execute on function app_private.save_cat_care_settings(uuid,integer,integer,text,jsonb),public.save_cat_care_settings(uuid,integer,integer,text,jsonb) to authenticated;
CREATE OR REPLACE FUNCTION app_private.ensure_cat_week(p_household uuid, p_user uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare h public.households;m public.household_members;d date;w date;result uuid;previous app_private.cat_weeks;begin
 select * into h from public.households where id=p_household;
 if h.reward_scheme<>'cats' then return null;end if;
 select * into m from public.household_members where household_id=p_household and user_id=p_user;
 if not found then return null;end if;
 d:=(now() at time zone h.timezone)::date;w:=date_trunc('week',d::timestamp)::date;
 select id into result from app_private.cat_weeks where household_id=p_household and user_id=p_user and week_start=w;
 if result is not null then return result;end if;
 perform app_private.settle_cat_weeks(p_household);
 select * into previous from app_private.cat_weeks where household_id=p_household and user_id=p_user and week_start<w order by week_start desc limit 1;
 insert into app_private.cat_weeks(household_id,user_id,week_start,eligible_from,variant,targets,timezone,required_days,companion_id,cat_name,care_plans)
 values(p_household,p_user,w,greatest(w,(m.joined_at at time zone h.timezone)::date,(coalesce(h.cat_enabled_at,now()) at time zone h.timezone)::date),
 case when previous.id is not null and previous.earned_at is null then previous.variant else floor(random()*28)::smallint end,array_fill(h.cat_daily_target,array[7]),h.timezone,h.cat_required_days,
 case when previous.id is not null and previous.earned_at is null then previous.companion_id else gen_random_uuid() end,
 case when previous.id is not null and previous.earned_at is null then previous.cat_name else '' end,
 (select jsonb_agg(jsonb_build_object('mode',h.cat_care_mode,'chores',h.cat_activity_chores) order by i) from generate_series(0,6)i))
 on conflict(household_id,user_id,week_start) do nothing;
 select id into result from app_private.cat_weeks where household_id=p_household and user_id=p_user and week_start=w;
 return result;
end $function$;
commit;
