begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('fc000000-0000-4000-8000-000000000001','wheel-admin@example.invalid','{}'),
 ('fc000000-0000-4000-8000-000000000002','wheel-member@example.invalid','{}'),
 ('fc000000-0000-4000-8000-000000000003','wheel-outsider@example.invalid','{}');
select set_config('request.jwt.claims','{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table wheel_qa(h uuid,first_roll jsonb,sticker_roll jsonb);
grant all on wheel_qa to authenticated;
insert into wheel_qa(h) select public.create_household_with_chores('Rollback wheels QA','Admin','UTC','wizard','{}');
insert into public.household_members(household_id,user_id,display_name,role) select h,'fc000000-0000-4000-8000-000000000002','Member','member' from wheel_qa;
set local role authenticated;
select public.save_unexpected_wheels(h,'{"standard":{"enabled":true,"values":[7,7,7,7]},"low":{"enabled":false,"values":[0,1,1,2]},"high":{"enabled":true,"values":[17,17,17,17]}}') from wheel_qa;
do $$begin
 if app_private.valid_unexpected_wheels('{"standard":{"enabled":true,"values":[-1,0,1,2]},"low":{"enabled":false,"values":[0,0,0,0]},"high":{"enabled":false,"values":[0,0,0,0]}}') then raise exception 'Negative reward accepted';end if;
 if app_private.valid_unexpected_wheels('{"standard":{"enabled":true,"values":[1.5,0,1,2]},"low":{"enabled":false,"values":[0,0,0,0]},"high":{"enabled":false,"values":[0,0,0,0]}}') then raise exception 'Fraction accepted';end if;
 if app_private.valid_unexpected_wheels('{"standard":{"enabled":true,"values":[1001,0,1,2]},"low":{"enabled":false,"values":[0,0,0,0]},"high":{"enabled":false,"values":[0,0,0,0]}}') then raise exception 'Out of bounds accepted';end if;
 if app_private.valid_unexpected_wheels('{}') then raise exception 'Missing wheels accepted';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"fc000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin
 begin perform public.save_unexpected_wheels((select h from wheel_qa),'{}');raise exception 'Member changed settings';exception when others then if sqlerrm not like 'Only household admins%' then raise;end if;end;
 begin perform public.log_unexpected_chore_wheel((select h from wheel_qa),'Disabled low chore',gen_random_uuid(),'low');raise exception 'Disabled wheel accepted';exception when others then if sqlerrm not like 'This chore wheel is disabled%' then raise;end if;end;
 begin perform public.log_unexpected_chore_wheel((select h from wheel_qa),'  ',gen_random_uuid(),'high');raise exception 'Blank description accepted';exception when others then if sqlerrm not like 'Describe the chore%' then raise;end if;end;
end $$;
update wheel_qa set first_roll=public.log_unexpected_chore_wheel(h,'Unexpected high effort job','fc000000-0000-4000-8000-000000000010','high');
do $$begin
 if (select (first_roll->>'points')::integer from wheel_qa)<>17 then raise exception 'Custom points not used';end if;
 if (select first_roll->'unexpected_reward'->'options' from wheel_qa)<>'[17,17,17,17]'::jsonb then raise exception 'Missing immutable options';end if;
 if (select (first_roll->'unexpected_reward'->>'index')::integer from wheel_qa) not between 0 and 3 then raise exception 'Invalid wheel index';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.save_unexpected_wheels(h,'{"standard":{"enabled":true,"values":[1000,1000,1000,1000]},"low":{"enabled":true,"values":[0,0,0,0]},"high":{"enabled":false,"values":[1,1,1,1]}}') from wheel_qa;
select set_config('request.jwt.claims','{"sub":"fc000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$declare retried jsonb;begin
 select public.log_unexpected_chore_wheel(h,'Unexpected high effort job','fc000000-0000-4000-8000-000000000010','high') into retried from wheel_qa;
 if retried is distinct from (select first_roll from wheel_qa) then raise exception 'Retry rerolled after settings changed';end if;
 begin perform public.log_unexpected_chore_wheel((select h from wheel_qa),'Unexpected high effort job','fc000000-0000-4000-8000-000000000010','low');raise exception 'Request reused with different wheel';exception when others then if sqlerrm not like 'This submission ID was already used%' then raise;end if;end;
 if (public.log_unexpected_chore((select h from wheel_qa),'Legacy standard call',gen_random_uuid())->>'points')::integer<>1000 then raise exception 'Legacy RPC lost standard settings';end if;
 if (public.log_unexpected_chore_wheel((select h from wheel_qa),'Zero point chore',gen_random_uuid(),'low')->>'points')::integer<>0 then raise exception 'Zero reward failed';end if;
end $$;
reset role;
update public.households set reward_scheme='stars',theme='parents' where id=(select h from wheel_qa);
set local role authenticated;
update wheel_qa set sticker_roll=public.log_unexpected_chore_wheel(h,'Surprise sticker chore','fc000000-0000-4000-8000-000000000011','standard');
do $$begin
 if (select (sticker_roll->>'points')::integer from wheel_qa)<>0 then raise exception 'Sticker chore granted points';end if;
 if (select sticker_roll->'unexpected_reward'->>'type' from wheel_qa)<>'sticker' then raise exception 'Wrong sticker reward type';end if;
 if (select sticker_roll->>'calendar_sticker' from wheel_qa) is distinct from (select sticker_roll->'unexpected_reward'->>'sticker' from wheel_qa) then raise exception 'Calendar trigger replaced random sticker';end if;
 if (select jsonb_array_length(sticker_roll->'unexpected_reward'->'options') from wheel_qa)<>17 then raise exception 'Wrong sticker pool';end if;
 if not exists(select 1 from jsonb_array_elements(public.reward_calendar((select h from wheel_qa),date_trunc('month',current_date)::date)) r where r->>'chore'='Surprise sticker chore' and r->>'calendar_sticker'=(select sticker_roll->>'calendar_sticker' from wheel_qa)) then raise exception 'Random sticker not on calendar';end if;
end $$;
reset role;
update public.households set reward_scheme='cats',theme='cats',cat_care_mode='chores' where id=(select h from wheel_qa);
set local role authenticated;
do $$begin
 begin perform public.log_unexpected_chore_wheel((select h from wheel_qa),'Must not bypass cat chores',gen_random_uuid(),'standard');raise exception 'Specific-chore cats accepted random points';exception when others then if sqlerrm not like 'Random chore wheels are unavailable%' then raise;end if;end;
 begin perform public.log_unexpected_chore((select h from wheel_qa),'Legacy cat bypass',gen_random_uuid());raise exception 'Legacy cat bypass accepted';exception when others then if sqlerrm not like 'Random chore wheels are unavailable%' then raise;end if;end;
 if public.log_unexpected_chore_wheel((select h from wheel_qa),'Surprise sticker chore','fc000000-0000-4000-8000-000000000011','standard') is distinct from (select sticker_roll from wheel_qa) then raise exception 'Theme change broke retry snapshot';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"fc000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
do $$begin
 begin perform public.log_unexpected_chore_wheel((select h from wheel_qa),'Outsider',gen_random_uuid(),'standard');raise exception 'Outsider accepted';exception when others then if sqlerrm not like 'Join this household%' then raise;end if;end;
 if has_function_privilege('anon','public.log_unexpected_chore_wheel(uuid,text,uuid,text)','execute') or has_function_privilege('anon','public.save_unexpected_wheels(uuid,jsonb)','execute') then raise exception 'Anonymous wheel mutation exposed';end if;
end $$;
reset role;
do $$begin
 if exists(select 1 from public.notifications where household_id=(select h from wheel_qa) and completion_id=((select sticker_roll from wheel_qa)->>'id')::uuid and message like '%points%') then raise exception 'Sticker notification still mentions points';end if;
end $$;
select 'PASS: admin settings, custom and disabled wheels, validation, immutable retry outcomes, legacy compatibility, random calendar sticker without points, cat chore mode exclusion and member isolation' result;
rollback;
