begin;
insert into auth.users(id,email,raw_user_meta_data) values('f8000000-0000-4000-8000-000000000001','casino-admin@example.invalid','{}'),('f8000000-0000-4000-8000-000000000002','casino-outsider@example.invalid','{}');
select set_config('request.jwt.claims','{"sub":"f8000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table casino_qa(h uuid,t uuid,c uuid,request uuid default gen_random_uuid(),response jsonb,wallet jsonb,g uuid);
grant all on casino_qa to authenticated;
insert into casino_qa(h) select public.create_household_with_chores('Rollback casino QA','Admin','UTC','poker','{}');
set local role authenticated;
update casino_qa set t=public.save_tag_with_cooldown(h,null,'Casino test chore','',100,100,'{}',true,0);
update casino_qa set c=(public.complete_chore_by_id(t,gen_random_uuid())->>'id')::uuid;
do $$declare d jsonb;begin
 d:=public.casino_dashboard((select h from casino_qa));
 if (d#>>'{wallet,available}')::bigint<>100 then raise exception 'Chore did not mint exactly once %',d;end if;
 if d::text like '%"deck"%' then raise exception 'Deck leaked';end if;
 d:=public.casino_command((select h from casino_qa),'bank',10,'{}',(select request from casino_qa));
 update casino_qa set response=d;
 if d#>>'{wallet,available}'<>'90' or d#>>'{wallet,banked}'<>'10' then raise exception 'Bank accounting failed %',d;end if;
 if public.casino_command((select h from casino_qa),'bank',10,'{}',(select request from casino_qa))<>d then raise exception 'Duplicate bank request changed balance';end if;
 begin perform public.casino_command((select h from casino_qa),'bank',11,'{}',(select request from casino_qa));raise exception 'Request reuse allowed';exception when others then if sqlerrm<>'This request was already used for a different action.' then raise;end if;end;
 begin perform public.casino_command((select h from casino_qa),'bank',-1,'{}',gen_random_uuid());raise exception 'Withdrawal allowed';exception when others then if sqlerrm not like 'Choose an amount%' then raise;end if;end;
 begin perform public.casino_command((select h from casino_qa),'slots',91,'{}',gen_random_uuid());raise exception 'Overbet allowed';exception when others then if sqlerrm not like 'Not enough available%' then raise;end if;end;
 begin perform public.casino_command((select h from casino_qa),'blackjack',3,'{}',gen_random_uuid());raise exception 'Odd blackjack allowed';exception when others then if sqlerrm not like 'Blackjack bets use even%' then raise;end if;end;
end $$;
-- Cover every roulette outcome with one-chip straights: stake 38, return 36.
do $$declare d jsonb;again jsonb;request uuid:=gen_random_uuid();bets jsonb;begin
 select jsonb_agg(jsonb_build_object('kind','straight','numbers',jsonb_build_array(n),'amount',1)) into bets from generate_series(0,37)n;
 d:=public.casino_command((select h from casino_qa),'roulette',38,jsonb_build_object('bets',bets),request);
 if d#>>'{game,payout}'<>'36' or d#>>'{wallet,available}'<>'88' or d#>>'{wallet,banked}'<>'10' then raise exception 'Roulette payout failed %',d;end if;
 again:=public.casino_command((select h from casino_qa),'roulette',38,jsonb_build_object('bets',bets),request);
 if again<>d then raise exception 'Roulette retry redrew outcome';end if;
end $$;
-- Slot results are checked against the published paytable, never client-supplied outcomes.
do $$declare d jsonb;before_wallet bigint;reels integer[];mult integer;cherries integer;i integer;begin
 for i in 1..12 loop
  before_wallet:=(public.casino_dashboard((select h from casino_qa))#>>'{wallet,available}')::bigint;
  d:=public.casino_command((select h from casino_qa),'slots',1,'{"reels":[5,5,5],"payout":999999}',gen_random_uuid());
  select array_agg(n::int) into reels from jsonb_array_elements_text(d#>'{game,outcome,reels}')n;
  select count(*) into cherries from unnest(reels)n where n=0;
  mult:=case when reels[1]=reels[2] and reels[2]=reels[3] then (array[5,8,10,15,25,40])[reels[1]+1] when cherries=2 then 2 when cherries=1 then 1 else 0 end;
  if cardinality(reels)<>3 or exists(select 1 from unnest(reels)n where n not between 0 and 5) or (d#>>'{game,payout}')::int<>mult or (d#>>'{wallet,available}')::bigint<>before_wallet-1+mult then raise exception 'Slot accounting failed %',d;end if;
 end loop;
end $$;
-- Begin a real shuffled hand; active responses hide the hole card and the deck.
do $$declare d jsonb;begin
 d:=public.casino_command((select h from casino_qa),'blackjack',2,'{}',gen_random_uuid());
 if d::text like '%"deck"%' then raise exception 'Deck exposed';end if;
 if d#>>'{game,state}'='active' then
  if jsonb_array_length(d#>'{game,dealer}')<>1 or d#>>'{game,dealer_total}' is not null then raise exception 'Dealer hole card leaked';end if;
  begin perform public.casino_command((select h from casino_qa),'slots',1,'{}',gen_random_uuid());raise exception 'Second game bypassed active hand';exception when others then if sqlerrm<>'Finish your current blackjack hand first.' then raise;end if;end;
  d:=public.casino_command((select h from casino_qa),'stand',0,jsonb_build_object('game_id',d#>>'{game,id}'),gen_random_uuid());
 end if;
 if d#>>'{game,state}'<>'settled' then raise exception 'Stand did not settle';end if;
end $$;
reset role;
-- Deterministic hand fixtures verify double, bust, soft aces, pushes and saved resumption.
insert into app_private.casino_games(household_id,user_id,kind,state,stake,player,dealer,deck) select h,'f8000000-0000-4000-8000-000000000001','blackjack','active',2,array[4,5],array[9,6],array[9,2,3,4] from casino_qa returning id;
update casino_qa set g=(select id from app_private.casino_games where household_id=h and state='active');
update app_private.casino_accounts set spendable=spendable-2,wagered=wagered+2 where household_id=(select h from casino_qa);
set local role authenticated;
do $$declare d jsonb;request uuid:=gen_random_uuid();begin
 d:=public.casino_dashboard((select h from casino_qa));if d#>>'{active_game,id}'<>(select g::text from casino_qa) then raise exception 'Active hand not resumed';end if;
 d:=public.casino_command((select h from casino_qa),'double',0,jsonb_build_object('game_id',(select g from casino_qa)),request);
 if d#>>'{game,stake}'<>'4' or d#>>'{game,payout}'<>'8' or d#>>'{game,player_total}'<>'21' then raise exception 'Double settlement failed %',d;end if;
 if public.casino_command((select h from casino_qa),'double',0,jsonb_build_object('game_id',(select g from casino_qa)),request)<>d then raise exception 'Double retried twice';end if;
end $$;
update casino_qa set wallet=public.casino_dashboard(h)->'wallet';
reset role;
-- Changing themes never remints spent chips, and chores earned in another theme do not become casino cash.
update public.households set theme='wizard',reward_scheme='points' where id=(select h from casino_qa);
update public.chore_completions set completed_at=now()-interval '1 minute' where id=(select c from casino_qa);
set local role authenticated;
do $$begin if public.casino_dashboard((select h from casino_qa))->'wallet'<>(select wallet from casino_qa) then raise exception 'Theme switch changed wallet';end if;begin perform public.casino_command((select h from casino_qa),'slots',1,'{}',gen_random_uuid());raise exception 'Other theme started game';exception when others then if sqlerrm<>'Choose the Poker Chips theme to play casino games.' then raise;end if;end;end $$;
update casino_qa set response=public.complete_chore_by_id(t,gen_random_uuid());
reset role;
update public.households set theme='poker',reward_scheme='poker' where id=(select h from casino_qa);
set local role authenticated;
do $$begin if public.casino_dashboard((select h from casino_qa))->'wallet'<>(select wallet from casino_qa) then raise exception 'Switching back restored lost chips';end if;end $$;
-- Deposit all available cash: no faucet, withdrawal or zero-balance wager exists.
do $$declare d jsonb;cash bigint;begin
 cash:=(public.casino_dashboard((select h from casino_qa))#>>'{wallet,available}')::bigint;
 d:=public.casino_command((select h from casino_qa),'bank',cash,'{}',gen_random_uuid());
 if d#>>'{wallet,available}'<>'0' then raise exception 'Bank all left usable cash';end if;
 begin perform public.casino_command((select h from casino_qa),'slots',1,'{}',gen_random_uuid());raise exception 'Empty wallet allowed gamble';exception when others then if sqlerrm not like 'Not enough available%' then raise;end if;end;
 update casino_qa set wallet=d->'wallet';
end $$;
reset role;
-- A correction creates a debt against future cash, never withdraws banked trophies.
update public.chore_completions set points=90 where id=(select c from casino_qa);
set local role authenticated;
do $$declare d jsonb;begin d:=public.casino_dashboard((select h from casino_qa));if d#>>'{wallet,adjustment_due}'<>'10' or d#>>'{wallet,banked}'<>(select wallet->>'banked' from casino_qa) then raise exception 'Adjustment touched protected bank %',d;end if;end $$;
reset role;
update public.chore_completions set points=100 where id=(select c from casino_qa);
set local role authenticated;
do $$begin if public.casino_dashboard((select h from casino_qa))->'wallet'<>(select wallet from casino_qa) then raise exception 'Rating toggling minted extra cash';end if;end $$;
select set_config('request.jwt.claims','{"sub":"f8000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin begin perform public.casino_dashboard((select h from casino_qa));raise exception 'Outsider accessed wallet';exception when others then if sqlerrm<>'Join this household first.' then raise;end if;end;end $$;
reset role;
do $$declare bank_total bigint;begin
 if (select sum(points) from public.chore_completions where household_id=(select h from casino_qa))<>200 then raise exception 'Games rewrote chore points';end if;
 if app_private.blackjack_total(array[0,13,9])<>12 or app_private.blackjack_total(array[0,9])<>21 then raise exception 'Ace rules incorrect';end if;
 if has_table_privilege('authenticated','app_private.casino_accounts','update') or has_function_privilege('authenticated','app_private.casino_random(integer)','execute') or has_function_privilege('authenticated','public.settle_roulette_round(uuid,uuid,jsonb,uuid)','execute') then raise exception 'Private wallet or retired payout exposed';end if;
 select (item->>'bank_total')::bigint into bank_total from app_private.trophy_items((select h from casino_qa)) where item->>'kind'='poker_bank';
 if bank_total<>(select banked from app_private.casino_accounts where household_id=(select h from casino_qa)) then raise exception 'Trophy bank did not follow deposits';end if;
 if exists(select 1 from app_private.casino_accounts where household_id=(select h from casino_qa) and spendable+banked<>earned+returned-wagered) then raise exception 'Ledger did not balance';end if;
end $$;
select 'PASS: chore credits, no theme regrant, separate points, permanent deposits, overbet guards, idempotent actions, slots paytable, roulette return, saved blackjack/double and private cards/ledger' result;
rollback;
