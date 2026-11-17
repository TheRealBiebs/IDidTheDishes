begin;
CREATE OR REPLACE FUNCTION app_private.complete_chore_entry(p_chore uuid, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer; scheme text; suffix text; cooldown integer; last_completed timestamptz; wait_minutes integer;period_start date;period_end date;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select * into t from public.chore_tags where id=p_chore for update;
 if t.id is null or t.deleted_at is not null or not app_private.is_member(t.household_id) then raise exception 'Join the household for this sticker before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id is distinct from t.id then raise exception 'This scan request was already used.'; end if;
  return to_jsonb(c);
 end if;
 if exists(select 1 from public.chore_refutations where doer_id=auth.uid() and completion_request_id=p_request and status='removed') then raise exception 'This completion was removed. Scan the sticker again to log a new completion.';end if;
 if (select teams_enabled from public.households where id=t.household_id) and t.assigned_team_id is not null and not exists(select 1 from public.household_members where household_id=t.household_id and user_id=auth.uid() and team_id=t.assigned_team_id) then raise exception 'This chore is assigned to another team.';end if;
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
 suffix := case scheme when 'stars' then ' (+1 sticker)' when 'adventure' then '' else ' (+'||t.points||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||suffix from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $function$;

create or replace function app_private.complete_chore(p_token uuid,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$declare chore uuid;begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 select chore_tag_id into chore from app_private.sticker_inventory where token=p_token and chore_tag_id is not null for update;
 if not found then raise exception 'This sticker is unassigned or is not a valid issued sticker.';end if;
 return app_private.complete_chore_entry(chore,p_request);
end $$;
create function app_private.complete_chore_by_id(p_chore uuid,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 return app_private.complete_chore_entry(p_chore,p_request);
end $$;
create function public.complete_chore_by_id(p_chore uuid,p_request uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.complete_chore_by_id(p_chore,p_request)$$;
revoke all on function app_private.complete_chore_entry(uuid,uuid) from public,anon,authenticated;
revoke all on function app_private.complete_chore_by_id(uuid,uuid),public.complete_chore_by_id(uuid,uuid) from public,anon;
grant execute on function app_private.complete_chore_by_id(uuid,uuid),public.complete_chore_by_id(uuid,uuid) to authenticated;
notify pgrst,'reload schema';

commit;
