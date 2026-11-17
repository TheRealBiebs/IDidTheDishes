begin;
insert into auth.users(id,email,raw_user_meta_data) values
('f7000000-0000-4000-8000-000000000001','roulette-admin@example.invalid','{}'),
('f7000000-0000-4000-8000-000000000002','roulette-member@example.invalid','{}'),
('f7000000-0000-4000-8000-000000000003','roulette-outsider@example.invalid','{}');
select set_config('request.jwt.claims','{"sub":"f7000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table roulette_qa(h uuid,r uuid,r2 uuid,round uuid,round2 uuid,saved jsonb);
grant all on roulette_qa to authenticated;
insert into roulette_qa(h) select public.create_household_with_chores('Rollback roulette QA','Admin','UTC','poker','{}');
insert into public.household_members(household_id,user_id,display_name,role) select h,'f7000000-0000-4000-8000-000000000002','Member','member' from roulette_qa;
update public.households set roulette_available_from=current_date-28 where id=(select h from roulette_qa);
insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores,teams_enabled) select h,date_trunc('week',current_date)::date-7,date_trunc('week',current_date)::date,'UTC','poker','poker','[]',false from roulette_qa;
update roulette_qa set r=(select id from public.household_week_results where household_id=h);
insert into public.weekly_result_chores(result_id,completion_id,completed_at,details) select r,gen_random_uuid(),now()-interval '8 days',jsonb_build_object('user_id','f7000000-0000-4000-8000-000000000001','points',100) from roulette_qa;
insert into public.weekly_result_chores(result_id,completion_id,completed_at,details) select r,gen_random_uuid(),now()-interval '8 days',jsonb_build_object('user_id','f7000000-0000-4000-8000-000000000002','points',40) from roulette_qa;
set local role authenticated;
do $$declare d jsonb;begin
 d:=public.roulette_dashboard((select h from roulette_qa));
 if jsonb_array_length(d->'rounds')<>1 or (d#>>'{rounds,0,earnings}')::bigint<>100 then raise exception 'Wrong private earnings %',d;end if;
 update roulette_qa set round=(d#>>'{rounds,0,id}')::uuid;
 begin perform public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),'[{"kind":"red","amount":101}]',gen_random_uuid());raise exception 'Overbet accepted';exception when others then if sqlerrm not like 'Your bets exceed%' then raise;end if;end;
 begin perform public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),'[{"kind":"split","numbers":[3,4],"amount":1}]',gen_random_uuid());raise exception 'Invalid geometry accepted';exception when others then if sqlerrm not like 'Those numbers do not form%' then raise;end if;end;
 begin perform public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),'[{"kind":"red","amount":1.5}]',gen_random_uuid());raise exception 'Fraction accepted';exception when others then if sqlerrm<>'Use positive whole-chip wagers.' then raise;end if;end;
 -- Bet one chip on all 38 pockets: exact guaranteed return 36, unbet 62, bank 98.
 select public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),jsonb_agg(jsonb_build_object('kind','straight','numbers',jsonb_build_array(n),'amount',1)),gen_random_uuid()) into d from generate_series(0,37)n;
 if (d#>>'{round,wager}')::int<>38 or (d#>>'{round,payout}')::int<>36 or (d#>>'{round,credit}')::int<>98 or (d->>'bank_total')::int<>98 then raise exception 'Wrong payout %',d;end if;
 update roulette_qa set saved=d;
 d:=public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),'[]',gen_random_uuid());
 if d<>(select saved from roulette_qa) then raise exception 'Second spin changed saved outcome/credit';end if;
end $$;
reset role;
-- Later snapshot edits cannot change a created round or banked chips.
update public.weekly_result_chores set details=details||'{"points":999}' where result_id=(select r from roulette_qa);
select app_private.ensure_roulette_rounds(h) from roulette_qa;
do $$begin if (select earnings from app_private.roulette_rounds where id=(select round from roulette_qa))<>100 then raise exception 'Earnings changed after snapshot';end if;end $$;
-- A subsequent week adds to the SAME case stack, with prior 98 outside the wager budget.
insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores,teams_enabled) select h,date_trunc('week',current_date)::date-14,date_trunc('week',current_date)::date-7,'UTC','poker','poker','[]',false from roulette_qa;
update roulette_qa set r2=(select id from public.household_week_results where household_id=h and id<>r);
insert into public.weekly_result_chores(result_id,completion_id,completed_at,details) select r2,gen_random_uuid(),now()-interval '15 days',jsonb_build_object('user_id','f7000000-0000-4000-8000-000000000001','points',10) from roulette_qa;
set local role authenticated;
do $$declare d jsonb;begin
 d:=public.roulette_dashboard((select h from roulette_qa));
 update roulette_qa set round2=(select (x->>'id')::uuid from jsonb_array_elements(d->'rounds')x where x->>'state'='pending');
 begin perform public.settle_roulette_round((select h from roulette_qa),(select round2 from roulette_qa),'[{"kind":"black","amount":11}]',gen_random_uuid());raise exception 'Bank used for bet';exception when others then if sqlerrm not like 'Your bets exceed%' then raise;end if;end;
 d:=public.settle_roulette_round((select h from roulette_qa),(select round2 from roulette_qa),'[]',gen_random_uuid());
 if (d->>'bank_total')::int<>108 or d#>>'{round,state}'<>'banked' or d#>>'{round,outcome}' is not null then raise exception 'Bank without spin failed %',d;end if;
end $$;
select set_config('request.jwt.claims','{"sub":"f7000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$declare d jsonb;begin
 d:=public.roulette_dashboard((select h from roulette_qa));
 if jsonb_array_length(d->'rounds')<>1 or (d#>>'{rounds,0,earnings}')::int<>40 or (d->>'bank_total')::int<>0 then raise exception 'Other user leaked %',d;end if;
 begin perform public.settle_roulette_round((select h from roulette_qa),(select round from roulette_qa),'[]',gen_random_uuid());raise exception 'Other user round allowed';exception when others then if sqlerrm<>'This weekly roulette round is not available to you.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f7000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
do $$begin begin perform public.roulette_dashboard((select h from roulette_qa));raise exception 'Outsider access allowed';exception when others then if sqlerrm<>'Join this household first.' then raise;end if;end;end $$;
reset role;
do $$declare n int;begin
 select count(*) into n from app_private.trophy_items((select h from roulette_qa)) where item->>'kind'='poker_bank';
 if n<>1 then raise exception 'Multiple bank stacks created';end if;
 if (select (item->>'bank_total')::int from app_private.trophy_items((select h from roulette_qa)) where item->>'kind'='poker_bank')<>108 then raise exception 'Wrong case total';end if;
 if has_function_privilege('authenticated','app_private.ensure_roulette_rounds(uuid)','execute') or has_table_privilege('authenticated','app_private.roulette_rounds','select') then raise exception 'Private ledger exposed';end if;
end $$;
select 'PASS: exact payout, retry immutability, no overbet, no bank wagering, private rounds, input validation, one accumulating trophy stack' result;
rollback;
