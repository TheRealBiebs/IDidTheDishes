begin;
create temp table cat_qa(a uuid,b uuid,c uuid,o uuid,h uuid,tag uuid,w date,past date);
grant all on cat_qa to authenticated,anon;
insert into cat_qa(a,b,c,o) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'cat-a-'||a||'@example.invalid' from cat_qa union all select b,'cat-b-'||b||'@example.invalid' from cat_qa union all select c,'cat-c-'||c||'@example.invalid' from cat_qa union all select o,'cat-o-'||o||'@example.invalid' from cat_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from cat_qa),'role','authenticated')::text,true);
set local role authenticated;
update cat_qa set h=public.create_household_experience('Cat QA','Admin','UTC','cats','{}');
update cat_qa set tag=public.save_chore_rewards(h,null,'Cat care QA','',5,100,'{}',true,0,'daily',null,'{}'),w=date_trunc('week',now() at time zone 'UTC')::date,past=date_trunc('week',now() at time zone 'UTC')::date-7;
reset role;
insert into public.household_members(household_id,user_id,display_name,role) select h,b,'Member B','member' from cat_qa union all select h,c,'Member C','member' from cat_qa;
set local role authenticated;
do $$declare d jsonb;begin
 d:=public.cat_dashboard((select h from cat_qa));
 if jsonb_array_length(d->'cats')<>3 then raise exception 'Every member must get a cat';end if;
 begin perform public.care_for_cat((select h from cat_qa),'feed');raise exception 'Feed unlocked at zero';exception when others then if sqlerrm<>'Do more chores to unlock this activity.' then raise;end if;end;
end $$;
reset role;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,a,tag,'Cat care QA',5,(now() at time zone 'UTC')::date,gen_random_uuid() from cat_qa;
set local role authenticated;
select public.care_for_cat(h,'feed'),public.care_for_cat(h,'feed') from cat_qa;
do $$begin
 begin perform public.care_for_cat((select h from cat_qa),'play');raise exception 'Play unlocked early';exception when others then if sqlerrm<>'Do more chores to unlock this activity.' then raise;end if;end;
end $$;
reset role;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,a,tag,'Cat care QA',5,(now() at time zone 'UTC')::date,gen_random_uuid() from cat_qa;
set local role authenticated;
select public.care_for_cat(h,'play') from cat_qa;
reset role;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,a,tag,'Cat care QA',5,(now() at time zone 'UTC')::date,gen_random_uuid() from cat_qa;
set local role authenticated;
select public.care_for_cat(h,'cuddle') from cat_qa;
reset role;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,a,tag,'Cat care QA',5,(now() at time zone 'UTC')::date,gen_random_uuid() from cat_qa;
set local role authenticated;
do $$begin
 begin perform public.care_for_cat((select h from cat_qa),'feed');raise exception 'Sleeping cat woke';exception when others then if sqlerrm<>'Your cat is satisfied and sleeping until tomorrow.' then raise;end if;end;
 perform public.set_cat_daily_target((select h from cat_qa),40);
 if (select (x->>'target')::integer from jsonb_array_elements(public.cat_dashboard((select h from cat_qa))->'cats') x where x->>'user_id'=(select a::text from cat_qa))<>40 then raise exception 'Today target did not update immediately';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from cat_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.set_cat_daily_target((select h from cat_qa),1);raise exception 'Member changed target';exception when others then if sqlerrm<>'Only household admins can set the cat target.' then raise;end if;end;
 if exists(select 1 from jsonb_array_elements(public.cat_dashboard((select h from cat_qa))->'cats') x where x->>'user_id'=(select b::text from cat_qa) and (x->>'points')::integer<>0) then raise exception 'Member received someone else points';end if;
end $$;
reset role;
insert into app_private.cat_weeks(household_id,user_id,week_start,eligible_from,variant,targets,timezone) select h,a,past,past,2,array_fill(20,array[7]),'UTC' from cat_qa union all select h,b,past,past,1,array_fill(20,array[7]),'UTC' from cat_qa union all select h,c,past,past,27,array_fill(20,array[7]),'UTC' from cat_qa;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id)
 select q.h,person,q.tag,'Cat care QA',5,q.past+day,gen_random_uuid() from cat_qa q cross join lateral unnest(array[q.a,q.b,q.c]) person cross join generate_series(0,6) day cross join generate_series(1,4) n where person<>q.c or day<>6;
update public.households set weekly_competition_started_at=(select past::timestamp at time zone 'UTC' from cat_qa) where id=(select h from cat_qa);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from cat_qa),'role','authenticated')::text,true);
set local role authenticated;
select public.household_weekly_scores(h) from cat_qa;
reset role;
do $$begin
 if (select count(*) from app_private.cat_weeks where household_id=(select h from cat_qa) and earned_at is not null)<>2 then raise exception 'Seven-day cats must reward all qualifying people only';end if;
 if exists(select 1 from app_private.cat_weeks where household_id=(select h from cat_qa) and week_start=(select past from cat_qa) and targets<>array_fill(20,array[7])) then raise exception 'Current target changed past targets';end if;
end $$;
-- An older wizard award must keep its original symbol/color after theme changes.
insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,teams_enabled,team_scores)
 select h,past-7,past,'UTC','points','wizard',false,jsonb_build_array(jsonb_build_object('team_id',a,'name','Admin','color','#123456','symbol','lion','points',50,'chores',5,'score',50,'winner',true,'weekly_win_points',1)) from cat_qa;
set local role authenticated;
select public.set_household_experience(h,'poker',false) from cat_qa;
do $$declare cases jsonb;mine jsonb;begin
 cases:=public.household_weekly_scores((select h from cat_qa));
 select value into mine from jsonb_array_elements(cases) where value->>'id'=(select a::text from cat_qa);
 if jsonb_array_length(mine->'trophies')<>2 then raise exception 'Mixed trophies missing';end if;
 if not exists(select 1 from jsonb_array_elements(mine->'trophies') t where t->>'mode'='points' and t->>'symbol'='lion' and t->>'color'='#123456') then raise exception 'Wizard appearance mutated';end if;
 if not exists(select 1 from jsonb_array_elements(mine->'trophies') t where t->>'mode'='cats' and (t->>'cat_type')::integer=2) then raise exception 'Earned cat appearance mutated';end if;
 if (public.weekly_hall((select h from cat_qa))->'standings') is null then raise exception 'Hall missing awards';end if;
end $$;
select public.set_community_sharing(h,true,true) from cat_qa;
do $$declare entry jsonb;begin
 select value into entry from jsonb_array_elements(public.community_board((select h from cat_qa))->'households') where value->>'id'=(select h::text from cat_qa);
 if (entry->>'points')::integer<>3 or jsonb_array_length(entry->'trophies')<>3 then raise exception 'Community mixed awards incorrect';end if;
 if entry::text like '%'||(select a::text from cat_qa)||'%' or entry::text like '%Member B%' or entry::text like '%cat_daily_target%' then raise exception 'Community exposed private cat/member data';end if;
 if exists(select 1 from jsonb_array_elements(entry->'trophies') t where t ? 'user_id' or t ? 'id' or t ? 'name' or t ? 'target') then raise exception 'Public award exposed private fields';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select o from cat_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.cat_dashboard((select h from cat_qa));raise exception 'Outsider viewed cats';exception when others then if sqlerrm<>'Join this household to see its cats.' then raise;end if;end;
 begin perform public.household_weekly_scores((select h from cat_qa));raise exception 'Outsider viewed trophies';exception when others then if sqlerrm='Outsider viewed trophies' then raise;end if;end;
end $$;
set local role anon;
do $$begin
 begin perform public.cat_dashboard((select h from cat_qa));raise exception 'Anonymous viewed cats';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: care quarters, sleep, idempotent actions, immediate target changes, personal scoring, seven-day awards for every qualifier, missed-day rejection, mixed immutable trophies, exact cat variant, admin/member/outsider permissions' as result;
rollback;
