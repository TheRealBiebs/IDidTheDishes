begin;
create temp table personal_qa(a uuid,b uuid,d uuid,o uuid,h uuid,t uuid,other_t uuid,tag uuid,w date,old_companion uuid,b_companion uuid,token uuid default gen_random_uuid());
grant all on personal_qa to authenticated,anon;
insert into personal_qa(a,b,d,o,t,other_t,old_companion,b_companion) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'personal-a-'||a||'@example.invalid' from personal_qa union all select b,'personal-b-'||b||'@example.invalid' from personal_qa union all select d,'personal-d-'||d||'@example.invalid' from personal_qa union all select o,'personal-o-'||o||'@example.invalid' from personal_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from personal_qa),'role','authenticated')::text,true);
set local role authenticated;
update personal_qa set h=public.create_household_experience('Personal QA','Admin','UTC','cats','{}'),w=date_trunc('week',now() at time zone 'UTC')::date;
select public.set_household_experience(h,'cats',true) from personal_qa;
update personal_qa set tag=public.save_chore_rewards(h,null,'Sticker chore','',10,100,'{}',true,0,'daily',null,'{}','kitty');
reset role;
insert into public.household_teams(id,household_id,name,color,symbol) select t,h,'Team A','#663399','star' from personal_qa union all select other_t,h,'Other team','#112233','heart' from personal_qa;
update public.household_members set team_id=(select t from personal_qa) where household_id=(select h from personal_qa);
insert into public.household_members(household_id,user_id,display_name,role,team_id) select h,b,'Member B','member',t from personal_qa union all select h,d,'Member D','member',other_t from personal_qa;
-- Move A/B's initial companions into a failed/successful previous week.
update app_private.cat_weeks c set week_start=q.w-7,eligible_from=q.w-7,variant=7,cat_name='Mittens',companion_id=q.old_companion,finalized_at=now() from personal_qa q where c.household_id=q.h and c.user_id=q.a;
update app_private.cat_weeks c set week_start=q.w-7,eligible_from=q.w-7,variant=2,cat_name='Comet',companion_id=q.b_companion,required_days=1 from personal_qa q where c.household_id=q.h and c.user_id=q.b;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,b,tag,'Sticker chore',10,w-7,gen_random_uuid() from personal_qa cross join generate_series(1,2);
-- Reseed after the completion trigger's lazy current-week creation.
delete from app_private.cat_weeks c using personal_qa q where c.household_id=q.h and c.user_id=q.b and c.week_start=q.w;
update app_private.cat_weeks c set finalized_at=null,earned_at=null from personal_qa q where c.household_id=q.h and c.user_id=q.b and c.week_start=q.w-7;
set local role authenticated;
do $$declare data jsonb;mine jsonb;begin
 data:=public.cat_dashboard((select h from personal_qa));select value into mine from jsonb_array_elements(data->'cats') where value->>'user_id'=(select a::text from personal_qa);
 if mine->>'cat_name'<>'Mittens' or (mine->>'variant')::integer<>7 or mine->>'companion_id'<>(select old_companion::text from personal_qa) then raise exception 'Failed cat did not carry over';end if;
 perform public.name_cat((select h from personal_qa),'Cocoa');
 perform public.save_cat_settings((select h from personal_qa),30,4);
 if (public.cat_dashboard((select h from personal_qa))->>'required_days')::integer<>4 then raise exception 'Required days missing';end if;
 begin perform public.name_cat((select h from personal_qa),' ');raise exception 'Empty cat name accepted';exception when others then if sqlerrm<>'Choose a cat name from 1 to 40 characters.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from personal_qa),'role','authenticated')::text,true);
do $$declare mine jsonb;begin
 select value into mine from jsonb_array_elements(public.cat_dashboard((select h from personal_qa))->'cats') where value->>'user_id'=(select b::text from personal_qa);
 if mine->>'companion_id'=(select b_companion::text from personal_qa) or mine->>'cat_name'<>'' then raise exception 'Winner did not get a fresh companion';end if;
 perform public.name_cat((select h from personal_qa),'Nova');
 perform public.save_trophy_case((select h from personal_qa),(select t from personal_qa),'#123456','#234567','modern');
 begin perform public.save_trophy_case((select h from personal_qa),(select other_t from personal_qa),'#123456','#234567','wood');raise exception 'Member edited rival case';exception when others then if sqlerrm<>'You can customize only your own or your team’s case.' then raise;end if;end;
 begin perform public.set_cat_required_days((select h from personal_qa),1);raise exception 'Member changed required days';exception when others then if sqlerrm<>'Only household admins can set qualifying days.' then raise;end if;end;
end $$;
reset role;
do $$begin
 if not exists(select 1 from app_private.cat_weeks c join personal_qa q on q.h=c.household_id where c.user_id=q.b and c.week_start=q.w-7 and c.earned_at is not null and c.cat_name='Comet' and c.required_days=1) then raise exception 'Earned cat name/requirement changed';end if;
end $$;
insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,teams_enabled,team_scores) select h,w-14,w-7,'UTC','points','wizard',true,jsonb_build_array(jsonb_build_object('team_id',t,'name','Team A','color','#663399','symbol','star','points',50,'chores',5,'score',50,'winner',true,'weekly_win_points',1)) from personal_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from personal_qa),'role','authenticated')::text,true);
set local role authenticated;
do $$declare cases jsonb;team_case jsonb;begin
 cases:=public.household_weekly_scores((select h from personal_qa));select value into team_case from jsonb_array_elements(cases) where value->>'id'=(select t::text from personal_qa);
 if jsonb_array_length(team_case->'trophies')<>2 then raise exception 'Personal/team awards not combined';end if;
 if exists(select 1 from jsonb_array_elements(cases) where value->>'id'=(select b::text from personal_qa)) then raise exception 'Duplicate individual case remains';end if;
 if not exists(select 1 from jsonb_array_elements(team_case->'trophies') a where a->>'cat_name'='Comet' and (a->>'points')::integer=20 and a->>'won_on' is not null) then raise exception 'Trophy details missing';end if;
 if team_case->'appearance'->>'frame'<>'#123456' then raise exception 'Case style not persisted';end if;
end $$;
-- Completed stickers are snapshots even after the chore is edited.
select public.save_chore_rewards(h,tag,'Sticker chore','',10,100,'{}',true,0,'daily',null,'{}','rainbow') from personal_qa;
reset role;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,chore_date,request_id) select h,a,tag,'Sticker chore',10,w-6,gen_random_uuid() from personal_qa;
set local role authenticated;
do $$declare rows jsonb;begin
 rows:=public.reward_calendar((select h from personal_qa),(select w-7 from personal_qa));
 if not exists(select 1 from jsonb_array_elements(rows) a where a->>'calendar_sticker'='kitty') or not exists(select 1 from jsonb_array_elements(rows) a where a->>'calendar_sticker'='rainbow') then raise exception 'Sticker calendar history was repainted';end if;
 begin perform public.save_chore_rewards(h,tag,'Sticker chore','',10,100,'{}',true,0,'daily',null,'{}','invalid') from personal_qa;raise exception 'Invalid sticker accepted';exception when others then if sqlerrm<>'Choose a supported calendar sticker.' then raise;end if;end;
end $$;
reset role;
insert into app_private.sticker_inventory(token,written_at) select token,now() from personal_qa;
set local role authenticated;
select public.claim_chore_rewards(token,h,tag,'Sticker chore','',10,100,'{}',true,0,'daily',null,'{}','dog') from personal_qa;
do $$begin
 if (select calendar_sticker from public.chore_tags where id=(select tag from personal_qa))<>'dog' then raise exception 'Claim did not save selected sticker';end if;
 begin perform public.save_cat_settings((select h from personal_qa),99,0);raise exception 'Invalid days accepted';exception when others then if sqlerrm<>'Choose 1 to 7 qualifying days.' then raise;end if;end;
 if (select cat_daily_target from public.households where id=(select h from personal_qa))<>30 then raise exception 'Invalid settings left a partial target update';end if;
end $$;
select public.set_community_sharing(h,true,true) from personal_qa;
do $$declare board jsonb;entry jsonb;begin
 board:=public.community_board((select h from personal_qa));select value into entry from jsonb_array_elements(board->'households') where value->>'id'=(select h::text from personal_qa);
 if not exists(select 1 from jsonb_array_elements(entry->'teams') t where t->>'id'=(select t::text from personal_qa) and (t->>'points')::integer=2) then raise exception 'Community did not combine personal awards';end if;
 if entry::text like '%Comet%' or entry::text like '%Member B%' or entry::text like '%personal_points%' then raise exception 'Public case disclosed private details';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select o from personal_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.name_cat((select h from personal_qa),'Spy');raise exception 'Outsider named cat';exception when others then if sqlerrm<>'Join this household first.' then raise;end if;end;
 begin perform public.save_trophy_case((select h from personal_qa),(select t from personal_qa),'#123456','#234567','wood');raise exception 'Outsider styled case';exception when others then if sqlerrm<>'Join this household first.' then raise;end if;end;
end $$;
reset role;
select 'PASS: cat names and carry-over, configurable required days, frozen trophy names/details, merged personal/team cases, case-style permissions, sticker snapshots, community privacy' as result;
rollback;
