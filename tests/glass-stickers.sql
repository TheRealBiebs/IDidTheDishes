begin;
insert into auth.users(id,email,raw_user_meta_data) values('fa000000-0000-4000-8000-000000000001','glass-a@example.invalid','{}'),('fa000000-0000-4000-8000-000000000002','glass-b@example.invalid','{}'),('fa000000-0000-4000-8000-000000000003','glass-c@example.invalid','{}');
select set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table glass_qa(h uuid,other_house uuid,t uuid,foreign_tag uuid,sticker uuid,other_sticker uuid,w date);
grant all on glass_qa to authenticated;
insert into glass_qa(h,other_house,w) select public.create_household_with_chores('Rollback rainbow QA','A','UTC','parents','{}'),public.create_household_with_chores('Rollback foreign QA','A','UTC','parents','{}'),date_trunc('week',current_date)::date-7;
insert into public.household_members(household_id,user_id,display_name,role) select h,'fa000000-0000-4000-8000-000000000002'::uuid,'B','member' from glass_qa union all select h,'fa000000-0000-4000-8000-000000000003'::uuid,'C','member' from glass_qa;
set local role authenticated;
update glass_qa set t=public.save_tag_with_cooldown(h,null,'Rainbow chore','',10,100,'{}',true,0),foreign_tag=public.save_tag_with_cooldown(other_house,null,'Foreign chore','',10,100,'{}',true,0);
select public.save_sticker_settings(h,'unicorn',jsonb_build_object(t,'rainbow')) from glass_qa;
reset role;
update public.households set teams_enabled=true,weekly_competition_started_at=(select w from glass_qa)::timestamp at time zone 'UTC' where id=(select h from glass_qa);
update app_private.weekly_history set effective_at=((select w from glass_qa)::timestamp at time zone 'UTC')-interval '1 day' where household_id=(select h from glass_qa);
-- A and C collect on seven distinct days; B logs seven chores on one day.
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,base_points,completion_kind,completed_at,chore_date,request_id)
select h,u,t,'Rainbow chore',10,10,'tag',(w+i)::timestamp at time zone 'UTC',w+i,gen_random_uuid() from glass_qa cross join generate_series(0,6)i cross join unnest(array['fa000000-0000-4000-8000-000000000001'::uuid,'fa000000-0000-4000-8000-000000000003'::uuid])u;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,base_points,completion_kind,completed_at,chore_date,request_id)
select h,'fa000000-0000-4000-8000-000000000002',t,'Rainbow chore',10,10,'tag',w::timestamp at time zone 'UTC',w,gen_random_uuid() from glass_qa cross join generate_series(0,6)i;
set local role authenticated;
select public.household_weekly_scores(h) from glass_qa;
reset role;
do $$declare r public.household_week_results;begin
 if (select count(*) from app_private.glass_stickers where household_id=(select h from glass_qa))<>2 then raise exception 'Not every seven-day member earned one, or one-day member earned one';end if;
 if not exists(select 1 from app_private.glass_stickers where household_id=(select h from glass_qa) and user_id='fa000000-0000-4000-8000-000000000003' and design='unicorn' and days=7) then raise exception 'Wrong weekly design';end if;
 select * into r from public.household_week_results where household_id=(select h from glass_qa) and week_start=(select w from glass_qa);
 if r.teams_enabled or (select count(*) from jsonb_array_elements(r.team_scores)s where (s->>'winner')::boolean)<>2 then raise exception 'Sticker mode still ranks teams instead of individual streaks';end if;
end $$;
update glass_qa set sticker=(select id from app_private.glass_stickers where household_id=h and user_id='fa000000-0000-4000-8000-000000000001'),other_sticker=(select id from app_private.glass_stickers where household_id=h and user_id='fa000000-0000-4000-8000-000000000003');
set local role authenticated;
select public.household_weekly_scores(h) from glass_qa;
do $$declare d jsonb;begin
 d:=public.place_glass_sticker((select sticker from glass_qa),25,60,15);
 if d<>'{"x":25,"y":60,"angle":15}'::jsonb then raise exception 'Placement was not saved';end if;
 perform public.place_glass_sticker((select sticker from glass_qa),25,60,15);
 begin perform public.place_glass_sticker((select other_sticker from glass_qa),50,50,0);raise exception 'Moved another person’s sticker';exception when others then if sqlerrm<>'Choose a sticker you earned in your household.' then raise;end if;end;
 begin perform public.place_glass_sticker((select sticker from glass_qa),101,50,0);raise exception 'Out of glass placement accepted';exception when others then if sqlerrm<>'Place the sticker inside the glass.' then raise;end if;end;
 begin perform public.save_sticker_settings((select h from glass_qa),'rainbow',jsonb_build_object((select foreign_tag from glass_qa),'kitty'));raise exception 'Changed foreign chore';exception when others then if sqlerrm<>'Only available chores from this household can be configured.' then raise;end if;end;
 perform public.save_sticker_settings((select h from glass_qa),'dolphin',jsonb_build_object((select t from glass_qa),'kitty'));
end $$;
select set_config('request.jwt.claims','{"sub":"fa000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin begin perform public.save_sticker_settings((select h from glass_qa),'heart','{}');raise exception 'Member changed sticker settings';exception when others then if sqlerrm<>'Only household admins can configure stickers.' then raise;end if;end;end $$;
reset role;
-- Old spade-chip trophies are suppressed, while genuine chip banks remain.
insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores,teams_enabled) select h,w-7,w,'UTC','poker','poker',jsonb_build_array(jsonb_build_object('team_id','fa000000-0000-4000-8000-000000000001','name','A','points',100,'chores',10,'winner',true,'weekly_win_points',1)),false from glass_qa;
insert into app_private.casino_accounts(household_id,user_id,banked,earned) select h,'fa000000-0000-4000-8000-000000000001',5000,5000 from glass_qa on conflict(household_id,user_id) do update set banked=5000,earned=5000;
do $$begin
 if exists(select 1 from app_private.trophy_items((select h from glass_qa)) where item->>'mode'='poker' and item->>'kind' is distinct from 'poker_bank') then raise exception 'Spade trophy still exists';end if;
 if not exists(select 1 from app_private.trophy_items((select h from glass_qa)) where item->>'kind'='poker_bank' and item->>'bank_total'='5000') then raise exception 'Chip bank disappeared';end if;
 if (select count(*) from app_private.glass_stickers where household_id=(select h from glass_qa))<>2 then raise exception 'Read/retry duplicated stickers';end if;
 if (select design from app_private.glass_stickers where id=(select sticker from glass_qa))<>'unicorn' then raise exception 'Changing next design rewrote earned art';end if;
 if (select calendar_sticker from public.chore_tags where id=(select t from glass_qa))<>'kitty' then raise exception 'Chore icon not saved in reward settings';end if;
 if has_table_privilege('authenticated','app_private.glass_stickers','update') or has_function_privilege('authenticated','app_private.ensure_glass_stickers(uuid)','execute') then raise exception 'Awards or placements exposed';end if;
end $$;
select 'PASS: seven distinct days, all qualifying people despite teams, immutable design, one award per week, owner-only bounded placement, admin-only chore choices, no chip trophies, preserved chip banks' result;
rollback;
