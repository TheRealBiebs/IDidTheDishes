begin;
alter table public.chore_tags add column frequency text not null default 'daily' check(frequency in ('daily','weekly','monthly'));
alter table public.chore_tags add column assigned_team_id uuid references public.household_teams(id) on delete set null;
create index chore_assigned_team_idx on public.chore_tags(assigned_team_id) where assigned_team_id is not null;

create function app_private.chore_period_start(p_day date,p_frequency text) returns date
language sql immutable set search_path='' as $$
 select case p_frequency when 'weekly' then date_trunc('week',p_day::timestamp)::date when 'monthly' then date_trunc('month',p_day::timestamp)::date else p_day end
$$;
revoke all on function app_private.chore_period_start(date,text) from public,anon,authenticated;

create function app_private.configure_chore_schedule(p_household uuid,p_tag uuid,p_frequency text,p_team uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can assign or schedule chores.';end if;
 if p_frequency is null or p_frequency not in ('daily','weekly','monthly') then raise exception 'Choose a daily, weekly, or monthly schedule.';end if;
 if p_team is not null and not exists(select 1 from public.household_teams where id=p_team and household_id=p_household and active) then raise exception 'Choose an active team from this household.';end if;
 update public.chore_tags set frequency=p_frequency,assigned_team_id=p_team where id=p_tag and household_id=p_household;
 if not found then raise exception 'Chore not found.';end if;
end $$;
revoke all on function app_private.configure_chore_schedule(uuid,uuid,text,uuid) from public,anon,authenticated;

create function app_private.save_scheduled_chore(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if p_frequency<>'daily' and p_limit<>1 then raise exception 'Weekly and monthly chores can be completed once per period.';end if;
 result:=app_private.save_tag_with_cooldown(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes);
 perform app_private.configure_chore_schedule(p_household,result,p_frequency,p_team);
 return result;
end $$;
create function public.save_scheduled_chore(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language sql security invoker set search_path='' as $$select app_private.save_scheduled_chore(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team)$$;

create function app_private.claim_scheduled_sticker(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if p_frequency<>'daily' and p_limit<>1 then raise exception 'Weekly and monthly chores can be completed once per period.';end if;
 result:=app_private.claim_sticker_with_cooldown(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes);
 perform app_private.configure_chore_schedule(p_household,result,p_frequency,p_team);
 return result;
end $$;
create function public.claim_scheduled_sticker(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language sql security invoker set search_path='' as $$select app_private.claim_scheduled_sticker(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team)$$;

create function app_private.chore_schedule(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d date;my_team uuid;result jsonb;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 select (now() at time zone timezone)::date into d from public.households where id=p_household;
 select team_id into my_team from public.household_members where household_id=p_household and user_id=auth.uid();
 select coalesce(jsonb_agg(to_jsonb(s) order by s.chore),'[]') into result from (
  select t.id,t.chore,t.location,t.frequency,t.assigned_team_id,t.active,t.points,t.daily_limit,
   periods.start_date as period_start,
   (case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end) as period_end,
   counts.done, greatest(0,t.daily_limit-counts.done) as remaining,
   (t.assigned_team_id=my_team and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as assigned_to_me,
   ((t.assigned_team_id is null or t.assigned_team_id=my_team) and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as eligible
  from public.chore_tags t
  cross join lateral (select app_private.chore_period_start(d,t.frequency) as start_date) periods
  cross join lateral (select count(*)::integer as done from public.chore_completions c where c.tag_id=t.id and c.chore_date>=periods.start_date and c.chore_date<(case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end)) counts
  where t.household_id=p_household
 )s;
 return result;
end $$;
create function public.chore_schedule(p_household uuid) returns jsonb
language sql security invoker set search_path='' as $$select app_private.chore_schedule(p_household)$$;

revoke all on function app_private.save_scheduled_chore(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),public.save_scheduled_chore(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),app_private.claim_scheduled_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),public.claim_scheduled_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),app_private.chore_schedule(uuid),public.chore_schedule(uuid) from public,anon;
grant execute on function app_private.save_scheduled_chore(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),public.save_scheduled_chore(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),app_private.claim_scheduled_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),public.claim_scheduled_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid),app_private.chore_schedule(uuid),public.chore_schedule(uuid) to authenticated;

-- The completion function below keeps inventory/tag locks and retry idempotency.
CREATE OR REPLACE FUNCTION app_private.complete_chore(p_token uuid, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer; scheme text; suffix text; cooldown integer; last_completed timestamptz; wait_minutes integer;period_start date;period_end date;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 perform 1 from app_private.sticker_inventory where token=p_token and chore_tag_id is not null for update;
 if not found then raise exception 'This sticker is unassigned or is not a valid issued sticker.';end if;
 select * into t from public.chore_tags where id=(select chore_tag_id from app_private.sticker_inventory where token=p_token) for update;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'Join the household for this sticker before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id is distinct from t.id then raise exception 'This scan request was already used.'; end if;
  return to_jsonb(c);
 end if;
 if t.assigned_team_id is not null and not exists(select 1 from public.household_members where household_id=t.household_id and user_id=auth.uid() and team_id=t.assigned_team_id) then raise exception 'This chore is assigned to another team.';end if;
 if not t.active then raise exception 'This sticker is paused.'; end if;
 if cardinality(t.eligible_users)>0 and not auth.uid()=any(t.eligible_users) then raise exception 'This chore is assigned to other household members.'; end if;
 select (now() at time zone timezone)::date,reward_scheme into d,scheme from public.households where id=t.household_id;
 period_start:=app_private.chore_period_start(d,t.frequency);
 period_end:=case t.frequency when 'weekly' then period_start+7 when 'monthly' then (period_start+interval '1 month')::date else period_start+1 end;
 select count(*) into count_today from public.chore_completions where tag_id=t.id and chore_date>=period_start and chore_date<period_end;
 if count_today>=t.daily_limit then raise exception 'This chore has reached its household limit for %.',case t.frequency when 'weekly' then 'this week' when 'monthly' then 'this month' else 'today' end; end if;
 -- The tag row is already locked, so simultaneous scans share one cooldown.
 cooldown:=case when t.frequency='daily' then app_private.chore_cooldown_minutes(t.daily_limit,t.cooldown_minutes) else 0 end;
 if cooldown>0 then
  select completed_at into last_completed from public.chore_completions where tag_id=t.id order by completed_at desc limit 1;
  if last_completed+make_interval(mins=>cooldown)>now() then
   wait_minutes:=greatest(1,ceil(extract(epoch from (last_completed+make_interval(mins=>cooldown)-now()))/60)::integer);
   raise exception 'This chore is cooling down. Try again in %.',case when wait_minutes>=60 then (wait_minutes/60)::text||'h'||case when wait_minutes%60>0 then ' '||(wait_minutes%60)::text||'m' else '' end else wait_minutes::text||'m' end;
  end if;
 end if;
 if exists(select 1 from public.chore_completions where tag_id=t.id and user_id=auth.uid() and completed_at>now()-interval '30 seconds') then raise exception 'Already logged just now. Wait 30 seconds before another completion.'; end if;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id)
 values(t.household_id,t.id,auth.uid(),t.chore,t.points,d,p_request) returning * into c;
 select display_name into n from public.household_members where household_id=t.household_id and user_id=auth.uid();
 suffix := case scheme when 'stars' then ' (+1 gold star)' when 'adventure' then '' else ' (+'||t.points||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||suffix from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $function$
;


notify pgrst, 'reload schema';
commit;
