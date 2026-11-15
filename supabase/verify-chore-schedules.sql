begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('f8000000-0000-4000-8000-000000000001','schedule-admin@example.invalid','{}'),
 ('f8000000-0000-4000-8000-000000000002','schedule-rival@example.invalid','{}'),
 ('f8000000-0000-4000-8000-000000000003','schedule-mate@example.invalid','{}');
create temp table schedule_qa(h uuid,a uuid default gen_random_uuid(),b uuid default gen_random_uuid(),daily uuid,weekly uuid,monthly uuid,open_chore uuid,req uuid default gen_random_uuid());
grant all on schedule_qa to authenticated,anon;
insert into schedule_qa default values;
select set_config('request.jwt.claims','{"sub":"f8000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update schedule_qa set h=public.create_household_with_chores('Rollback schedules QA','Admin','America/Los_Angeles','cats','{}');
insert into public.household_teams(id,household_id,name,color,symbol) select a,h,'Team A','#ff0000','star' from schedule_qa union all select b,h,'Team B','#0000ff','star' from schedule_qa;
update public.household_members set team_id=(select a from schedule_qa) where household_id=(select h from schedule_qa);
insert into public.household_members(household_id,user_id,display_name,role,team_id) select h,'f8000000-0000-4000-8000-000000000002'::uuid,'Rival','member',b from schedule_qa union all select h,'f8000000-0000-4000-8000-000000000003'::uuid,'Mate','member',a from schedule_qa;
set local role authenticated;
update schedule_qa set daily=public.save_scheduled_chore(h,null,'Daily counters','Kitchen',10,3,'{}',true,0,'daily',a),weekly=public.save_scheduled_chore(h,null,'Weekly floors','Hall',20,1,'{}',true,null,'weekly',a),monthly=public.save_scheduled_chore(h,null,'Monthly oven','Kitchen',30,1,'{}',true,null,'monthly',a),open_chore=public.save_scheduled_chore(h,null,'Open monthly job','',10,1,'{}',true,null,'monthly',null);
reset role;
insert into app_private.sticker_inventory(token,chore_tag_id,household_id,written_at) select t.token,t.id,t.household_id,now() from public.chore_tags t where household_id=(select h from schedule_qa);
set local role authenticated;
do $$declare rows jsonb;c jsonb;again jsonb;begin
 rows:=public.chore_schedule((select h from schedule_qa));
 if (select count(*) from jsonb_array_elements(rows) r where (r->>'assigned_to_me')::boolean)<>3 then raise exception 'Assigned list incorrect';end if;
 if (select count(*) from jsonb_array_elements(rows) r where r->>'assigned_team_id' is null and (r->>'eligible')::boolean)<>1 then raise exception 'Open chore mixed with assignments';end if;
 c:=public.complete_chore((select token from public.chore_tags where id=(select daily from schedule_qa)),(select req from schedule_qa));
 again:=public.complete_chore((select token from public.chore_tags where id=(select daily from schedule_qa)),(select req from schedule_qa));
 if c->>'id'<>again->>'id' then raise exception 'Replay awarded twice';end if;
 perform public.complete_chore((select token from public.chore_tags where id=(select weekly from schedule_qa)),gen_random_uuid());
 perform public.complete_chore((select token from public.chore_tags where id=(select monthly from schedule_qa)),gen_random_uuid());
 begin perform public.complete_chore((select token from public.chore_tags where id=(select weekly from schedule_qa)),gen_random_uuid());raise exception 'Weekly limit bypassed';exception when others then if sqlerrm<>'This chore has reached its household limit for this week.' then raise;end if;end;
 begin perform public.complete_chore((select token from public.chore_tags where id=(select monthly from schedule_qa)),gen_random_uuid());raise exception 'Monthly limit bypassed';exception when others then if sqlerrm<>'This chore has reached its household limit for this month.' then raise;end if;end;
 rows:=public.chore_schedule((select h from schedule_qa));
 if (select count(*) from jsonb_array_elements(rows) r where (r->>'assigned_to_me')::boolean and (r->>'remaining')::integer>0)<>1 then raise exception 'Completed assignments still pending';end if;
 if (select (r->>'remaining')::integer from jsonb_array_elements(rows) r where r->>'frequency'='daily')<>2 then raise exception 'Daily repetitions incorrect';end if;
 begin perform public.save_scheduled_chore(h,daily,'Daily counters','',10,3,'{}',true,0,'daily',gen_random_uuid()) from schedule_qa;raise exception 'Foreign team accepted';exception when others then if sqlerrm<>'Choose an active team from this household.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f8000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin
 begin perform public.complete_chore((select token from public.chore_tags where id=(select daily from schedule_qa)),gen_random_uuid());raise exception 'Rival stole assignment';exception when others then if sqlerrm<>'This chore is assigned to another team.' then raise;end if;end;
 begin perform public.save_scheduled_chore(h,daily,'Steal','',10,3,'{}',true,0,'daily',b) from schedule_qa;raise exception 'Member reassigned chore';exception when others then if sqlerrm<>'Only the household admin can configure stickers.' then raise;end if;end;
 perform public.complete_chore((select token from public.chore_tags where id=(select open_chore from schedule_qa)),gen_random_uuid());
end $$;
select set_config('request.jwt.claims','{"sub":"f8000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select public.complete_chore((select token from public.chore_tags where id=(select daily from schedule_qa)),gen_random_uuid());
reset role;
-- Move old completions outside the calendar period, then verify the next period is available.
update public.chore_completions set chore_date=app_private.chore_period_start((now() at time zone 'America/Los_Angeles')::date,'weekly')-1,completed_at=now()-interval '8 days' where tag_id=(select weekly from schedule_qa);
update public.chore_completions set chore_date=app_private.chore_period_start((now() at time zone 'America/Los_Angeles')::date,'monthly')-1,completed_at=now()-interval '40 days' where tag_id=(select monthly from schedule_qa);
set local role authenticated;
select public.complete_chore((select token from public.chore_tags where id=(select weekly from schedule_qa)),gen_random_uuid());
select public.complete_chore((select token from public.chore_tags where id=(select monthly from schedule_qa)),gen_random_uuid());
reset role;
do $$begin
 if app_private.chore_period_start('2026-11-01','weekly')<>'2026-10-26'::date or app_private.chore_period_start('2026-11-02','weekly')<>'2026-11-02'::date or app_private.chore_period_start('2028-02-29','monthly')<>'2028-02-01'::date then raise exception 'Calendar boundaries incorrect';end if;
end $$;
set local role anon;
do $$begin
 begin perform public.chore_schedule((select h from schedule_qa));raise exception 'Anonymous read allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: recurring periods, team-only completion, admin-only assignment, shared daily repetitions, weekly/monthly limits and resets, pending counts, unassigned availability, retry idempotency and calendar boundaries; fixtures rolled back' as result;
