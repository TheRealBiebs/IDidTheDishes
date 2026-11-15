begin;
create table public.chore_refutations(
 id uuid primary key default gen_random_uuid(),completion_id uuid references public.chore_completions on delete set null,
 household_id uuid not null references public.households on delete cascade,doer_id uuid not null references auth.users on delete cascade,
 refuter_id uuid not null references auth.users on delete cascade,reason text check(length(reason)<=1000),
 request_id uuid not null,completion_request_id uuid not null,
 status text not null default 'pending' check(status in('pending','redone','removed')),
 created_at timestamptz not null default now(),resolved_at timestamptz,
 unique(refuter_id,request_id)
);
create unique index chore_refutation_pending_idx on public.chore_refutations(completion_id) where status='pending';
create index chore_refutation_thread_idx on public.chore_refutations(completion_id,created_at desc);
create index chore_refutation_household_idx on public.chore_refutations(household_id);
create index chore_refutation_doer_idx on public.chore_refutations(doer_id,completion_request_id);
alter table public.chore_refutations enable row level security;
create policy chore_refutations_read on public.chore_refutations for select to authenticated using(app_private.is_member(household_id));
revoke all on public.chore_refutations from public,anon,authenticated;
grant select on public.chore_refutations to authenticated;

create function app_private.refute_chore(p_completion uuid,p_reason text,p_request uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;existing public.chore_refutations;result uuid;n text;reason_text text:=nullif(btrim(p_reason),'');
begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 if p_request is null then raise exception 'A refutation submission ID is required.';end if;
 if length(reason_text)>1000 then raise exception 'Keep the reason to 1000 characters or fewer.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,64));
 select * into c from public.chore_completions where id=p_completion for update;
 if c.id is null or not app_private.is_member(c.household_id) then raise exception 'This chore is not available to your household.';end if;
 if c.user_id=auth.uid() then raise exception 'You cannot refute your own chore.';end if;
 if not exists(select 1 from public.household_members where household_id=c.household_id and user_id=c.user_id) then raise exception 'The doer must still be in the household to respond.';end if;
 select * into existing from public.chore_refutations where refuter_id=auth.uid() and request_id=p_request;
 if existing.id is not null then
  if existing.completion_id is distinct from c.id or existing.reason is distinct from reason_text then raise exception 'This submission ID was already used for another refutation.';end if;
  return existing.id;
 end if;
 if exists(select 1 from public.chore_refutations where completion_id=c.id and status='pending') then raise exception 'This chore is already waiting for the doer to respond.';end if;
 insert into public.chore_refutations(completion_id,household_id,doer_id,refuter_id,reason,request_id,completion_request_id) values(c.id,c.household_id,c.user_id,auth.uid(),reason_text,p_request,c.request_id) returning id into result;
 select display_name into n from public.household_members where household_id=c.household_id and user_id=auth.uid();
 insert into public.notifications(user_id,household_id,completion_id,message) values(c.user_id,c.household_id,c.id,n||' refuted your chore: '||c.chore||case when reason_text is null then '. Choose to redo it or remove the completion.' else '. Reason: '||left(reason_text,240) end);
 return result;
end $$;
create function public.refute_chore(p_completion uuid,p_reason text,p_request uuid) returns uuid language sql security invoker set search_path='' as $$select app_private.refute_chore(p_completion,p_reason,p_request)$$;

create function app_private.resolve_chore_refutation(p_refutation uuid,p_action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.chore_refutations;c public.chore_completions;archived public.household_week_results;raw_scores jsonb;n text;
begin
 select * into r from public.chore_refutations where id=p_refutation for update;
 if r.id is null or auth.uid() is distinct from r.doer_id or not app_private.is_member(r.household_id) then raise exception 'Only the original doer can resolve this refutation.';end if;
 if p_action is null or p_action not in('redone','removed') then raise exception 'Choose redo or remove.';end if;
 if r.status<>'pending' then
  if r.status<>p_action then raise exception 'This refutation has already been resolved.';end if;
  return jsonb_build_object('removed',r.status='removed','status',r.status);
 end if;
 -- Match household settings/weekly-settlement locks and scan tag locks.
 perform 1 from public.households where id=r.household_id for no key update;
 select * into c from public.chore_completions where id=r.completion_id;
 if c.id is null then raise exception 'This completion is no longer available.';end if;
 if c.tag_id is not null then perform 1 from public.chore_tags where id=c.tag_id for update;end if;
 select * into c from public.chore_completions where id=r.completion_id for update;
 update public.chore_refutations set status=p_action,resolved_at=now() where id=r.id;
 if p_action='redone' then
  if exists(select 1 from public.household_members where household_id=c.household_id and user_id=r.refuter_id) then
   select display_name into n from public.household_members where household_id=c.household_id and user_id=c.user_id;
   insert into public.notifications(user_id,household_id,completion_id,message) values(r.refuter_id,c.household_id,c.id,n||' redid '||c.chore||' and kept the original points.');
  end if;
 else
  -- Remove archived copies and recompute their team totals and weekly winners.
  for archived in select w.* from public.household_week_results w where w.household_id=c.household_id and exists(select 1 from public.weekly_result_chores wc where wc.result_id=w.id and wc.completion_id=c.id) for update loop
   delete from public.weekly_result_chores where result_id=archived.id and completion_id=c.id;
   select coalesce(jsonb_agg(team||jsonb_build_object('points',points,'chores',chores)),'[]') into raw_scores from (
    select t.value as team,coalesce(sum((wc.details->>'points')::bigint),0) as points,count(wc.completion_id) as chores
    from jsonb_array_elements(archived.team_scores) t left join public.weekly_result_chores wc on wc.result_id=archived.id and wc.team_id::text=t.value->>'team_id' group by t.value
   ) totals;
   update public.household_week_results set team_scores=app_private.rank_week_teams(raw_scores,archived.reward_scheme) where id=archived.id;
  end loop;
  delete from public.chore_completions where id=c.id;
 end if;
 return jsonb_build_object('removed',p_action='removed','status',p_action);
end $$;
create function public.resolve_chore_refutation(p_refutation uuid,p_action text) returns jsonb language sql security invoker set search_path='' as $$select app_private.resolve_chore_refutation(p_refutation,p_action)$$;

revoke all on function app_private.refute_chore(uuid,text,uuid),public.refute_chore(uuid,text,uuid),app_private.resolve_chore_refutation(uuid,text),public.resolve_chore_refutation(uuid,text) from public,anon;
grant execute on function app_private.refute_chore(uuid,text,uuid),public.refute_chore(uuid,text,uuid),app_private.resolve_chore_refutation(uuid,text),public.resolve_chore_refutation(uuid,text) to authenticated;
alter publication supabase_realtime add table public.chore_refutations;
CREATE OR REPLACE FUNCTION app_private.chore_social(p_completion uuid, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c public.chore_completions;result jsonb;
begin
 select * into c from public.chore_completions where id=p_completion;
 if c.id is null or not app_private.is_member(c.household_id) then raise exception 'This chore is not available to your household.';end if;
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid comment page.';end if;
 select jsonb_build_object('completion',to_jsonb(c),'likes_count',(select count(*) from public.chore_likes where completion_id=c.id and liked),
  'liked_by_me',exists(select 1 from public.chore_likes where completion_id=c.id and user_id=auth.uid() and liked),
  'liked_by',(select coalesce(jsonb_agg(name order by name),'[]') from (select coalesce(m.display_name,'Former household member') as name from public.chore_likes l left join public.household_members m on m.household_id=l.household_id and m.user_id=l.user_id where l.completion_id=c.id and l.liked order by name,l.user_id limit 25) names),
  'comments',(select coalesce(jsonb_agg(to_jsonb(rows) order by rows.created_at desc,rows.id desc),'[]') from (select s.id,s.body,s.created_at,coalesce(m.display_name,'Former household member') as display_name from public.chore_comments s left join public.household_members m on m.household_id=s.household_id and m.user_id=s.user_id where s.completion_id=c.id order by s.created_at desc,s.id desc offset p_offset limit 50) rows),
  'total_comments',(select count(*) from public.chore_comments where completion_id=c.id)) into result;
 return result||jsonb_build_object(
  'is_doer',c.user_id=auth.uid(),
  'can_refute',c.user_id<>auth.uid() and exists(select 1 from public.household_members where household_id=c.household_id and user_id=c.user_id) and not exists(select 1 from public.chore_refutations where completion_id=c.id and status='pending'),
  'refutations',(select coalesce(jsonb_agg(to_jsonb(rows) order by rows.created_at desc,rows.id desc),'[]') from (select r.id,r.reason,r.status,r.created_at,r.resolved_at,coalesce(m.display_name,'Former household member') as refuter_name from public.chore_refutations r left join public.household_members m on m.household_id=r.household_id and m.user_id=r.refuter_id where r.completion_id=c.id order by r.created_at desc,r.id desc limit 20) rows));
end $function$;

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
 if exists(select 1 from public.chore_refutations where doer_id=auth.uid() and completion_request_id=p_request and status='removed') then raise exception 'This completion was removed. Scan the sticker again to log a new completion.';end if;
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
