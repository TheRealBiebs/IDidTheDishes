create or replace function app_private.reassign_sticker(p_token uuid,p_chore uuid) returns void
language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory; target public.chore_tags;
begin
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found or s.household_id is null then raise exception 'This sticker is not claimed.';end if;
 perform 1 from public.households where id=s.household_id for no key update;
 if not app_private.is_admin(s.household_id) then raise exception 'Only its current household admin can reassign this sticker.';end if;
 select * into target from public.chore_tags where id=p_chore and household_id=s.household_id and deleted_at is null for update;
 if not found then raise exception 'Choose a chore in this household.';end if;
 if s.chore_tag_id=p_chore then return;end if;
 if exists(select 1 from app_private.sticker_inventory where chore_tag_id=p_chore) then raise exception 'That chore already has a sticker. Release it before assigning a different one.';end if;
 -- Move only the physical binding: both chores retain their configuration/history.
 update public.chore_tags set token=gen_random_uuid() where id=s.chore_tag_id;
 update public.chore_tags set token=p_token where id=p_chore;
 update app_private.sticker_inventory set chore_tag_id=p_chore,generation=generation+1 where token=p_token;
 update public.sticker_release_requests set status='obsolete',reviewed_at=now() where token=p_token and status='pending';
end $$;
create or replace function public.reassign_sticker(p_token uuid,p_chore uuid) returns void language sql security invoker set search_path='' as $$select app_private.reassign_sticker(p_token,p_chore)$$;
revoke all on function app_private.reassign_sticker(uuid,uuid),public.reassign_sticker(uuid,uuid) from public,anon;
grant execute on function app_private.reassign_sticker(uuid,uuid),public.reassign_sticker(uuid,uuid) to authenticated;

-- Person assignments and team assignments feed the same dashboard lists.
create or replace function app_private.chore_schedule(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d date;my_team uuid;result jsonb;enabled boolean;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 select (now() at time zone timezone)::date,teams_enabled into d,enabled from public.households where id=p_household;
 select team_id into my_team from public.household_members where household_id=p_household and user_id=auth.uid();
 select coalesce(jsonb_agg(to_jsonb(s) order by s.chore),'[]') into result from (
  select t.id,t.chore,t.location,t.frequency,case when enabled then t.assigned_team_id else null end as assigned_team_id,t.eligible_users,t.active,t.points,t.daily_limit,
   periods.start_date as period_start,
   (case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end) as period_end,
   counts.done,greatest(0,t.daily_limit-counts.done) as remaining,
   (((enabled and t.assigned_team_id is not null) or cardinality(t.eligible_users)>0)
     and (not enabled or t.assigned_team_id is null or t.assigned_team_id=my_team)
     and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as assigned_to_me,
   ((not enabled or t.assigned_team_id is null or t.assigned_team_id=my_team)
     and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as eligible
  from public.chore_tags t
  cross join lateral (select app_private.chore_period_start(d,t.frequency) as start_date) periods
  cross join lateral (select count(*)::integer as done from public.chore_completions c where c.tag_id=t.id and c.chore_date>=periods.start_date and c.chore_date<(case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end)) counts
  where t.household_id=p_household and t.deleted_at is null
 )s;
 return result;
end $$;
