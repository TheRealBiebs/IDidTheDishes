begin;
lock table public.chore_completions,app_private.roulette_rounds in share row exclusive mode;
create table app_private.casino_accounts(
 household_id uuid not null references public.households on delete cascade,user_id uuid not null references auth.users on delete cascade,
 spendable bigint not null default 0 check(abs(spendable)<=1000000000000000),banked bigint not null default 0 check(banked between 0 and 1000000000000000),
 earned bigint not null default 0,wagered bigint not null default 0 check(wagered>=0),returned bigint not null default 0 check(returned>=0),
 primary key(household_id,user_id)
);
create index casino_accounts_user on app_private.casino_accounts(user_id);
create table app_private.casino_chore_credits(
 completion_id uuid primary key,household_id uuid not null references public.households on delete cascade,user_id uuid not null references auth.users on delete cascade,
 eligible boolean not null,credited integer not null default 0
);
create index casino_credits_house on app_private.casino_chore_credits(household_id,user_id);
create index casino_credits_user on app_private.casino_chore_credits(user_id);
create table app_private.casino_games(
 id uuid primary key default gen_random_uuid(),household_id uuid not null,user_id uuid not null,
 kind text not null check(kind in('slots','blackjack','roulette')),state text not null check(state in('active','settled')),
 stake bigint not null check(stake>0),payout bigint not null default 0 check(payout>=0),
 player integer[] not null default '{}',dealer integer[] not null default '{}',deck integer[] not null default '{}',
 bets jsonb not null default '[]',outcome jsonb not null default '{}',created_at timestamptz not null default now(),settled_at timestamptz,
 foreign key(household_id,user_id) references app_private.casino_accounts on delete cascade
);
create index casino_games_history on app_private.casino_games(household_id,user_id,created_at desc);
create unique index casino_one_active_game on app_private.casino_games(household_id,user_id) where state='active';
create table app_private.casino_requests(
 household_id uuid not null,user_id uuid not null,request_id uuid not null,input jsonb not null,result jsonb not null,created_at timestamptz not null default now(),
 primary key(household_id,user_id,request_id),foreign key(household_id,user_id) references app_private.casino_accounts on delete cascade
);
create table app_private.casino_deposits(
 id uuid primary key default gen_random_uuid(),household_id uuid not null,user_id uuid not null,amount bigint not null check(amount>0),source text not null default 'bank',created_at timestamptz not null default now(),
 foreign key(household_id,user_id) references app_private.casino_accounts on delete cascade
);
create index casino_deposits_history on app_private.casino_deposits(household_id,user_id,created_at desc);
do $$declare t text;begin foreach t in array array['casino_accounts','casino_chore_credits','casino_games','casino_requests','casino_deposits'] loop
 execute format('alter table app_private.%I enable row level security',t);
 execute format('create policy casino_private on app_private.%I to anon,authenticated using(false) with check(false)',t);
 execute format('revoke all on app_private.%I from public,anon,authenticated',t);
end loop;end $$;

-- One-time cutover: old banked winnings stay safe; pending weekly pots become playable.
insert into app_private.casino_accounts(household_id,user_id,spendable,banked,earned,wagered,returned)
select household_id,user_id,sum(case when state='pending' then earnings else 0 end),sum(credit),sum(earnings),sum(wager),sum(payout)
from app_private.roulette_rounds group by household_id,user_id;
insert into app_private.casino_deposits(household_id,user_id,amount,source)
select household_id,user_id,banked,'legacy' from app_private.casino_accounts where banked>0;
-- Historical completions are marked, never re-minted by theme changes. Only current-week
-- poker chores not already represented by a weekly round are funded at cutover.
insert into app_private.casino_chore_credits(completion_id,household_id,user_id,eligible,credited)
select c.id,c.household_id,c.user_id,
 h.reward_scheme='poker' and c.chore_date>=date_trunc('week',now() at time zone h.timezone)::date
 and not exists(select 1 from app_private.roulette_rounds r where r.household_id=c.household_id and r.user_id=c.user_id and c.chore_date>=r.week_start and c.chore_date<r.week_start+7),c.points
from public.chore_completions c join public.households h on h.id=c.household_id;
insert into app_private.casino_accounts(household_id,user_id,spendable,earned)
select household_id,user_id,sum(credited),sum(credited) from app_private.casino_chore_credits where eligible group by household_id,user_id
on conflict(household_id,user_id) do update set spendable=app_private.casino_accounts.spendable+excluded.spendable,earned=app_private.casino_accounts.earned+excluded.earned;

create function app_private.casino_chore_credit() returns trigger language plpgsql security definer set search_path='' as $$
declare c app_private.casino_chore_credits;allow_credit boolean;delta bigint;begin
 if tg_op='INSERT' then
  select reward_scheme='poker' into allow_credit from public.households where id=new.household_id;
  insert into app_private.casino_chore_credits values(new.id,new.household_id,new.user_id,coalesce(allow_credit,false),new.points) on conflict(completion_id) do nothing;
  if found and allow_credit then
   insert into app_private.casino_accounts(household_id,user_id,spendable,earned) values(new.household_id,new.user_id,new.points,new.points)
   on conflict(household_id,user_id) do update set spendable=app_private.casino_accounts.spendable+excluded.spendable,earned=app_private.casino_accounts.earned+excluded.earned;
  end if;
 else
  select * into c from app_private.casino_chore_credits where completion_id=old.id for update;
  if not found then return null;end if;
  if tg_op='UPDATE' and (new.household_id<>old.household_id or new.user_id<>old.user_id) then raise exception 'Completion ownership cannot be changed.';end if;
  delta:=case when tg_op='DELETE' then 0 else new.points end-c.credited;
  update app_private.casino_chore_credits set credited=case when tg_op='DELETE' then 0 else new.points end where completion_id=old.id;
  if c.eligible and delta<>0 then update app_private.casino_accounts set spendable=spendable+delta,earned=earned+delta where household_id=c.household_id and user_id=c.user_id;end if;
 end if;
 return null;
end $$;
create trigger casino_chore_credit after insert or update or delete on public.chore_completions for each row execute function app_private.casino_chore_credit();

create function app_private.casino_random(p_n integer) returns integer language plpgsql volatile set search_path='' as $$
declare b integer;lim integer;begin
 if p_n not between 1 and 256 then raise exception 'Invalid random range';end if;
 lim:=(256/p_n)*p_n;
 loop b:=get_byte(extensions.gen_random_bytes(1),0);exit when b<lim;end loop;return b%p_n;
end $$;
create function app_private.blackjack_total(cards integer[]) returns integer language plpgsql immutable set search_path='' as $$
declare n integer;total integer:=0;aces integer:=0;begin
 foreach n in array cards loop if n%13=0 then total:=total+11;aces:=aces+1;else total:=total+least(10,n%13+1);end if;end loop;
 while total>21 and aces>0 loop total:=total-10;aces:=aces-1;end loop;return total;
end $$;
create function app_private.casino_wallet(p_household uuid,p_user uuid) returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('available',greatest(0,a.spendable),'adjustment_due',greatest(0,-a.spendable),'banked',a.banked,'earned',a.earned,'wagered',a.wagered,'returned',a.returned,'net_gambling',a.returned-a.wagered)
from app_private.casino_accounts a where household_id=p_household and user_id=p_user
$$;
create function app_private.casino_game_view(g app_private.casino_games) returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('id',g.id,'kind',g.kind,'state',g.state,'stake',g.stake,'payout',g.payout,'player',g.player,
'dealer',case when g.kind='blackjack' and g.state='active' then g.dealer[1:1] else g.dealer end,
'player_total',app_private.blackjack_total(g.player),'dealer_total',case when g.state='active' then null else app_private.blackjack_total(g.dealer) end,
'bets',g.bets,'outcome',g.outcome,'created_at',g.created_at)
$$;
create function app_private.casino_dashboard(p_household uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 insert into app_private.casino_accounts(household_id,user_id) values(p_household,auth.uid()) on conflict do nothing;
 select jsonb_build_object('wallet',app_private.casino_wallet(p_household,auth.uid()),'enabled',h.reward_scheme='poker',
 'balances',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'name',m.display_name,'available',greatest(0,coalesce(a.spendable,0)),'banked',coalesce(a.banked,0)) order by m.display_name),'[]') from public.household_members m left join app_private.casino_accounts a on a.household_id=m.household_id and a.user_id=m.user_id where m.household_id=p_household),
 'active_game',(select app_private.casino_game_view(g) from app_private.casino_games g where g.household_id=p_household and g.user_id=auth.uid() and g.state='active'),
 'history',(select coalesce(jsonb_agg(app_private.casino_game_view(g) order by g.created_at desc),'[]') from(select * from app_private.casino_games where household_id=p_household and user_id=auth.uid() order by created_at desc limit 15)g)) into result
 from public.households h where h.id=p_household;
 return result;
end $$;
create function app_private.casino_command(p_household uuid,p_action text,p_amount bigint,p_details jsonb,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a app_private.casino_accounts;g app_private.casino_games;prior app_private.casino_requests;input jsonb;result jsonb;
 stake bigint:=p_amount;paid bigint:=0;bet jsonb;num integer;reels integer[];mult integer;cherries integer;i integer;j integer;tmp integer;cards integer[];pt integer;dt integer;verdict text;deposit uuid;
begin
 if auth.uid() is null or not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if p_request is null or p_action is null or p_details is null or jsonb_typeof(p_details)<>'object' then raise exception 'A valid casino request is required.';end if;
 insert into app_private.casino_accounts(household_id,user_id) values(p_household,auth.uid()) on conflict do nothing;
 select * into a from app_private.casino_accounts where household_id=p_household and user_id=auth.uid() for update;
 input:=jsonb_build_object('action',p_action,'amount',p_amount,'details',p_details);
 select * into prior from app_private.casino_requests where household_id=p_household and user_id=auth.uid() and request_id=p_request;
 if found then
  if prior.input<>input then raise exception 'This request was already used for a different action.';end if;
  result:=prior.result||jsonb_build_object('wallet',app_private.casino_wallet(p_household,auth.uid()));
  if result#>>'{game,id}' is not null then select * into g from app_private.casino_games where id=(result#>>'{game,id}')::uuid;result:=result||jsonb_build_object('game',app_private.casino_game_view(g));end if;
  return result;
 end if;
 if p_action='bank' then
  if stake is null or stake<1 or stake>a.spendable then raise exception 'Choose an amount from your available chips to bank.';end if;
  update app_private.casino_accounts set spendable=spendable-stake,banked=banked+stake where household_id=p_household and user_id=auth.uid();
  insert into app_private.casino_deposits(household_id,user_id,amount) values(p_household,auth.uid(),stake) returning id into deposit;
  result:=jsonb_build_object('banked',stake,'deposit_id',deposit);
 elsif p_action in('hit','stand','double') then
  select * into g from app_private.casino_games where id=(p_details->>'game_id')::uuid and household_id=p_household and user_id=auth.uid() and kind='blackjack' for update;
  if not found or g.state<>'active' then raise exception 'There is no active blackjack hand for this action.';end if;
  if p_amount is distinct from 0::bigint then raise exception 'Blackjack actions do not accept a client stake.';end if;
  if p_action='double' then
   if cardinality(g.player)<>2 or a.spendable<g.stake then raise exception 'Double requires two cards and enough available chips.';end if;
   update app_private.casino_accounts set spendable=spendable-g.stake,wagered=wagered+g.stake where household_id=p_household and user_id=auth.uid();g.stake:=g.stake*2;
  end if;
  if p_action in('hit','double') then g.player:=g.player||g.deck[1];g.deck:=g.deck[2:];end if;
  pt:=app_private.blackjack_total(g.player);
  if p_action<>'hit' or pt>=21 then
   if pt<=21 then while app_private.blackjack_total(g.dealer)<17 loop g.dealer:=g.dealer||g.deck[1];g.deck:=g.deck[2:];end loop;end if;
   dt:=app_private.blackjack_total(g.dealer);
   paid:=case when pt>21 then 0 when dt>21 or pt>dt then g.stake*2 when pt=dt then g.stake else 0 end;
   verdict:=case when pt>21 then 'Bust' when dt>21 then 'Dealer busts' when pt>dt then 'You win' when pt=dt then 'Push' else 'Dealer wins' end;
   g.state:='settled';g.payout:=paid;g.settled_at:=now();g.outcome:=jsonb_build_object('label',verdict);
   update app_private.casino_accounts set spendable=spendable+paid,returned=returned+paid where household_id=p_household and user_id=auth.uid();
  end if;
  update app_private.casino_games set player=g.player,dealer=g.dealer,deck=g.deck,stake=g.stake,state=g.state,payout=g.payout,settled_at=g.settled_at,outcome=g.outcome where id=g.id returning * into g;
  result:=jsonb_build_object('game',app_private.casino_game_view(g));
 elsif p_action in('roulette','slots','blackjack') then
  if not exists(select 1 from public.households where id=p_household and reward_scheme='poker') then raise exception 'Choose the Poker Chips theme to play casino games.';end if;
  if exists(select 1 from app_private.casino_games where household_id=p_household and user_id=auth.uid() and state='active') then raise exception 'Finish your current blackjack hand first.';end if;
  if stake is null or stake<1 or stake>1000000000000 or stake>a.spendable then raise exception 'Not enough available chips. Complete chores to earn more.';end if;
  if p_action='roulette' then
   if jsonb_typeof(p_details->'bets') is distinct from 'array' or jsonb_array_length(p_details->'bets') not between 1 and 256 then raise exception 'Place at least one valid roulette bet.';end if;
   paid:=0;
   for bet in select value from jsonb_array_elements(p_details->'bets') loop
    if (bet->>'amount') is null or bet->>'amount' !~ '^[1-9][0-9]{0,12}$' then raise exception 'Use positive whole-chip wagers.';end if;
    paid:=paid+(bet->>'amount')::bigint;perform app_private.roulette_multiplier(bet,0);
   end loop;
   if paid<>stake then raise exception 'Roulette stake must match the bets.';end if;
  elsif p_action='blackjack' and stake%2<>0 then raise exception 'Blackjack bets use even chip amounts so a natural pays exactly 3:2.';
  end if;
  update app_private.casino_accounts set spendable=spendable-stake,wagered=wagered+stake where household_id=p_household and user_id=auth.uid();paid:=0;
  if p_action='roulette' then
   num:=app_private.casino_random(38);
   for bet in select value from jsonb_array_elements(p_details->'bets') loop paid:=paid+(bet->>'amount')::bigint*app_private.roulette_multiplier(bet,num);end loop;
   insert into app_private.casino_games(household_id,user_id,kind,state,stake,payout,bets,outcome,settled_at) values(p_household,auth.uid(),'roulette','settled',stake,paid,p_details->'bets',jsonb_build_object('number',num,'label',case when num=37 then '00' else num::text end),now()) returning * into g;
  elsif p_action='slots' then
   reels:=array[app_private.casino_random(6),app_private.casino_random(6),app_private.casino_random(6)];
   select count(*) into cherries from unnest(reels)n where n=0;
   mult:=case when reels[1]=reels[2] and reels[2]=reels[3] then (array[5,8,10,15,25,40])[reels[1]+1] when cherries=2 then 2 when cherries=1 then 1 else 0 end;paid:=stake*mult;
   insert into app_private.casino_games(household_id,user_id,kind,state,stake,payout,outcome,settled_at) values(p_household,auth.uid(),'slots','settled',stake,paid,jsonb_build_object('reels',reels,'multiplier',mult,'label',case when paid>stake then 'Winner!' when paid=stake then 'Stake returned' else 'No match' end),now()) returning * into g;
  else
   cards:=array(select generate_series(0,51));
   for i in reverse 52..2 loop j:=app_private.casino_random(i)+1;tmp:=cards[i];cards[i]:=cards[j];cards[j]:=tmp;end loop;
   pt:=app_private.blackjack_total(array[cards[1],cards[3]]);dt:=app_private.blackjack_total(array[cards[2],cards[4]]);
   if pt=21 or dt=21 then paid:=case when pt=dt then stake when pt=21 then stake*5/2 else 0 end;end if;
   insert into app_private.casino_games(household_id,user_id,kind,state,stake,payout,player,dealer,deck,outcome,settled_at)
   values(p_household,auth.uid(),'blackjack',case when pt=21 or dt=21 then 'settled' else 'active' end,stake,paid,array[cards[1],cards[3]],array[cards[2],cards[4]],cards[5:],jsonb_build_object('label',case when pt=21 and dt=21 then 'Push' when pt=21 then 'Blackjack!' when dt=21 then 'Dealer blackjack' else 'Your turn' end),case when pt=21 or dt=21 then now() else null end) returning * into g;
  end if;
  if paid>0 then update app_private.casino_accounts set spendable=spendable+paid,returned=returned+paid where household_id=p_household and user_id=auth.uid();end if;
  result:=jsonb_build_object('game',app_private.casino_game_view(g));
 else raise exception 'Unknown casino action.';
 end if;
 result:=result||jsonb_build_object('wallet',app_private.casino_wallet(p_household,auth.uid()));
 insert into app_private.casino_requests values(p_household,auth.uid(),p_request,input,result,now());
 return result;
end $$;

-- Retire the old weekly pots and payout path; historical rows remain for auditing.
create or replace function app_private.ensure_roulette_rounds(p_household uuid) returns void language plpgsql security definer set search_path='' as $$begin return;end $$;
create or replace function app_private.roulette_dashboard(p_household uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;return '{"rounds":[],"bank_total":0}'::jsonb;end $$;
revoke execute on function public.settle_roulette_round(uuid,uuid,jsonb,uuid),app_private.settle_roulette_round(uuid,uuid,jsonb,uuid) from public,anon,authenticated;
create or replace function app_private.trophy_items(p_household uuid) returns table(entity_id uuid,entity_name text,item jsonb) language sql stable security definer set search_path='' as $$
select * from app_private.pre_roulette_trophy_items(p_household)
union all
select a.user_id,coalesce(m.display_name,'Former member'),jsonb_build_object('id','poker-bank:'||a.user_id,'mode','poker','kind','poker_bank','bank_total',a.banked,'name',coalesce(m.display_name,'Former member'),'points',a.banked,'won_on',(select max(created_at)::date from app_private.casino_deposits where household_id=a.household_id and user_id=a.user_id),'deposits',(select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'amount',d.amount,'date',d.created_at,'source',d.source) order by d.created_at desc),'[]') from app_private.casino_deposits d where d.household_id=a.household_id and d.user_id=a.user_id))
from app_private.casino_accounts a left join public.household_members m on m.household_id=a.household_id and m.user_id=a.user_id where a.household_id=p_household and a.banked>0
$$;
create function public.casino_dashboard(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.casino_dashboard(p_household)$$;
create function public.casino_command(p_household uuid,p_action text,p_amount bigint,p_details jsonb,p_request uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.casino_command(p_household,p_action,p_amount,p_details,p_request)$$;
revoke all on function app_private.casino_chore_credit(),app_private.casino_random(integer),app_private.blackjack_total(integer[]),app_private.casino_wallet(uuid,uuid),app_private.casino_game_view(app_private.casino_games),app_private.casino_dashboard(uuid),app_private.casino_command(uuid,text,bigint,jsonb,uuid),public.casino_dashboard(uuid),public.casino_command(uuid,text,bigint,jsonb,uuid) from public,anon,authenticated;
grant execute on function app_private.casino_dashboard(uuid),app_private.casino_command(uuid,text,bigint,jsonb,uuid),public.casino_dashboard(uuid),public.casino_command(uuid,text,bigint,jsonb,uuid) to authenticated;
commit;
