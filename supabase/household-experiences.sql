begin;
-- Preserve existing households; new households start with individual scoring.
alter table public.households add column teams_enabled boolean not null default true;
alter table public.households alter column teams_enabled set default false;
alter table public.household_week_results add column teams_enabled boolean not null default true;
alter table public.chore_tags add column deleted_at timestamptz;
create index chore_tags_live_household on public.chore_tags(household_id,created_at) where deleted_at is null;
alter table public.households drop constraint households_theme_check;
alter table public.households drop constraint households_reward_scheme_check;


create function app_private.align_household_experience() returns trigger language plpgsql set search_path='' as $$
begin
 if new.theme='clean' then new.theme:='poker';end if;
 new.reward_scheme:=case new.theme when 'wizard' then 'points' when 'parents' then 'stars' when 'cats' then 'cats' when 'poker' then 'poker' else null end;
 return new;
end $$;
revoke all on function app_private.align_household_experience() from public,anon,authenticated;
create trigger align_household_experience before insert or update of theme,reward_scheme on public.households for each row execute function app_private.align_household_experience();
update public.households set theme=case when theme='clean' then 'poker' else theme end;
alter table public.households add constraint households_theme_check check(theme in ('wizard','cats','parents','poker'));
alter table public.households add constraint households_reward_scheme_check check(reward_scheme in ('points','stars','cats','poker'));

create or replace function app_private.seed_new_household() returns trigger language plpgsql security definer set search_path='' as $$
begin if new.teams_enabled then perform app_private.seed_theme_teams(new.id,new.theme);end if;return new;end $$;
CREATE OR REPLACE FUNCTION app_private.seed_theme_teams(h uuid, t text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 insert into public.household_teams(household_id,name,color,symbol,preset_key)
 select h,x.name,x.color,x.symbol,t||':'||x.key from jsonb_to_recordset(
 case t
 when 'cats' then '[{"key":"whiskers","name":"Whisker Warriors","color":"#d478a0","symbol":"cat"},{"key":"purr","name":"Purr Patrol","color":"#9c83d6","symbol":"paw"},{"key":"claws","name":"Claw Crew","color":"#4baca1","symbol":"cat"},{"key":"naps","name":"Nap Champions","color":"#d2a34f","symbol":"paw"}]'::jsonb
 when 'poker' then '[{"key":"aces","name":"Aces","color":"#cf5252","symbol":"star"},{"key":"kings","name":"Kings","color":"#43a787","symbol":"star"},{"key":"queens","name":"Queens","color":"#728dce","symbol":"star"},{"key":"jacks","name":"Jacks","color":"#d2aa50","symbol":"star"}]'::jsonb
 when 'parents' then '[{"key":"mom","name":"Team Mom","color":"#ca7c80","symbol":"heart"},{"key":"dad","name":"Team Dad","color":"#668ea8","symbol":"coffee"},{"key":"helpers","name":"Little Helpers","color":"#89a17a","symbol":"star"},{"key":"family","name":"Family Crew","color":"#c69b58","symbol":"heart"}]'::jsonb
 else '[{"key":"gryffindor","name":"Ember Guild","color":"#ed5255","symbol":"lion"},{"key":"slytherin","name":"Moonstone Circle","color":"#43d3a1","symbol":"snake"},{"key":"ravenclaw","name":"Stormwatch Order","color":"#6b9df5","symbol":"raven"},{"key":"hufflepuff","name":"Sunstone Fellowship","color":"#f1c34f","symbol":"badger"}]'::jsonb end
 ) as x(key text,name text,color text,symbol text) on conflict do nothing;
end $function$
;
CREATE OR REPLACE FUNCTION app_private.create_themed_household(p_name text, p_display_name text, p_timezone text, p_theme text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_theme is null or p_theme not in ('wizard','cats','clean','parents','poker') then raise exception 'Choose a supported theme.'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'Choose a valid time zone.'; end if;
 if (select count(*) from public.household_members where user_id=auth.uid() and role='owner')>=10 then raise exception 'You can own up to 10 households.'; end if;
 insert into public.households(name,timezone,theme) values(trim(p_name),p_timezone,p_theme) returning id into h;
 insert into public.household_members(household_id,user_id,display_name,role) values(h,auth.uid(),trim(p_display_name),'owner');
 insert into app_private.household_invites(household_id) values(h);
 return h;
end $function$
;
create or replace function app_private.set_household_theme(p_household uuid,p_theme text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can change the theme.';end if;
 if p_theme is null or p_theme not in ('wizard','parents','cats','poker','clean') then raise exception 'Choose a supported theme.';end if;
 update public.households set theme=p_theme where id=p_household;
end $$;
create or replace function app_private.set_reward_scheme(p_household uuid,p_scheme text) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_scheme is null or p_scheme not in ('points','stars','cats','poker') then raise exception 'Select a household theme to choose its rewards.';end if;
 perform app_private.set_household_theme(p_household,case p_scheme when 'points' then 'wizard' when 'stars' then 'parents' else p_scheme end);
end $$;
create or replace function app_private.create_household_setup(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[],p_reward_scheme text) returns uuid language plpgsql security definer set search_path='' as $$
begin return app_private.create_household_with_chores(p_name,p_display_name,p_timezone,p_theme,p_starters);end $$;
create function app_private.set_household_experience(p_household uuid,p_theme text,p_teams_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can change these settings.';end if;
 if p_teams_enabled is null then raise exception 'Choose individual or team scoring.';end if;
 perform app_private.set_household_theme(p_household,p_theme);
 update public.households set teams_enabled=p_teams_enabled where id=p_household;
end $$;
create function public.set_household_experience(p_household uuid,p_theme text,p_teams_enabled boolean) returns void language sql security invoker set search_path='' as $$select app_private.set_household_experience(p_household,p_theme,p_teams_enabled)$$;
create function app_private.create_household_experience(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[],p_teams_enabled boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if p_teams_enabled is null then raise exception 'Choose individual or team scoring.';end if;
 h:=app_private.create_household_setup(p_name,p_display_name,p_timezone,p_theme,p_starters,null);
 update public.households set teams_enabled=p_teams_enabled where id=h;
 if p_teams_enabled then perform app_private.seed_theme_teams(h,(select theme from public.households where id=h));end if;
 return h;
end $$;
create function public.create_household_experience(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[],p_teams_enabled boolean default false) returns uuid language sql security invoker set search_path='' as $$select app_private.create_household_experience(p_name,p_display_name,p_timezone,p_theme,p_starters,p_teams_enabled)$$;

-- Retire chores without erasing their completions, comments, proof or weekly awards.
create function app_private.prevent_deleted_chore_changes() returns trigger language plpgsql set search_path='' as $$
begin if old.deleted_at is not null then raise exception 'This chore has been deleted.';end if;return new;end $$;
revoke all on function app_private.prevent_deleted_chore_changes() from public,anon,authenticated;
create trigger protect_deleted_chore before update on public.chore_tags for each row execute function app_private.prevent_deleted_chore_changes();
create function app_private.delete_chore(p_household uuid,p_chore uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can delete chores.';end if;
 -- Same inventory-first lock order as claim/scan. Include unassigned rows so
 -- a concurrent claim cannot bind this chore while it is being retired.
 lock table app_private.sticker_inventory in exclusive mode;
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can delete chores.';end if;
 perform 1 from public.chore_tags where id=p_chore and household_id=p_household for update;
 if not found then raise exception 'Chore not found in this household.';end if;
 if exists(select 1 from public.chore_tags where id=p_chore and deleted_at is not null) then return;end if;
 update public.sticker_release_requests set status='released',reviewed_at=now() where status='pending' and token in(select token from app_private.sticker_inventory where chore_tag_id=p_chore and household_id=p_household);
 update app_private.sticker_inventory set chore_tag_id=null,household_id=null,generation=generation+1 where chore_tag_id=p_chore and household_id=p_household;
 update public.chore_tags set active=false,deleted_at=now(),token=gen_random_uuid() where id=p_chore;
end $$;
create function public.delete_chore(p_household uuid,p_chore uuid) returns void language sql security invoker set search_path='' as $$select app_private.delete_chore(p_household,p_chore)$$;
CREATE OR REPLACE FUNCTION app_private.chore_schedule(p_household uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d date;my_team uuid;result jsonb;enabled boolean;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 select (now() at time zone timezone)::date,teams_enabled into d,enabled from public.households where id=p_household;
 select team_id into my_team from public.household_members where household_id=p_household and user_id=auth.uid();
 select coalesce(jsonb_agg(to_jsonb(s) order by s.chore),'[]') into result from (
  select t.id,t.chore,t.location,t.frequency,case when enabled then t.assigned_team_id else null end as assigned_team_id,t.active,t.points,t.daily_limit,
   periods.start_date as period_start,
   (case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end) as period_end,
   counts.done, greatest(0,t.daily_limit-counts.done) as remaining,
   (enabled and t.assigned_team_id=my_team and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as assigned_to_me,
   ((not enabled or t.assigned_team_id is null or t.assigned_team_id=my_team) and (cardinality(t.eligible_users)=0 or auth.uid()=any(t.eligible_users))) is true as eligible
  from public.chore_tags t
  cross join lateral (select app_private.chore_period_start(d,t.frequency) as start_date) periods
  cross join lateral (select count(*)::integer as done from public.chore_completions c where c.tag_id=t.id and c.chore_date>=periods.start_date and c.chore_date<(case t.frequency when 'weekly' then periods.start_date+7 when 'monthly' then (periods.start_date+interval '1 month')::date else periods.start_date+1 end)) counts
  where t.household_id=p_household and t.deleted_at is null
 )s;
 return result;
end $function$
;
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
 suffix := case scheme when 'stars' then ' (+1 gold star)' when 'adventure' then '' else ' (+'||t.points||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||suffix from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $function$
;
CREATE OR REPLACE FUNCTION app_private.settle_household_weeks(p_household uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare h public.households;w date;current_week date;boundary timestamptz;scheme text;look text;raw_scores jsonb;scores jsonb;r uuid;enabled boolean;
begin
 select * into h from public.households where id=p_household for no key update;
 if h.id is null then return;end if;
 current_week:=date_trunc('week',now() at time zone h.timezone)::date;
 w:=date_trunc('week',h.weekly_competition_started_at at time zone h.timezone)::date;
 select greatest(w,coalesce(max(week_start)+7,w)) into w from public.household_week_results where household_id=p_household;
 while w<current_week loop
  boundary:=(w+7)::timestamp at time zone h.timezone;
  select payload->>'reward_scheme',payload->>'theme',coalesce((payload->>'teams_enabled')::boolean,true) into scheme,look,enabled from app_private.weekly_history where household_id=p_household and kind='household' and effective_at<boundary order by effective_at desc,id desc limit 1;
  scheme:=coalesce(scheme,h.reward_scheme);look:=coalesce(look,h.theme);enabled:=coalesce(enabled,h.teams_enabled);
  if enabled then
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  totals as(
   select t.entity_id as team_id,t.payload->>'name' as name,t.payload->>'color' as color,t.payload->>'symbol' as symbol,count(c.id) as chores,coalesce(sum(c.points),0) as points
   from teams_at_end t left join members_at_end m on m.payload->>'team_id'=t.entity_id::text and not coalesce((m.payload->>'_deleted')::boolean,false)
   left join public.chore_completions c on c.household_id=p_household and c.user_id=m.entity_id and c.chore_date>=w and c.chore_date<w+7
   where not coalesce((t.payload->>'_deleted')::boolean,false) group by t.entity_id,t.payload
  ) select coalesce(jsonb_agg(to_jsonb(totals)),'[]'::jsonb) into raw_scores from totals;
  else
   with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
   totals as(select m.entity_id as team_id,m.payload->>'display_name' as name,'#7e9dce'::text as color,'star'::text as symbol,'individual'::text as kind,count(c.id) as chores,coalesce(sum(c.points),0) as points
    from members_at_end m left join public.chore_completions c on c.household_id=p_household and c.user_id=m.entity_id and c.chore_date>=w and c.chore_date<w+7
    where not coalesce((m.payload->>'_deleted')::boolean,false) group by m.entity_id,m.payload)
   select coalesce(jsonb_agg(to_jsonb(totals)),'[]'::jsonb) into raw_scores from totals;
  end if;
  scores:=app_private.rank_week_teams(raw_scores,scheme);
  insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores,teams_enabled) values(p_household,w,w+7,h.timezone,scheme,look,scores,enabled) returning id into r;
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc)
  insert into public.weekly_result_chores(result_id,completion_id,team_id,completed_at,proof_path,details)
  select r,c.id,case when enabled then t.entity_id else m.entity_id end,c.completed_at,c.proof_path,to_jsonb(c)||jsonb_build_object('display_name',coalesce(m.payload->>'display_name','Former member'),'team_id',case when enabled then t.entity_id else m.entity_id end,'team_name',case when enabled then t.payload->>'name' else m.payload->>'display_name' end,'team_color',case when enabled then t.payload->>'color' else '#7e9dce' end)
  from public.chore_completions c left join members_at_end m on m.entity_id=c.user_id
  left join teams_at_end t on t.entity_id::text=m.payload->>'team_id' and not coalesce((m.payload->>'_deleted')::boolean,false) and not coalesce((t.payload->>'_deleted')::boolean,false)
  where c.household_id=p_household and c.chore_date>=w and c.chore_date<w+7;
  w:=w+7;
 end loop;
end $function$
;
revoke all on function app_private.settle_household_weeks(uuid) from public,anon,authenticated;
create or replace function app_private.settle_weekly_results(p_household uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not app_private.is_member(p_household) then raise exception 'Join this household to view weekly results.';end if;perform app_private.settle_household_weeks(p_household);end $$;
create or replace function app_private.rank_week_teams(p_scores jsonb,p_scheme text) returns jsonb language sql immutable set search_path='' as $$
 with scored as(select value||jsonb_build_object('score',case when p_scheme in ('stars','adventure') then coalesce((value->>'chores')::bigint,0) else coalesce((value->>'points')::bigint,0) end) as item from jsonb_array_elements(p_scores)),
 ranked as(select item,(item->>'score')::bigint as score,max((item->>'score')::bigint) over() as high from scored)
 select coalesce(jsonb_agg(item||jsonb_build_object('winner',score>0 and score=high,'weekly_win_points',case when score>0 and score=high then 1 else 0 end) order by score desc,item->>'name'),'[]'::jsonb) from ranked
$$;
create function app_private.household_weekly_scores(p_household uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare enabled boolean;result jsonb;
begin
 perform app_private.settle_weekly_results(p_household);
 select teams_enabled into enabled from public.households where id=p_household;
 with competitors as(
  select t.id,t.name from public.household_teams t where t.household_id=p_household and t.active and enabled
  union all select m.user_id,m.display_name from public.household_members m where m.household_id=p_household and not enabled
 ), wins as(select (s->>'team_id')::uuid as id,sum(coalesce((s->>'weekly_win_points')::integer,0)) as weekly_points from public.household_week_results r cross join lateral jsonb_array_elements(r.team_scores) s where r.household_id=p_household and r.teams_enabled=enabled group by s->>'team_id')
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'weekly_points',coalesce(w.weekly_points,0)) order by coalesce(w.weekly_points,0) desc,c.name,c.id),'[]'::jsonb) into result from competitors c left join wins w using(id);
 return result;
end $$;
create function public.household_weekly_scores(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.household_weekly_scores(p_household)$$;

create or replace function app_private.community_board(p_household uuid,p_followed_only boolean default false,p_offset integer default 0) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;h uuid;
begin
 perform app_private.community_access(p_household);
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid page.';end if;
 -- Deterministic lock order. Settlement stays private; only aggregate wins
 -- and team names can leave this function, never member identities.
 for h in select household_id from app_private.community_households where enabled order by household_id loop
  perform app_private.settle_household_weeks(h);
 end loop;
 with enrolled as(
  select h.id,h.name,h.teams_enabled,exists(select 1 from app_private.community_follows f where f.user_id=auth.uid() and f.target_household=h.id) as following
  from public.households h join app_private.community_households e on e.household_id=h.id and e.enabled
 ), wins as(
  select r.household_id,(s->>'team_id')::uuid as id,r.teams_enabled,sum(coalesce((s->>'weekly_win_points')::integer,0))::bigint as points,(array_agg(s->>'name' order by r.week_start desc))[1] as name
  from public.household_week_results r join enrolled e on e.id=r.household_id cross join lateral jsonb_array_elements(r.team_scores) s
  group by r.household_id,s->>'team_id',r.teams_enabled
 ), scored as(
  select e.id,e.name,e.teams_enabled,e.following,coalesce((select sum(w.points) from wins w where w.household_id=e.id),0)::bigint as points,
   case when e.teams_enabled then coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'name',w.name,'points',w.points) order by w.points desc,w.name,w.id) from wins w where w.household_id=e.id and w.teams_enabled),'[]'::jsonb) else '[]'::jsonb end as teams
  from enrolled e
 ), ranked as(select *,dense_rank() over(order by points desc) as rank from scored),
 filtered as(select * from ranked where not coalesce(p_followed_only,false) or following or id=p_household),
 page as(select * from filtered order by points desc,lower(name),id offset p_offset limit 25)
 select jsonb_build_object('households',(select coalesce(jsonb_agg(to_jsonb(p) order by p.points desc,lower(p.name),p.id),'[]') from page p),'total',(select count(*) from filtered),'following_count',(select count(*) from enrolled where following),'score_kind','weekly_wins') into result;
 return result;
end $$;
revoke all on function app_private.set_household_experience(uuid,text,boolean),public.set_household_experience(uuid,text,boolean),app_private.create_household_experience(text,text,text,text,text[],boolean),public.create_household_experience(text,text,text,text,text[],boolean),app_private.delete_chore(uuid,uuid),public.delete_chore(uuid,uuid),app_private.household_weekly_scores(uuid),public.household_weekly_scores(uuid) from public,anon;
grant execute on function app_private.set_household_experience(uuid,text,boolean),public.set_household_experience(uuid,text,boolean),app_private.create_household_experience(text,text,text,text,text[],boolean),public.create_household_experience(text,text,text,text,text[],boolean),app_private.delete_chore(uuid,uuid),public.delete_chore(uuid,uuid),app_private.household_weekly_scores(uuid),public.household_weekly_scores(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
