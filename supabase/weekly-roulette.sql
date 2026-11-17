begin;
alter table public.households add column roulette_available_from date;
update public.households set roulette_available_from=date_trunc('week',now() at time zone timezone)::date-7 where roulette_available_from is null;
create table app_private.roulette_rounds(
 id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households on delete cascade,
 user_id uuid not null references auth.users on delete cascade,result_id uuid not null references public.household_week_results on delete cascade,
 week_start date not null,earnings bigint not null check(earnings between 1 and 1000000000000),
 state text not null default 'pending' check(state in('pending','spun','banked')),bets jsonb not null default '[]',
 wager bigint not null default 0 check(wager>=0),payout bigint not null default 0 check(payout>=0),credit bigint not null default 0 check(credit>=0),
 outcome integer check(outcome between 0 and 37),request_id uuid,settled_at timestamptz,
 unique(household_id,user_id,week_start),check(wager<=earnings),check(state<>'pending' or (credit=0 and outcome is null and settled_at is null))
);
create index roulette_rounds_user_house on app_private.roulette_rounds(user_id,household_id,week_start);
create index roulette_rounds_result on app_private.roulette_rounds(result_id);
alter table app_private.roulette_rounds enable row level security;
create policy roulette_rounds_private on app_private.roulette_rounds to anon,authenticated using(false) with check(false);
revoke all on app_private.roulette_rounds from public,anon,authenticated;

create function app_private.ensure_roulette_rounds(p_household uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 insert into app_private.roulette_rounds(household_id,user_id,result_id,week_start,earnings)
 select r.household_id,(c.details->>'user_id')::uuid,r.id,r.week_start,greatest(0,sum((c.details->>'points')::bigint))
 from public.household_week_results r join public.households h on h.id=r.household_id join public.weekly_result_chores c on c.result_id=r.id
 where r.household_id=p_household and r.reward_scheme='poker'
 and r.week_start>=coalesce(h.roulette_available_from,date_trunc('week',h.created_at at time zone h.timezone)::date)
 group by r.household_id,c.details->>'user_id',r.id,r.week_start having sum((c.details->>'points')::bigint)>0
 on conflict(household_id,user_id,week_start) do nothing;
end $$;

-- Returns the total-return multiplier, including the winning stake.
create function app_private.roulette_multiplier(p_bet jsonb,p_outcome integer) returns integer
language plpgsql immutable set search_path='' as $$
declare kind text:=p_bet->>'kind';nums integer[];count_nums integer;first integer;row_start integer;win boolean;mult integer;
begin
 if jsonb_typeof(p_bet)<>'object' or kind is null then raise exception 'Invalid roulette bet.';end if;
 if kind in('straight','split','street','trio','corner','sixline','basket') then
  if jsonb_typeof(p_bet->'numbers') is distinct from 'array' then raise exception 'Choose the numbers for this inside bet.';end if;
  if exists(select 1 from jsonb_array_elements_text(p_bet->'numbers') n where n !~ '^(0|[1-9][0-9]?)$') then raise exception 'Invalid roulette pocket.';end if;
  select array_agg(n::integer order by n::integer),count(*) into nums,count_nums from jsonb_array_elements_text(p_bet->'numbers') n;
  if count_nums=0 or count_nums>6 or (select count(distinct n) from unnest(nums)n)<>count_nums or exists(select 1 from unnest(nums)n where n not between 0 and 37) then raise exception 'Invalid inside bet.';end if;
  first:=nums[1];row_start:=((first-1)/3)*3+1;
  if kind='straight' then win:=count_nums=1;mult:=36;
  elsif kind='split' then win:=count_nums=2 and (nums in(array[0,37],array[0,1],array[0,2],array[2,37],array[3,37]) or (first>=1 and nums[2]<=36 and (nums[2]-first=3 or (nums[2]-first=1 and (first-1)/3=(nums[2]-1)/3))));mult:=18;
  elsif kind='street' then win:=first>=1 and first<=34 and (first-1)%3=0 and nums=array[first,first+1,first+2];mult:=12;
  elsif kind='trio' then win:=nums in(array[0,1,2],array[2,3,37]);mult:=12;
  elsif kind='corner' then win:=first>=1 and first<=32 and (first-1)%3<2 and nums=array[first,first+1,first+3,first+4];mult:=9;
  elsif kind='sixline' then win:=first>=1 and first<=31 and (first-1)%3=0 and nums=array[first,first+1,first+2,first+3,first+4,first+5];mult:=6;
  else win:=nums=array[0,1,2,3,37];mult:=7;
  end if;
  if win is not true then raise exception 'Those numbers do not form a valid % bet.',kind;end if;
  return case when p_outcome=any(nums) then mult else 0 end;
 end if;
 if kind not in('red','black','even','odd','low','high','dozen1','dozen2','dozen3','column1','column2','column3') then raise exception 'Unsupported roulette bet.';end if;
 if p_outcome is null or p_outcome in(0,37) then return 0;end if;
 win:=case kind
 when 'red' then p_outcome=any(array[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36])
 when 'black' then not p_outcome=any(array[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36])
 when 'even' then p_outcome%2=0 when 'odd' then p_outcome%2=1 when 'low' then p_outcome<=18 when 'high' then p_outcome>=19
 when 'dozen1' then p_outcome<=12 when 'dozen2' then p_outcome between 13 and 24 when 'dozen3' then p_outcome>=25
 when 'column1' then p_outcome%3=1 when 'column2' then p_outcome%3=2 when 'column3' then p_outcome%3=0 end;
 return case when not win then 0 when kind like 'dozen%' or kind like 'column%' then 3 else 2 end;
end $$;

create function app_private.roulette_dashboard(p_household uuid) returns jsonb
language plpgsql security definer set search_path='' as $$declare rounds jsonb;bank bigint;begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 perform app_private.settle_weekly_results(p_household);
 perform app_private.ensure_roulette_rounds(p_household);
 select coalesce(sum(credit),0) into bank from app_private.roulette_rounds where household_id=p_household and user_id=auth.uid() and state<>'pending';
 select coalesce(jsonb_agg(to_jsonb(r) order by (r.state='pending') desc,r.week_start),'[]'::jsonb) into rounds from(
  select * from app_private.roulette_rounds where household_id=p_household and user_id=auth.uid() order by (state='pending') desc,case when state='pending' then week_start end,week_start desc limit 52
 )r;
 return jsonb_build_object('bank_total',bank,'rounds',rounds);
end $$;

create function app_private.settle_roulette_round(p_household uuid,p_round uuid,p_bets jsonb,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r app_private.roulette_rounds;bet jsonb;stake bigint:=0;paid bigint:=0;amount bigint;number integer;byte integer;bank bigint;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 select * into r from app_private.roulette_rounds where id=p_round and household_id=p_household and user_id=auth.uid() for update;
 if not found then raise exception 'This weekly roulette round is not available to you.';end if;
 if r.state<>'pending' then
  select coalesce(sum(credit),0) into bank from app_private.roulette_rounds where household_id=p_household and user_id=auth.uid() and state<>'pending';
  return jsonb_build_object('round',to_jsonb(r),'bank_total',bank);
 end if;
 if p_request is null then raise exception 'A spin request is required.';end if;
 if jsonb_typeof(p_bets) is distinct from 'array' or jsonb_array_length(p_bets)>256 then raise exception 'Choose a valid set of roulette bets.';end if;
 for bet in select value from jsonb_array_elements(p_bets) loop
  if (bet->>'amount') is null or bet->>'amount' !~ '^[1-9][0-9]{0,12}$' then raise exception 'Use positive whole-chip wagers.';end if;
  amount:=(bet->>'amount')::bigint;stake:=stake+amount;
  perform app_private.roulette_multiplier(bet,0);
 end loop;
 if stake>r.earnings then raise exception 'Your bets exceed this week’s earned chips. Banked chips cannot be wagered.';end if;
 if stake>0 then
  loop byte:=get_byte(extensions.gen_random_bytes(1),0);exit when byte<228;end loop;
  number:=byte%38;
  for bet in select value from jsonb_array_elements(p_bets) loop paid:=paid+(bet->>'amount')::bigint*app_private.roulette_multiplier(bet,number);end loop;
 end if;
 update app_private.roulette_rounds set state=case when stake=0 then 'banked' else 'spun' end,bets=p_bets,wager=stake,payout=paid,credit=earnings-stake+paid,outcome=number,request_id=p_request,settled_at=now() where id=r.id returning * into r;
 select coalesce(sum(credit),0) into bank from app_private.roulette_rounds where household_id=p_household and user_id=auth.uid() and state<>'pending';
 if bank>9007199254740991 then raise exception 'The chip bank exceeds the supported display total.';end if;
 return jsonb_build_object('round',to_jsonb(r),'bank_total',bank);
end $$;
create function public.roulette_dashboard(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.roulette_dashboard(p_household)$$;
create function public.settle_roulette_round(p_household uuid,p_round uuid,p_bets jsonb,p_request uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.settle_roulette_round(p_household,p_round,p_bets,p_request)$$;
revoke all on function app_private.ensure_roulette_rounds(uuid),app_private.roulette_multiplier(jsonb,integer),app_private.roulette_dashboard(uuid),app_private.settle_roulette_round(uuid,uuid,jsonb,uuid),public.roulette_dashboard(uuid),public.settle_roulette_round(uuid,uuid,jsonb,uuid) from public,anon,authenticated;
grant execute on function app_private.roulette_dashboard(uuid),app_private.settle_roulette_round(uuid,uuid,jsonb,uuid),public.roulette_dashboard(uuid),public.settle_roulette_round(uuid,uuid,jsonb,uuid) to authenticated;
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
 perform app_private.settle_cat_weeks(p_household);
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
  if scheme='cats' and exists(select 1 from app_private.cat_weeks cw where cw.household_id=p_household and cw.week_start=w) then
   enabled:=false;
   select coalesce(jsonb_agg(jsonb_build_object('team_id',cw.user_id,'name',coalesce(m.display_name,'Former member'),'color','#c99da9','symbol','cat','kind','individual','cat_type',cw.variant,'cat_name',cw.cat_name,'required_days',cw.required_days,'chores',app_private.cat_satisfied_days(cw),'points',(select coalesce(sum(c.points),0) from public.chore_completions c where c.household_id=p_household and c.user_id=cw.user_id and c.chore_date>=w and c.chore_date<w+7),'score',app_private.cat_satisfied_days(cw),'winner',cw.earned_at is not null,'weekly_win_points',case when cw.earned_at is not null then 1 else 0 end) order by cw.user_id),'[]'::jsonb) into scores
   from app_private.cat_weeks cw left join public.household_members m on m.household_id=cw.household_id and m.user_id=cw.user_id where cw.household_id=p_household and cw.week_start=w;
  end if;
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
 perform app_private.ensure_roulette_rounds(p_household);
end $function$;
CREATE OR REPLACE FUNCTION app_private.pre_roulette_trophy_items(p_household uuid)
 RETURNS TABLE(entity_id uuid, entity_name text, item jsonb)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select (s->>'team_id')::uuid,s->>'name',jsonb_build_object('id',r.id::text||':'||(s->>'team_id')||':'||n,'mode',r.reward_scheme,'symbol',coalesce(s->>'symbol','star'),'color',coalesce(s->>'color','#c8a55b'),'week_start',r.week_start,'won_on',r.week_end,'name',s->>'name','points',coalesce((s->>'points')::bigint,0),'chores',coalesce((s->>'chores')::integer,0),'personal_points',(select coalesce(sum((details->>'points')::bigint),0) from public.weekly_result_chores where result_id=r.id and details->>'user_id'=auth.uid()::text))
 from public.household_week_results r cross join lateral jsonb_array_elements(r.team_scores) s cross join lateral generate_series(1,coalesce((s->>'weekly_win_points')::integer,0)) n
 where r.household_id=p_household and not(r.reward_scheme='cats' and exists(select 1 from app_private.cat_weeks c where c.household_id=r.household_id and c.week_start=r.week_start))
 union all select c.user_id,coalesce(m.display_name,'Former member'),jsonb_build_object('id',c.id,'mode','cats','cat_type',c.variant,'cat_name',c.cat_name,'week_start',c.week_start,'won_on',c.week_start+7,'color','#c99da9','points',coalesce(c.award_points,(select coalesce(sum(points),0) from public.chore_completions where household_id=c.household_id and user_id=c.user_id and chore_date>=c.week_start and chore_date<c.week_start+7)),'chores',c.award_chores,'satisfied_days',coalesce(c.award_days,app_private.cat_satisfied_days(c)),'required_days',c.required_days,'name',coalesce(m.display_name,'Former member'))
 from app_private.cat_weeks c left join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household and c.earned_at is not null
$function$;
revoke all on function app_private.pre_roulette_trophy_items(uuid) from public,anon,authenticated;
create or replace function app_private.trophy_items(p_household uuid)
returns table(entity_id uuid,entity_name text,item jsonb) language sql stable security definer set search_path='' as $$
select * from app_private.pre_roulette_trophy_items(p_household)
union all
select r.user_id,coalesce(m.display_name,'Former member'),jsonb_build_object(
'id','poker-bank:'||r.user_id,'mode','poker','kind','poker_bank','bank_total',sum(r.credit),
'name',coalesce(m.display_name,'Former member'),'week_start',min(r.week_start),'won_on',max(r.week_start)+7,
'points',sum(r.credit),'rounds',jsonb_agg(jsonb_build_object('week_start',r.week_start,'earnings',r.earnings,'wager',r.wager,'payout',r.payout,'credit',r.credit,'outcome',r.outcome) order by r.week_start desc))
from app_private.roulette_rounds r left join public.household_members m on m.household_id=r.household_id and m.user_id=r.user_id
where r.household_id=p_household and r.state<>'pending'
group by r.user_id,m.display_name having sum(r.credit)>0
$$;
CREATE OR REPLACE FUNCTION app_private.community_board(p_household uuid, p_followed_only boolean DEFAULT false, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  select h.id,h.name,h.teams_enabled,h.theme,h.reward_scheme,exists(select 1 from app_private.community_follows f where f.user_id=auth.uid() and f.target_household=h.id) as following
  from public.households h join app_private.community_households e on e.household_id=h.id and e.enabled
 ), scored as(
 select e.id,e.name,e.teams_enabled,e.theme,e.reward_scheme,e.following,
 (select count(*) from (select * from app_private.case_trophy_items(e.id) where item->>'kind' is distinct from 'poker_bank'))::bigint as points,
 (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('mode',a.item->'mode','symbol',a.item->'symbol','color',a.item->'color','cat_type',a.item->'cat_type','week_start',a.item->'week_start')) order by a.item->>'week_start',a.item->>'id'),'[]'::jsonb) from (select * from app_private.case_trophy_items(e.id) where item->>'kind' is distinct from 'poker_bank') a) as trophies,
 case when e.teams_enabled then (select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'appearance',coalesce((select jsonb_build_object('frame',cs.frame,'backdrop',cs.backdrop,'finish',cs.finish) from app_private.trophy_case_styles cs where cs.household_id=e.id and cs.case_id=t.id),'{}'::jsonb),'points',(select count(*) from (select * from app_private.case_trophy_items(e.id) where item->>'kind' is distinct from 'poker_bank') a where a.entity_id=t.id),'trophies',(select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('mode',a.item->'mode','symbol',a.item->'symbol','color',a.item->'color','cat_type',a.item->'cat_type','week_start',a.item->'week_start')) order by a.item->>'week_start',a.item->>'id'),'[]'::jsonb) from (select * from app_private.case_trophy_items(e.id) where item->>'kind' is distinct from 'poker_bank') a where a.entity_id=t.id)) order by t.name),'[]'::jsonb) from public.household_teams t where t.household_id=e.id and t.active) else '[]'::jsonb end as teams
 from enrolled e
 ), ranked as(select *,dense_rank() over(order by points desc) as rank from scored),
 filtered as(select * from ranked where not coalesce(p_followed_only,false) or following or id=p_household),
 page as(select * from filtered order by points desc,lower(name),id offset p_offset limit 25)
 select jsonb_build_object('households',(select coalesce(jsonb_agg(to_jsonb(p) order by p.points desc,lower(p.name),p.id),'[]') from page p),'total',(select count(*) from filtered),'following_count',(select count(*) from enrolled where following),'score_kind','weekly_wins') into result;
 return result;
end $function$;
commit;
