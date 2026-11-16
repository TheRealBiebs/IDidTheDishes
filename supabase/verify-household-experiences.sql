begin;
create temp table experience_qa(h uuid,h2 uuid,a uuid,b uuid,t uuid,t2 uuid,team uuid,token uuid,c uuid,refutation uuid,w date default date_trunc('week',now() at time zone 'UTC')::date-7);
grant all on experience_qa to authenticated,anon;
insert into experience_qa(a,b) select (select id from auth.users where email='andrewpbieber@gmail.com'),(select id from auth.users where email='andrew@cyclingcicerone.com');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from experience_qa),'role','authenticated')::text,true);
set local role authenticated;
update experience_qa set h=public.create_household_experience('Experience QA','Secret member A','UTC','wizard','{}');
update experience_qa set h2=public.create_household_experience('Other household QA','Other admin','UTC','poker','{}',true);
reset role;
do $$begin
 if (select teams_enabled from public.households where id=(select h from experience_qa)) then raise exception 'New household did not default to individual mode';end if;
 if exists(select 1 from public.household_teams where household_id=(select h from experience_qa)) then raise exception 'Individual household seeded teams';end if;
 if (select count(*) from public.household_teams where household_id=(select h2 from experience_qa))<>4 then raise exception 'Team creation did not seed four teams';end if;
 if (select reward_scheme from public.households where id=(select h2 from experience_qa))<>'poker' then raise exception 'Poker mapping failed';end if;
end $$;
insert into public.household_members(household_id,user_id,display_name,role) select h,b,'Secret member B','member' from experience_qa;
set local role authenticated;
select public.set_household_experience(h,'parents',false) from experience_qa;
do $$begin if (select reward_scheme from public.households where id=(select h from experience_qa))<>'stars' then raise exception 'Parent calendar mapping failed';end if;end $$;
select public.set_household_experience(h,'cats',false) from experience_qa;
do $$begin if (select reward_scheme from public.households where id=(select h from experience_qa))<>'cats' then raise exception 'Cat mapping failed';end if;end $$;
select public.set_household_experience(h,'clean',false) from experience_qa;
do $$begin if (select theme from public.households where id=(select h from experience_qa))<>'poker' then raise exception 'Legacy clean mapping failed';end if;end $$;
select public.set_household_experience(h,'wizard',false) from experience_qa;
select public.add_theme_teams(h) from experience_qa;
reset role;
update experience_qa set team=(select id from public.household_teams where household_id=h limit 1);
set local role authenticated;
update experience_qa set t=public.save_chore_rewards(h,null,'QA counters','Kitchen',10,5,'{}',true,0,'daily',team,'{}');
update experience_qa set t2=public.save_chore_rewards(h,null,'QA bathroom','Bathroom',20,5,'{}',true,0,'daily',null,'{}');
do $$declare rows jsonb;begin
 rows:=public.chore_schedule((select h from experience_qa));
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'id'=(select t::text from experience_qa) and r->>'assigned_team_id' is null and (r->>'eligible')::boolean) then raise exception 'Dormant team assignment blocked an individual';end if;
end $$;
reset role;
update experience_qa set token=(select token from public.chore_tags where id=t);
insert into app_private.sticker_inventory(token,household_id,chore_tag_id,written_at) select token,h,t,now() from experience_qa;
set local role authenticated;
update experience_qa set c=(public.complete_chore(token,gen_random_uuid())->>'id')::uuid;
select public.set_household_experience(h,'wizard',true) from experience_qa;
do $$begin begin
 perform public.complete_chore((select token from experience_qa),gen_random_uuid());raise exception 'Team restriction missing';
 exception when others then if sqlerrm<>'This chore is assigned to another team.' then raise;end if;end;end $$;
select public.set_household_experience(h,'wizard',false) from experience_qa;
reset role;
-- Move one real completion and two members' history into the previous week.
update public.chore_completions set chore_date=(select w+1 from experience_qa),completed_at=(select (w+1)::timestamp at time zone 'UTC' from experience_qa) where id=(select c from experience_qa);
insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id,completed_at) select h,t2,b,'QA bathroom',20,w+1,gen_random_uuid(),(w+1)::timestamp at time zone 'UTC' from experience_qa;
-- Current week has a different high scorer: it must not affect weekly wins.
insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id) select h,t,a,'QA counters',10,w+7,gen_random_uuid() from experience_qa;
update public.households set weekly_competition_started_at=(select w::timestamp at time zone 'UTC' from experience_qa) where id=(select h from experience_qa);
update app_private.weekly_history set effective_at=(select w::timestamp at time zone 'UTC' from experience_qa) where household_id=(select h from experience_qa);
set local role authenticated;
do $$declare rows jsonb;begin
 rows:=public.household_weekly_scores((select h from experience_qa));
 if not exists(select 1 from jsonb_array_elements(rows) r where r->>'id'=(select b::text from experience_qa) and (r->>'weekly_points')::integer=1) then raise exception 'Individual weekly winner incorrect';end if;
 if exists(select 1 from jsonb_array_elements(rows) r where r->>'id'=(select a::text from experience_qa) and (r->>'weekly_points')::integer<>0) then raise exception 'Raw chore points leaked into weekly wins';end if;
end $$;
select public.set_community_sharing(h,true,true) from experience_qa;
select public.set_community_sharing(h2,true,true) from experience_qa;
do $$declare board jsonb;begin
 board:=public.community_board((select h from experience_qa));
 if not exists(select 1 from jsonb_array_elements(board->'households') r where r->>'id'=(select h::text from experience_qa) and (r->>'points')::integer=1 and r->'teams'='[]'::jsonb) then raise exception 'Community individual weekly wins incorrect';end if;
 if board::text like '%Secret member%' or board::text like '%'||(select a::text from experience_qa)||'%' or board::text like '%'||(select b::text from experience_qa)||'%' then raise exception 'Community revealed member identity';end if;
end $$;
-- Ordinary members cannot configure or delete household chores.
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from experience_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.delete_chore((select h from experience_qa),(select t from experience_qa));raise exception 'Member deleted chore';exception when others then if sqlerrm not like 'Only household admins%' then raise;end if;end;
 begin perform public.set_household_experience((select h from experience_qa),'poker',true);raise exception 'Member changed settings';exception when others then if sqlerrm not like 'Only household admins%' then raise;end if;end;
 begin perform public.household_weekly_scores((select h2 from experience_qa));raise exception 'Foreign weekly scores exposed';exception when others then if sqlerrm not like 'Join this household%' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from experience_qa),'role','authenticated')::text,true);
select public.delete_chore(h,t) from experience_qa;
select public.delete_chore(h,t) from experience_qa;
do $$begin
 if exists(select 1 from jsonb_array_elements(public.chore_schedule((select h from experience_qa))) r where r->>'id'=(select t::text from experience_qa)) then raise exception 'Deleted chore still scheduled';end if;
 begin perform public.save_chore_rewards((select h from experience_qa),(select t from experience_qa),'Resurrect','',10,1,'{}',true,0,'daily',null,'{}');raise exception 'Deleted chore resurrected';exception when others then if sqlerrm<>'This chore has been deleted.' then raise;end if;end;
end $$;
reset role;
do $$begin
 if (select count(*) from public.chore_completions where household_id=(select h from experience_qa))<>3 then raise exception 'Deletion erased chore history';end if;
 if not exists(select 1 from app_private.sticker_inventory where token=(select token from experience_qa) and household_id is null and chore_tag_id is null) then raise exception 'Deletion failed to release sticker';end if;
 if not exists(select 1 from public.household_week_results where household_id=(select h from experience_qa) and not teams_enabled and jsonb_array_length(team_scores)=2) then raise exception 'Individual archive incorrect';end if;
 if has_function_privilege('authenticated','app_private.settle_household_weeks(uuid)','execute') or has_function_privilege('anon','public.delete_chore(uuid,uuid)','execute') then raise exception 'Unauthorized function grant';end if;
end $$;
set local role authenticated;
do $$begin if public.inspect_sticker((select token from experience_qa))->>'status'<>'available' then raise exception 'Released sticker did not become claimable';end if;end $$;
select public.claim_chore_rewards(token,h,t2,'QA bathroom','Bathroom',20,5,'{}',true,0,'daily',null,'{}') from experience_qa;
reset role;
do $$begin if not exists(select 1 from app_private.sticker_inventory where token=(select token from experience_qa) and chore_tag_id=(select t2 from experience_qa)) then raise exception 'Released sticker could not be reassigned';end if;end $$;
-- Detail edits and refutations must also correct individual weekly awards.
update public.chore_completions set trait_adjustments='{"shabbily":-20}' where household_id=(select h from experience_qa) and user_id=(select b from experience_qa);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from experience_qa),'role','authenticated')::text,true);
set local role authenticated;
select public.save_chore_details((select id from public.chore_completions where household_id=(select h from experience_qa) and user_id=(select b from experience_qa)),'shabbily',null,null,null);
do $$begin
 if not exists(select 1 from jsonb_array_elements(public.household_weekly_scores((select h from experience_qa))) r where r->>'id'=(select a::text from experience_qa) and (r->>'weekly_points')::integer=1) then raise exception 'Rating change failed to correct individual weekly winner';end if;
end $$;
update experience_qa set refutation=public.refute_chore(c,'Please redo this chore',gen_random_uuid());
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from experience_qa),'role','authenticated')::text,true);
select public.resolve_chore_refutation(refutation,'removed') from experience_qa;
do $$begin
 if exists(select 1 from jsonb_array_elements(public.household_weekly_scores((select h from experience_qa))) r where (r->>'weekly_points')::integer<>0) then raise exception 'Refutation removal failed to clear individual weekly win';end if;
end $$;
reset role;
rollback;
select 'PASS: paired themes, individual defaults, optional-team scan eligibility, individual weekly winners, private community weekly wins, admin-only idempotent chore deletion preserving history and releasing stickers; rolled back' as result;
