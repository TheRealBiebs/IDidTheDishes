begin;
create temp table refute_qa(h uuid,foreign_h uuid,foreign_c uuid,doer uuid,actor uuid,tag uuid,token uuid,c uuid,r uuid,request uuid default gen_random_uuid(),scan_request uuid default gen_random_uuid(),archived_c uuid,other_c uuid,result_id uuid default gen_random_uuid(),team_a uuid default gen_random_uuid(),team_b uuid default gen_random_uuid());
grant all on refute_qa to authenticated,anon;
insert into refute_qa(doer,actor) select (select id from auth.users where email='andrewpbieber@gmail.com'),(select id from auth.users where email='andrew@cyclingcicerone.com');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select doer from refute_qa),'role','authenticated')::text,true);
update refute_qa set h=public.create_household_with_chores('Refutation QA','Mia','UTC','cats','{}'),foreign_h=public.create_household_with_chores('Foreign refutation QA','Mia','UTC','cats','{}');
insert into public.household_members(household_id,user_id,display_name,role) select h,actor,'Andrew','member' from refute_qa;
update refute_qa set tag=public.save_scheduled_chore(h,null,'Do the dishes','Kitchen',10,2,'{}',true,0,'daily',null);
update refute_qa set token=(select t.token from public.chore_tags t where t.id=tag);
insert into app_private.sticker_inventory(token,household_id,chore_tag_id,written_at) select token,h,tag,now() from refute_qa;
insert into public.chore_completions(household_id,user_id,chore,points,chore_date,request_id,completion_kind) select foreign_h,doer,'Foreign chore',3,current_date,gen_random_uuid(),'unexpected' from refute_qa;
update refute_qa set foreign_c=(select id from public.chore_completions where household_id=foreign_h);
set local role authenticated;
update refute_qa set c=(public.complete_chore(token,scan_request)->>'id')::uuid;
do $$begin
 begin perform public.refute_chore((select c from refute_qa),null,gen_random_uuid());raise exception 'Self-refutation allowed';exception when others then if sqlerrm<>'You cannot refute your own chore.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select actor from refute_qa),'role','authenticated')::text,true);
update refute_qa set r=public.refute_chore(c,'Still greasy.',request);
do $$declare d jsonb;begin
 if public.refute_chore((select c from refute_qa),'Still greasy.',(select request from refute_qa))<>(select r from refute_qa) then raise exception 'Refutation retry duplicated';end if;
 begin perform public.refute_chore((select c from refute_qa),null,gen_random_uuid());raise exception 'Second pending refutation allowed';exception when others then if sqlerrm<>'This chore is already waiting for the doer to respond.' then raise;end if;end;
 begin perform public.resolve_chore_refutation((select r from refute_qa),'removed');raise exception 'Refuter deleted someone else completion';exception when others then if sqlerrm<>'Only the original doer can resolve this refutation.' then raise;end if;end;
 begin perform public.refute_chore((select foreign_c from refute_qa),null,gen_random_uuid());raise exception 'Foreign refutation allowed';exception when others then if sqlerrm<>'This chore is not available to your household.' then raise;end if;end;
 begin update public.chore_refutations set status='redone' where id=(select r from refute_qa);raise exception 'Direct refutation update allowed';exception when insufficient_privilege then null;end;
 d:=public.chore_social((select c from refute_qa));
 if d->>'is_doer'<>'false' or d->>'can_refute'<>'false' or d->'refutations'->0->>'reason'<>'Still greasy.' then raise exception 'Refutation visibility incorrect';end if;
end $$;
reset role;
do $$begin
 if (select count(*) from public.notifications where completion_id=(select c from refute_qa) and user_id=(select doer from refute_qa))<>1 then raise exception 'Refutation sent duplicate alerts';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select doer from refute_qa),'role','authenticated')::text,true);
set local role authenticated;
select public.resolve_chore_refutation((select r from refute_qa),'redone');
select public.resolve_chore_refutation((select r from refute_qa),'redone');
do $$begin
 if (select points from public.chore_completions where id=(select c from refute_qa))<>10 or (select count(*) from public.chore_completions where household_id=(select h from refute_qa))<>1 then raise exception 'Redo changed reward or created duplicate completion';end if;
 if public.chore_social((select c from refute_qa))->'refutations'->0->>'status'<>'redone' then raise exception 'Redo not resolved';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select actor from refute_qa),'role','authenticated')::text,true);
update refute_qa set r=public.refute_chore(c,null,gen_random_uuid());
select set_config('request.jwt.claims',jsonb_build_object('sub',(select doer from refute_qa),'role','authenticated')::text,true);
select public.resolve_chore_refutation((select r from refute_qa),'removed');
select public.resolve_chore_refutation((select r from refute_qa),'removed');
do $$begin
 if exists(select 1 from public.chore_completions where id=(select c from refute_qa)) then raise exception 'Removed completion remains';end if;
 begin perform public.complete_chore((select token from refute_qa),(select scan_request from refute_qa));raise exception 'Removed scan replay awarded again';exception when others then if sqlerrm<>'This completion was removed. Scan the sticker again to log a new completion.' then raise;end if;end;
 perform public.complete_chore((select token from refute_qa),gen_random_uuid());
end $$;
reset role;
-- Two archived teams: removing A's completion must make B the weekly winner.
insert into public.chore_completions(household_id,user_id,chore,points,chore_date,completed_at,request_id,completion_kind) select h,doer,'Archived A',3,date_trunc('week',now())::date-7,now()-interval '8 days',gen_random_uuid(),'unexpected' from refute_qa;
insert into public.chore_completions(household_id,user_id,chore,points,chore_date,completed_at,request_id,completion_kind) select h,actor,'Archived B',2,date_trunc('week',now())::date-7,now()-interval '8 days',gen_random_uuid(),'unexpected' from refute_qa;
update refute_qa set archived_c=(select id from public.chore_completions where household_id=h and chore='Archived A'),other_c=(select id from public.chore_completions where household_id=h and chore='Archived B');
insert into public.household_week_results(id,household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores) select result_id,h,date_trunc('week',now())::date-7,date_trunc('week',now())::date,'UTC','points','cats',app_private.rank_week_teams(jsonb_build_array(jsonb_build_object('team_id',team_a,'name','Team A','points',3,'chores',1),jsonb_build_object('team_id',team_b,'name','Team B','points',2,'chores',1)),'points') from refute_qa;
insert into public.weekly_result_chores(result_id,completion_id,team_id,completed_at,details) select q.result_id,c.id,case when c.id=q.archived_c then q.team_a else q.team_b end,c.completed_at,to_jsonb(c.*) from refute_qa q join public.chore_completions c on c.id in(q.archived_c,q.other_c);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select actor from refute_qa),'role','authenticated')::text,true);
set local role authenticated;
update refute_qa set r=public.refute_chore(archived_c,'Not finished.',gen_random_uuid());
select set_config('request.jwt.claims',jsonb_build_object('sub',(select doer from refute_qa),'role','authenticated')::text,true);
select public.resolve_chore_refutation((select r from refute_qa),'removed');
reset role;
do $$begin
 if exists(select 1 from public.weekly_result_chores where completion_id=(select archived_c from refute_qa)) then raise exception 'Archive still contains removed completion';end if;
 if not exists(select 1 from public.household_week_results w cross join lateral jsonb_array_elements(w.team_scores) t where w.id=(select result_id from refute_qa) and t->>'team_id'=(select team_b::text from refute_qa) and (t->>'winner')::boolean and (t->>'weekly_win_points')::integer=1) then raise exception 'Archived winner not recalculated';end if;
end $$;
-- Deleting a household with a pending refutation must still cascade cleanly.
select set_config('request.jwt.claims',jsonb_build_object('sub',(select actor from refute_qa),'role','authenticated')::text,true);
set local role authenticated;
select public.refute_chore((select id from public.chore_completions where household_id=(select h from refute_qa) and chore='Do the dishes'),null,gen_random_uuid());
select set_config('request.jwt.claims',jsonb_build_object('sub',(select doer from refute_qa),'role','authenticated')::text,true);
select public.delete_household((select h from refute_qa),'Refutation QA');
reset role;rollback;
select 'PASS: optional reason, private thread, doer-only response, one pending refutation, notification/retry safety, redo keeps points, deletion frees scan slot and prevents replay, archived scores/winner corrected, and household cascade; fixtures rolled back' as result;
