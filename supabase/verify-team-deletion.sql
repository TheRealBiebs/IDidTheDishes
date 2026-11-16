begin;
create temp table team_delete_qa(h uuid,h2 uuid,a uuid,b uuid,team uuid,other_team uuid,foreign_team uuid,chore uuid,retired uuid,c uuid,team_name text,w date default date_trunc('week',now() at time zone 'UTC')::date-7);
grant all on team_delete_qa to authenticated,anon;
insert into team_delete_qa(a,b) select (select id from auth.users where email='andrewpbieber@gmail.com'),(select id from auth.users where email='andrew@cyclingcicerone.com');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from team_delete_qa),'role','authenticated')::text,true);
set local role authenticated;
update team_delete_qa set h=public.create_household_experience('Team delete QA','QA admin','UTC','wizard','{}',true),h2=public.create_household_experience('Foreign team QA','Other admin','UTC','parents','{}',true);
reset role;
update team_delete_qa set team=(select id from public.household_teams where household_id=h order by preset_key limit 1),foreign_team=(select id from public.household_teams where household_id=h2 limit 1);
update team_delete_qa set other_team=(select id from public.household_teams where household_id=h and id<>team limit 1),team_name=(select name from public.household_teams where id=team);
insert into public.household_members(household_id,user_id,display_name,role,team_id) select h,b,'QA member','member',other_team from team_delete_qa;
set local role authenticated;
select public.choose_team(h,team,null) from team_delete_qa;
update team_delete_qa set chore=public.save_chore_rewards(h,null,'Live assigned chore','Kitchen',10,1,'{}',true,0,'daily',team,'{}');
update team_delete_qa set retired=public.save_chore_rewards(h,null,'Retired assigned chore','Bathroom',5,1,'{}',true,0,'daily',team,'{}');
select public.delete_chore(h,retired) from team_delete_qa;
reset role;
insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id,completed_at) select h,chore,a,'Live assigned chore',10,w+1,gen_random_uuid(),(w+1)::timestamp at time zone 'UTC' from team_delete_qa;
update team_delete_qa set c=(select id from public.chore_completions where household_id=h);
update public.households set weekly_competition_started_at=(select w::timestamp at time zone 'UTC' from team_delete_qa) where id=(select h from team_delete_qa);
update app_private.weekly_history set effective_at=(select w::timestamp at time zone 'UTC' from team_delete_qa) where household_id=(select h from team_delete_qa);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from team_delete_qa),'role','authenticated')::text,true);
set local role authenticated;
do $$begin
 begin perform public.delete_team((select h from team_delete_qa),(select team from team_delete_qa));raise exception 'Ordinary member deleted team';exception when others then if sqlerrm<>'Only household admins can delete teams.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from team_delete_qa),'role','authenticated')::text,true);
-- Admin of H must not be able to delete a team from H2 by passing it to H.
select public.delete_team(h,foreign_team) from team_delete_qa;
select public.delete_team(h,team) from team_delete_qa;
select public.delete_team(h,team) from team_delete_qa;
do $$declare hall jsonb;begin
 if exists(select 1 from public.household_teams where id=(select team from team_delete_qa)) then raise exception 'Team remained after delete';end if;
 if not exists(select 1 from public.household_teams where id=(select foreign_team from team_delete_qa)) then raise exception 'Foreign team was deleted';end if;
 if exists(select 1 from public.household_members where household_id=(select h from team_delete_qa) and user_id=(select a from team_delete_qa) and (team_id is not null or wizard_house is not null)) then raise exception 'Member was not unassigned';end if;
 if exists(select 1 from public.chore_tags where id in(select chore from team_delete_qa union all select retired from team_delete_qa) and assigned_team_id is not null) then raise exception 'Chore assignment remained';end if;
 if not exists(select 1 from public.chore_completions where id=(select c from team_delete_qa) and points=10) then raise exception 'Completion or personal points lost';end if;
 hall:=public.weekly_hall((select h from team_delete_qa));
 if not exists(select 1 from jsonb_array_elements(hall->'standings') t where t->>'team_id'=(select team::text from team_delete_qa) and t->>'name'=(select team_name from team_delete_qa) and (t->>'weekly_points')::integer=1) then raise exception 'Deleted team weekly award was lost';end if;
 if not exists(select 1 from public.weekly_result_chores where completion_id=(select c from team_delete_qa) and team_id=(select team from team_delete_qa)) then raise exception 'Archived team attribution lost';end if;
 begin perform public.save_chore_rewards((select h from team_delete_qa),(select retired from team_delete_qa),'Revived chore','',5,1,'{}',true,0,'daily',null,'{}');raise exception 'Deleted chore guard bypassed';exception when others then if sqlerrm<>'This chore has been deleted.' then raise;end if;end;
end $$;
select public.set_community_sharing(h,true,true) from team_delete_qa;
do $$declare board jsonb;begin
 board:=public.community_board((select h from team_delete_qa));
 if not exists(select 1 from jsonb_array_elements(board->'households') h cross join lateral jsonb_array_elements(h->'teams') t where h->>'id'=(select h::text from team_delete_qa) and t->>'id'=(select team::text from team_delete_qa) and (t->>'points')::integer=1) then raise exception 'Community lost archived team win';end if;
end $$;
select public.add_theme_teams(h) from team_delete_qa;
do $$begin
 if (select count(*) from public.household_teams where household_id=(select h from team_delete_qa))<>4 then raise exception 'Deleted starter team could not be created again';end if;
end $$;
reset role;
do $$begin
 if has_function_privilege('anon','public.delete_team(uuid,uuid)','execute') or has_table_privilege('authenticated','public.household_teams','delete') then raise exception 'Unauthorized direct deletion grant';end if;
end $$;
rollback;
select 'PASS: admin-only, household-scoped and retry-safe team deletion; members/live and retired chores unassigned, personal points and weekly/team community history preserved, deleted-chore guard retained, starter team can be recreated; rolled back' as result;
