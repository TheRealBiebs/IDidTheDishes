begin;
alter table public.households add column reward_scheme text not null default 'points'
 check (reward_scheme in ('points','stars','adventure'));

create function app_private.set_reward_scheme(p_household uuid,p_scheme text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can change its reward system.'; end if;
 if p_scheme is null or p_scheme not in ('points','stars','adventure') then raise exception 'Choose a supported reward system.'; end if;
 update public.households set reward_scheme=p_scheme where id=p_household;
end $$;
create function public.set_reward_scheme(p_household uuid,p_scheme text) returns void
language sql security invoker set search_path='' as $$select app_private.set_reward_scheme(p_household,p_scheme)$$;
revoke all on function app_private.set_reward_scheme(uuid,text),public.set_reward_scheme(uuid,text) from public,anon;
grant execute on function app_private.set_reward_scheme(uuid,text),public.set_reward_scheme(uuid,text) to authenticated;

-- Aggregate the whole month in Postgres: calendar totals must not depend on a
-- browser's limited recent-activity list. Existing SELECT RLS also applies here.
create function app_private.reward_calendar(p_household uuid,p_month date) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare start_day date; result jsonb;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.'; end if;
 if p_month is null then raise exception 'Choose a calendar month.'; end if;
 start_day := date_trunc('month',p_month::timestamp)::date;
 select coalesce(jsonb_agg(to_jsonb(s) order by s.day,s.chore,s.user_id),'[]'::jsonb) into result
 from (
  select chore_date as day,tag_id,user_id,chore,count(*) as stars
  from public.chore_completions
  where household_id=p_household and chore_date>=start_day and chore_date<(start_day+interval '1 month')::date
  group by chore_date,tag_id,user_id,chore
 ) s;
 return result;
end $$;
create function public.reward_calendar(p_household uuid,p_month date) returns jsonb
language sql security invoker set search_path='' as $$select app_private.reward_calendar(p_household,p_month)$$;
revoke all on function app_private.reward_calendar(uuid,date),public.reward_calendar(uuid,date) from public,anon;
grant execute on function app_private.reward_calendar(uuid,date),public.reward_calendar(uuid,date) to authenticated;

-- Keep the canonical completion record, all eligibility checks, household limits,
-- and idempotency. Only the notification's reward wording changes.
create or replace function app_private.complete_chore(p_token uuid,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer; scheme text; suffix text;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select * into t from public.chore_tags where token=p_token for update;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'Join this sticker’s household before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id<>t.id then raise exception 'This scan request was already used.'; end if;
  return to_jsonb(c);
 end if;
 if not t.active then raise exception 'This sticker is paused.'; end if;
 if cardinality(t.eligible_users)>0 and not auth.uid()=any(t.eligible_users) then raise exception 'This chore is assigned to other household members.'; end if;
 select (now() at time zone timezone)::date,reward_scheme into d,scheme from public.households where id=t.household_id;
 select count(*) into count_today from public.chore_completions where tag_id=t.id and chore_date=d;
 if count_today>=t.daily_limit then raise exception 'This chore has reached its household limit for today.'; end if;
 if exists(select 1 from public.chore_completions where tag_id=t.id and user_id=auth.uid() and completed_at>now()-interval '30 seconds') then raise exception 'Already logged just now. Wait 30 seconds before another completion.'; end if;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id)
 values(t.household_id,t.id,auth.uid(),t.chore,t.points,d,p_request) returning * into c;
 select display_name into n from public.household_members where household_id=t.household_id and user_id=auth.uid();
 suffix := case scheme when 'stars' then ' (+1 gold star)' when 'adventure' then '' else ' (+'||t.points||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||suffix from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $$;
commit;
