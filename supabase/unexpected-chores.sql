begin;
alter table public.chore_completions alter column tag_id drop not null;
alter table public.chore_completions add column completion_kind text not null default 'tag';
alter table public.chore_completions add constraint completion_source_valid check(
 (completion_kind='tag' and tag_id is not null) or (completion_kind='unexpected' and tag_id is null and points between 0 and 3)
);
create function app_private.log_unexpected_chore(p_household uuid,p_description text,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;d date;n text;scheme text;reward integer;description text:=trim(p_description);suffix text;
begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 if p_request is null then raise exception 'A submission ID is required.';end if;
 if description is null or description !~ '[^[:space:]]' or length(description)>500 then raise exception 'Describe the chore in 1 to 500 characters.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,41));
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household before logging chores.';end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.completion_kind<>'unexpected' or c.household_id<>p_household or c.chore<>description then raise exception 'This submission ID was already used for another chore.';end if;
  return to_jsonb(c);
 end if;
 select (now() at time zone timezone)::date,reward_scheme into d,scheme from public.households where id=p_household;
 reward:=floor(random()*4)::integer;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id,completion_kind)
 values(p_household,null,auth.uid(),description,reward,d,p_request,'unexpected') returning * into c;
 select display_name into n from public.household_members where household_id=p_household and user_id=auth.uid();
 suffix:=case when scheme='stars' then ' (+1 gold star; '||reward||' roulette points)' else ' (+'||reward||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,p_household,c.id,n||' completed an unexpected chore: '||description||suffix from public.household_members where household_id=p_household and user_id<>auth.uid();
 return to_jsonb(c);
end $$;
create function public.log_unexpected_chore(p_household uuid,p_description text,p_request uuid) returns jsonb
language sql security invoker set search_path='' as $$select app_private.log_unexpected_chore(p_household,p_description,p_request)$$;
revoke all on function app_private.log_unexpected_chore(uuid,text,uuid),public.log_unexpected_chore(uuid,text,uuid) from public,anon;
grant execute on function app_private.log_unexpected_chore(uuid,text,uuid),public.log_unexpected_chore(uuid,text,uuid) to authenticated;
-- Updated dashboard/tag-request compatibility functions are appended below.
CREATE OR REPLACE FUNCTION app_private.complete_chore(p_token uuid, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer; scheme text; suffix text;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 perform 1 from app_private.sticker_inventory where token=p_token and chore_tag_id is not null for update;
 if not found then raise exception 'This sticker is unassigned or is not a valid issued sticker.';end if;
 select * into t from public.chore_tags where id=(select chore_tag_id from app_private.sticker_inventory where token=p_token) for update;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'Join this stickerÃ¢â‚¬â„¢s household before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id is distinct from t.id then raise exception 'This scan request was already used.'; end if;
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
end $function$
;
CREATE OR REPLACE FUNCTION app_private.household_dashboard(p_household uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d date; w date; result jsonb;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.'; end if;
 select (now() at time zone timezone)::date into d from public.households where id=p_household;
 w:=date_trunc('week',d::timestamp)::date;
 select jsonb_build_object(
  'today',d,'week_start',w,
  'today_count',(select count(*) from public.chore_completions where household_id=p_household and chore_date=d),
  'today_points',(select coalesce(sum(points),0) from public.chore_completions where household_id=p_household and chore_date=d),
  'week_count',(select count(*) from public.chore_completions where household_id=p_household and chore_date>=w),
  'week_points',(select coalesce(sum(points),0) from public.chore_completions where household_id=p_household and chore_date>=w),
  'scores',(select coalesce(jsonb_agg(row_to_json(s)),'[]') from (select m.user_id,m.display_name,m.role,count(c.id) as chores,coalesce(sum(c.points),0) as points from public.household_members m left join public.chore_completions c on c.household_id=m.household_id and c.user_id=m.user_id and c.chore_date>=w where m.household_id=p_household group by m.user_id,m.display_name,m.role,m.joined_at order by sum(c.points) desc nulls last,m.joined_at) s),
  'tag_counts',(select coalesce(jsonb_object_agg(tag_id,n),'{}') from (select tag_id,count(*) n from public.chore_completions where household_id=p_household and chore_date=d and tag_id is not null group by tag_id) counts),
  'activity',(select coalesce(jsonb_agg(row_to_json(a)),'[]') from (select c.*,m.display_name from public.chore_completions c join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household order by completed_at desc limit 50) a)
 ) into result;
 return result;
end $function$
;
commit;


