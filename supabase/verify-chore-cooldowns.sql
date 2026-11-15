begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('f6000000-0000-4000-8000-000000000001','cooldown-admin@example.invalid','{}'),
 ('f6000000-0000-4000-8000-000000000002','cooldown-member@example.invalid','{}');
create temp table cooldown_qa(h uuid,t uuid,token uuid,request uuid default gen_random_uuid());
grant all on cooldown_qa to authenticated,anon;
insert into cooldown_qa default values;
select set_config('request.jwt.claims','{"sub":"f6000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update cooldown_qa set h=public.create_household_with_chores('Rollback cooldown QA','Admin','UTC','cats','{}');
insert into public.household_members(household_id,user_id,display_name,role) select h,'f6000000-0000-4000-8000-000000000002','Member','member' from cooldown_qa;
set local role authenticated;
update cooldown_qa set t=public.save_tag_with_cooldown(h,null,'Wipe counters','Kitchen',10,3,'{}',true,null);
reset role;
update cooldown_qa set token=(select token from public.chore_tags where id=t);
insert into app_private.sticker_inventory(token,chore_tag_id,household_id,written_at) select token,t,h,now() from cooldown_qa;
set local role authenticated;
do $$declare c jsonb;again jsonb;begin
 c:=public.complete_chore((select token from cooldown_qa),(select request from cooldown_qa));
 again:=public.complete_chore((select token from cooldown_qa),(select request from cooldown_qa));
 if c->>'id'<>again->>'id' then raise exception 'Retry was not idempotent';end if;
 begin perform public.complete_chore((select token from cooldown_qa),gen_random_uuid());raise exception 'Cooldown allowed repeat';exception when others then if sqlerrm not like 'This chore is cooling down.%4h%' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{"sub":"f6000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$begin
 begin perform public.complete_chore((select token from cooldown_qa),gen_random_uuid());raise exception 'Another member bypassed cooldown';exception when others then if sqlerrm not like 'This chore is cooling down.%' then raise;end if;end;
 begin perform public.save_tag_with_cooldown(h,t,'Wipe counters','',10,3,'{}',true,0) from cooldown_qa;raise exception 'Member changed cooldown';exception when others then if sqlerrm<>'Only the household admin can configure stickers.' then raise;end if;end;
end $$;
reset role;
-- A completion before midnight still starts the household wait.
update public.chore_completions set chore_date=current_date-1,completed_at=now()-interval '1 hour' where household_id=(select h from cooldown_qa);
set local role authenticated;
do $$begin
 begin perform public.complete_chore((select token from cooldown_qa),gen_random_uuid());raise exception 'Midnight bypassed cooldown';exception when others then if sqlerrm not like 'This chore is cooling down.%3h%' then raise;end if;end;
end $$;
reset role;
update public.chore_completions set completed_at=now()-interval '4 hours' where household_id=(select h from cooldown_qa);
set local role authenticated;
select public.complete_chore(token,gen_random_uuid()) from cooldown_qa;
select set_config('request.jwt.claims','{"sub":"f6000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.save_tag_with_cooldown(h,t,'Wipe counters','',10,3,'{}',true,90) from cooldown_qa;
reset role;
update public.chore_completions set completed_at=now()-interval '89 minutes' where household_id=(select h from cooldown_qa) and chore_date=current_date;
set local role authenticated;
do $$begin
 begin perform public.complete_chore((select token from cooldown_qa),gen_random_uuid());raise exception 'Custom wait ignored';exception when others then if sqlerrm not like 'This chore is cooling down.%1m%' then raise;end if;end;
 begin perform public.save_tag_with_cooldown(h,t,'Wipe counters','',10,3,'{}',true,-1) from cooldown_qa;raise exception 'Invalid cooldown allowed';exception when others then if sqlerrm not like 'Choose a cooldown%' then raise;end if;end;
end $$;
select public.save_tag_with_cooldown(h,t,'Wipe counters','',10,3,'{}',true,0) from cooldown_qa;
-- Another member can log immediately with cooldown off.
select public.complete_chore(token,gen_random_uuid()) from cooldown_qa;
select set_config('request.jwt.claims','{"sub":"f6000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.complete_chore(token,gen_random_uuid()) from cooldown_qa;
do $$begin
 begin perform public.complete_chore((select token from cooldown_qa),gen_random_uuid());raise exception 'Daily cap ignored';exception when others then if sqlerrm<>'This chore has reached its household limit for today.' then raise;end if;end;
end $$;
reset role;
-- Verify automatic values and single-completion chores independently of client input.
do $$begin
 if app_private.chore_cooldown_minutes(3,null)<>240 or app_private.chore_cooldown_minutes(2,null)<>360 or app_private.chore_cooldown_minutes(100,null)<>7 or app_private.chore_cooldown_minutes(1,90)<>0 then raise exception 'Automatic defaults incorrect';end if;
 if (select count(*) from public.chore_completions where household_id=(select h from cooldown_qa))<>4 then raise exception 'Unexpected completion count';end if;
end $$;

select set_config('request.jwt.claims','{"sub":"f6000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table claim_cooldown_qa(token uuid default gen_random_uuid(),tag uuid);
insert into claim_cooldown_qa default values;
grant all on claim_cooldown_qa to authenticated;
insert into app_private.sticker_inventory(token,written_at) select token,now() from claim_cooldown_qa;
set local role authenticated;
update claim_cooldown_qa set tag=public.claim_sticker_with_cooldown(token,(select h from cooldown_qa),null,'Claim test','',10,3,'{}',true,120);
do $$begin
 if (select cooldown_minutes from public.chore_tags where id=(select tag from claim_cooldown_qa))<>120 then raise exception 'Claim dropped cooldown';end if;
 perform public.save_tag((select h from cooldown_qa),(select tag from claim_cooldown_qa),'Legacy client edit','',10,3,'{}',true);
 if (select cooldown_minutes from public.chore_tags where id=(select tag from claim_cooldown_qa))<>120 then raise exception 'Legacy edit reset cooldown';end if;
end $$;
reset role;
set local role anon;
do $$begin
 begin perform public.save_tag_with_cooldown(h,t,'Nope','',10,3,'{}',true,0) from cooldown_qa;raise exception 'Anonymous settings allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: defaults, cross-member and midnight enforcement, expiry, custom duration, opt-out, daily cap, replay safety, validation and admin permissions; fixtures rolled back' as result;
