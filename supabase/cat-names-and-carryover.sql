begin;
alter table public.households add column cat_required_days integer not null default 7 check(cat_required_days between 1 and 7);
alter table app_private.cat_weeks add column companion_id uuid not null default gen_random_uuid();
alter table app_private.cat_weeks add column cat_name text not null default '' check(length(cat_name)<=40);
alter table app_private.cat_weeks add column required_days integer not null default 7 check(required_days between 1 and 7);
alter table app_private.cat_weeks add column award_points bigint;
alter table app_private.cat_weeks add column award_chores integer;
alter table app_private.cat_weeks add column award_days integer;
create index cat_companion_lookup on app_private.cat_weeks(companion_id);

create or replace function app_private.settle_cat_weeks(p_household uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 update app_private.cat_weeks w set earned_at=case when app_private.cat_satisfied_days(w)>=w.required_days then now() else null end,finalized_at=now(),
 award_days=app_private.cat_satisfied_days(w),award_points=(select coalesce(sum(points),0) from public.chore_completions where household_id=w.household_id and user_id=w.user_id and chore_date>=w.week_start and chore_date<w.week_start+7),
 award_chores=(select count(*) from public.chore_completions where household_id=w.household_id and user_id=w.user_id and chore_date>=w.week_start and chore_date<w.week_start+7)
 where household_id=p_household and finalized_at is null and week_start+7<=(now() at time zone timezone)::date;
end $$;
create or replace function app_private.ensure_cat_week(p_household uuid,p_user uuid) returns uuid
language plpgsql security definer set search_path='' as $$
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
 insert into app_private.cat_weeks(household_id,user_id,week_start,eligible_from,variant,targets,timezone,required_days,companion_id,cat_name)
 values(p_household,p_user,w,greatest(w,(m.joined_at at time zone h.timezone)::date,(coalesce(h.cat_enabled_at,now()) at time zone h.timezone)::date),
 case when previous.id is not null and previous.earned_at is null then previous.variant else floor(random()*28)::smallint end,array_fill(h.cat_daily_target,array[7]),h.timezone,h.cat_required_days,
 case when previous.id is not null and previous.earned_at is null then previous.companion_id else gen_random_uuid() end,
 case when previous.id is not null and previous.earned_at is null then previous.cat_name else '' end)
 on conflict(household_id,user_id,week_start) do nothing;
 select id into result from app_private.cat_weeks where household_id=p_household and user_id=p_user and week_start=w;
 return result;
end $$;
create function app_private.name_cat(p_household uuid,p_name text) returns jsonb
language plpgsql security definer set search_path='' as $$declare c app_private.cat_weeks;begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if p_name is null or length(trim(p_name)) not between 1 and 40 then raise exception 'Choose a cat name from 1 to 40 characters.';end if;
 select * into c from app_private.cat_weeks where id=app_private.ensure_cat_week(p_household,auth.uid());
 if not found then raise exception 'Choose cat mode to name your companion.';end if;
 update app_private.cat_weeks set cat_name=trim(p_name) where companion_id=c.companion_id and user_id=auth.uid() and earned_at is null;
 return app_private.cat_dashboard(p_household);
end $$;
create function app_private.set_cat_required_days(p_household uuid,p_days integer) returns void
language plpgsql security definer set search_path='' as $$declare d date;zone text;begin
 select timezone into zone from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can set qualifying days.';end if;
 if p_days is null or p_days not between 1 and 7 then raise exception 'Choose 1 to 7 qualifying days.';end if;
 d:=(now() at time zone zone)::date;
 update public.households set cat_required_days=p_days where id=p_household;
 update app_private.cat_weeks set required_days=p_days where household_id=p_household and week_start<=d and week_start+7>d and finalized_at is null;
end $$;
create function public.name_cat(p_household uuid,p_name text) returns jsonb language sql security invoker set search_path='' as $$select app_private.name_cat(p_household,p_name)$$;
create function public.set_cat_required_days(p_household uuid,p_days integer) returns void language sql security invoker set search_path='' as $$select app_private.set_cat_required_days(p_household,p_days)$$;
revoke all on function app_private.name_cat(uuid,text),app_private.set_cat_required_days(uuid,integer),public.name_cat(uuid,text),public.set_cat_required_days(uuid,integer) from public,anon;
grant execute on function app_private.name_cat(uuid,text),app_private.set_cat_required_days(uuid,integer),public.name_cat(uuid,text),public.set_cat_required_days(uuid,integer) to authenticated;
commit;
