begin;
alter table public.households add column weekly_competition_started_at timestamptz not null default now();
create table app_private.weekly_history(
 id bigint generated always as identity primary key,
 household_id uuid not null references public.households on delete cascade,
 kind text not null check(kind in ('household','member','team')),
 entity_id uuid not null,payload jsonb not null,effective_at timestamptz not null default clock_timestamp()
);
create index weekly_history_lookup on app_private.weekly_history(household_id,kind,entity_id,effective_at desc,id desc);
alter table app_private.weekly_history enable row level security;
create policy weekly_history_private on app_private.weekly_history to anon,authenticated using(false) with check(false);
revoke all on app_private.weekly_history from public,anon,authenticated;
create function app_private.record_weekly_history() returns trigger language plpgsql security definer set search_path='' as $$
declare doc jsonb;h uuid;k text;entity uuid;
begin
 if tg_op='DELETE' then doc:=to_jsonb(old)||'{"_deleted":true}'::jsonb;else doc:=to_jsonb(new);end if;
 if tg_table_name='households' then h:=(doc->>'id')::uuid;k:='household';entity:=h;
 elsif tg_table_name='household_members' then h:=(doc->>'household_id')::uuid;k:='member';entity:=(doc->>'user_id')::uuid;
 else h:=(doc->>'household_id')::uuid;k:='team';entity:=(doc->>'id')::uuid;end if;
 -- Parent deletion cascades should not attempt to recreate child history.
 if exists(select 1 from public.households where id=h) then
  insert into app_private.weekly_history(household_id,kind,entity_id,payload) values(h,k,entity,doc);
 end if;
 return null;
end $$;
revoke all on function app_private.record_weekly_history() from public,anon,authenticated;
create trigger weekly_history_households after insert or update on public.households for each row execute function app_private.record_weekly_history();
create trigger weekly_history_members after insert or update or delete on public.household_members for each row execute function app_private.record_weekly_history();
create trigger weekly_history_teams after insert or update or delete on public.household_teams for each row execute function app_private.record_weekly_history();
insert into app_private.weekly_history(household_id,kind,entity_id,payload) select id,'household',id,to_jsonb(h) from public.households h;
insert into app_private.weekly_history(household_id,kind,entity_id,payload) select household_id,'member',user_id,to_jsonb(m) from public.household_members m;
insert into app_private.weekly_history(household_id,kind,entity_id,payload) select household_id,'team',id,to_jsonb(t) from public.household_teams t;

create table public.household_week_results(
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households on delete cascade,
 week_start date not null,week_end date not null,timezone text not null,reward_scheme text not null,theme text not null,
 team_scores jsonb not null,finalized_at timestamptz not null default now(),
 unique(household_id,week_start),check(week_end=week_start+7)
);
create table public.weekly_result_chores(
 result_id uuid not null references public.household_week_results on delete cascade,
 completion_id uuid not null,team_id uuid,completed_at timestamptz not null,proof_path text,details jsonb not null,
 primary key(result_id,completion_id)
);
create index weekly_chore_team_lookup on public.weekly_result_chores(result_id,team_id,completed_at desc);
create index weekly_chore_proof_lookup on public.weekly_result_chores(proof_path) where proof_path is not null;
alter table public.household_week_results enable row level security;
alter table public.weekly_result_chores enable row level security;
create policy weekly_results_read on public.household_week_results for select to authenticated using(app_private.is_member(household_id));
create policy weekly_chores_read on public.weekly_result_chores for select to authenticated using(exists(select 1 from public.household_week_results r where r.id=result_id and app_private.is_member(r.household_id)));
revoke all on public.household_week_results,public.weekly_result_chores from public,anon,authenticated;
grant select on public.household_week_results,public.weekly_result_chores to authenticated;
create table app_private.weekly_celebrations(
 user_id uuid not null references auth.users on delete cascade,result_id uuid not null references public.household_week_results on delete cascade,
 seen_at timestamptz not null default now(),primary key(user_id,result_id)
);
alter table app_private.weekly_celebrations enable row level security;
create policy weekly_celebrations_private on app_private.weekly_celebrations to anon,authenticated using(false) with check(false);
revoke all on app_private.weekly_celebrations from public,anon,authenticated;

-- Pure ranking logic is shared with read-only verification queries. Each
-- winning team earns exactly one weekly point, including tied leaders.
create function app_private.rank_week_teams(p_scores jsonb,p_scheme text) returns jsonb language sql immutable set search_path='' as $$
 with scored as(select value||jsonb_build_object('score',case when p_scheme='points' then coalesce((value->>'points')::bigint,0) else coalesce((value->>'chores')::bigint,0) end) as item from jsonb_array_elements(p_scores)),
 ranked as(select item,(item->>'score')::bigint as score,max((item->>'score')::bigint) over() as high from scored)
 select coalesce(jsonb_agg(item||jsonb_build_object('winner',score>0 and score=high,'weekly_win_points',case when score>0 and score=high then 1 else 0 end) order by score desc,item->>'name'),'[]'::jsonb) from ranked
$$;
revoke all on function app_private.rank_week_teams(jsonb,text) from public,anon,authenticated;

create function app_private.settle_weekly_results(p_household uuid) returns void language plpgsql security definer set search_path='' as $$
declare h public.households;w date;current_week date;boundary timestamptz;scheme text;look text;raw_scores jsonb;scores jsonb;r uuid;
begin
 select * into h from public.households where id=p_household for no key update;
 if h.id is null or not app_private.is_member(p_household) then raise exception 'Join this household to view weekly results.';end if;
 current_week:=date_trunc('week',now() at time zone h.timezone)::date;
 w:=date_trunc('week',h.weekly_competition_started_at at time zone h.timezone)::date;
 select greatest(w,coalesce(max(week_start)+7,w)) into w from public.household_week_results where household_id=p_household;
 while w<current_week loop
  boundary:=(w+7)::timestamp at time zone h.timezone;
  select payload->>'reward_scheme',payload->>'theme' into scheme,look from app_private.weekly_history where household_id=p_household and kind='household' and effective_at<boundary order by effective_at desc,id desc limit 1;
  scheme:=coalesce(scheme,h.reward_scheme);look:=coalesce(look,h.theme);
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  totals as(
   select t.entity_id as team_id,t.payload->>'name' as name,t.payload->>'color' as color,t.payload->>'symbol' as symbol,count(c.id) as chores,coalesce(sum(c.points),0) as points
   from teams_at_end t left join members_at_end m on m.payload->>'team_id'=t.entity_id::text and not coalesce((m.payload->>'_deleted')::boolean,false)
   left join public.chore_completions c on c.household_id=p_household and c.user_id=m.entity_id and c.chore_date>=w and c.chore_date<w+7
   where not coalesce((t.payload->>'_deleted')::boolean,false) group by t.entity_id,t.payload
  ) select coalesce(jsonb_agg(to_jsonb(totals)),'[]'::jsonb) into raw_scores from totals;
  scores:=app_private.rank_week_teams(raw_scores,scheme);
  insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores) values(p_household,w,w+7,h.timezone,scheme,look,scores) returning id into r;
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc)
  insert into public.weekly_result_chores(result_id,completion_id,team_id,completed_at,proof_path,details)
  select r,c.id,t.entity_id,c.completed_at,c.proof_path,to_jsonb(c)||jsonb_build_object('display_name',coalesce(m.payload->>'display_name','Former member'),'team_id',t.entity_id,'team_name',t.payload->>'name','team_color',t.payload->>'color')
  from public.chore_completions c left join members_at_end m on m.entity_id=c.user_id
  left join teams_at_end t on t.entity_id::text=m.payload->>'team_id' and not coalesce((m.payload->>'_deleted')::boolean,false) and not coalesce((t.payload->>'_deleted')::boolean,false)
  where c.household_id=p_household and c.chore_date>=w and c.chore_date<w+7;
  w:=w+7;
 end loop;
end $$;
revoke all on function app_private.settle_weekly_results(uuid) from public,anon,authenticated;

create function app_private.weekly_hall(p_household uuid,p_before date default null,p_limit integer default 30) returns jsonb language plpgsql security definer set search_path='' as $$
declare weeks jsonb;standings jsonb;more boolean;
begin
 if p_limit not between 1 and 100 or p_limit is null then raise exception 'Choose 1 to 100 weekly results.';end if;
 perform app_private.settle_weekly_results(p_household);
 select coalesce(jsonb_agg(to_jsonb(q) order by week_start desc),'[]'::jsonb) into weeks from (select * from public.household_week_results where household_id=p_household and (p_before is null or week_start<p_before) order by week_start desc limit p_limit) q;
 select count(*)>p_limit into more from public.household_week_results where household_id=p_household and (p_before is null or week_start<p_before);
 with wins as(select (s->>'team_id')::uuid as team_id,(array_agg(s->>'name' order by r.week_start desc))[1] as name,(array_agg(s->>'color' order by r.week_start desc))[1] as color,sum((s->>'weekly_win_points')::integer) as weekly_points from public.household_week_results r cross join lateral jsonb_array_elements(r.team_scores) s where r.household_id=p_household and (s->>'winner')::boolean group by s->>'team_id')
 select coalesce(jsonb_agg(jsonb_build_object('team_id',wins.team_id,'name',coalesce(t.name,wins.name),'color',coalesce(t.color,wins.color),'weekly_points',weekly_points) order by weekly_points desc,wins.name),'[]'::jsonb) into standings from wins left join public.household_teams t on t.id=wins.team_id and t.household_id=p_household;
 return jsonb_build_object('weeks',weeks,'standings',standings,'has_more',more,'started_at',(select weekly_competition_started_at from public.households where id=p_household));
end $$;
create function app_private.pending_weekly_result(p_household uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.household_week_results;
begin
 perform app_private.settle_weekly_results(p_household);
 -- Only the latest completed week is celebrated after a long absence; older
 -- weeks still have their awards and full Hall of Fame entries.
 select * into r from public.household_week_results where household_id=p_household order by week_start desc limit 1;
 if r.id is null or exists(select 1 from app_private.weekly_celebrations where result_id=r.id and user_id=auth.uid()) then return null;end if;
 return to_jsonb(r);
end $$;
create function app_private.ack_weekly_result(p_result uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.household_week_results where id=p_result and app_private.is_member(household_id)) then raise exception 'Join this household to view weekly results.';end if;
 insert into app_private.weekly_celebrations(user_id,result_id) values(auth.uid(),p_result) on conflict do nothing;
end $$;
create function app_private.weekly_chores(p_result uuid,p_team uuid default null,p_offset integer default 0,p_limit integer default 50) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;total integer;
begin
 if not exists(select 1 from public.household_week_results where id=p_result and app_private.is_member(household_id)) then raise exception 'Join this household to view weekly results.';end if;
 if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset<0 then raise exception 'Choose a valid history page.';end if;
 select count(*) into total from public.weekly_result_chores where result_id=p_result and (p_team is null or team_id=p_team);
 select coalesce(jsonb_agg(details order by completed_at desc,completion_id),'[]'::jsonb) into rows from(select * from public.weekly_result_chores where result_id=p_result and (p_team is null or team_id=p_team) order by completed_at desc,completion_id offset p_offset limit p_limit) q;
 return jsonb_build_object('chores',rows,'total',total);
end $$;
create function public.weekly_hall(p_household uuid,p_before date default null,p_limit integer default 30) returns jsonb language sql security invoker set search_path='' as $$select app_private.weekly_hall(p_household,p_before,p_limit)$$;
create function public.pending_weekly_result(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.pending_weekly_result(p_household)$$;
create function public.ack_weekly_result(p_result uuid) returns void language sql security invoker set search_path='' as $$select app_private.ack_weekly_result(p_result)$$;
create function public.weekly_chores(p_result uuid,p_team uuid default null,p_offset integer default 0,p_limit integer default 50) returns jsonb language sql security invoker set search_path='' as $$select app_private.weekly_chores(p_result,p_team,p_offset,p_limit)$$;
revoke all on function app_private.weekly_hall(uuid,date,integer),public.weekly_hall(uuid,date,integer),app_private.pending_weekly_result(uuid),public.pending_weekly_result(uuid),app_private.ack_weekly_result(uuid),public.ack_weekly_result(uuid),app_private.weekly_chores(uuid,uuid,integer,integer),public.weekly_chores(uuid,uuid,integer,integer) from public,anon;
grant execute on function app_private.weekly_hall(uuid,date,integer),public.weekly_hall(uuid,date,integer),app_private.pending_weekly_result(uuid),public.pending_weekly_result(uuid),app_private.ack_weekly_result(uuid),public.ack_weekly_result(uuid),app_private.weekly_chores(uuid,uuid,integer,integer),public.weekly_chores(uuid,uuid,integer,integer) to authenticated;
-- Archived proof remains private and available with its historical chore.
create policy weekly_proof_read on storage.objects for select to authenticated using(bucket_id='chore-proof' and exists(select 1 from public.weekly_result_chores q join public.household_week_results r on r.id=q.result_id where q.proof_path=name and app_private.is_member(r.household_id)));
create or replace function app_private.proof_is_unattached(p_path text) returns boolean language sql stable security definer set search_path='' as $$select not exists(select 1 from public.chore_completions where proof_path=p_path) and not exists(select 1 from public.weekly_result_chores where proof_path=p_path)$$;
commit;
