begin;
create temp table repeat_qa(a uuid,b uuid,c uuid,h uuid,w uuid,m uuid,wt uuid,mt uuid);
grant all on repeat_qa to authenticated;
insert into repeat_qa(a,b,c,wt,mt) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'repeat-a-'||a||'@example.invalid' from repeat_qa union all select b,'repeat-b-'||b||'@example.invalid' from repeat_qa union all select c,'repeat-c-'||c||'@example.invalid' from repeat_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from repeat_qa),'role','authenticated')::text,true);
set local role authenticated;
update repeat_qa set h=public.create_household_experience('Repeat QA','Admin','UTC','wizard','{}');
update repeat_qa set w=public.save_chore_rewards(h,null,'Weekly chore','',10,3,'{}',false,null,'weekly',null,'{}');
reset role;
insert into public.household_members(household_id,user_id,display_name,role) select h,b,'Member B','member' from repeat_qa union all select h,c,'Member C','member' from repeat_qa;
insert into app_private.sticker_inventory(token,written_at) select wt,now() from repeat_qa union all select mt,now() from repeat_qa;
set local role authenticated;
select public.claim_chore_rewards(wt,h,w,'Weekly chore','',10,3,'{}',false,null,'weekly',null,'{}') from repeat_qa;
update repeat_qa set m=public.claim_chore_rewards(mt,h,null,'Monthly chore','',10,2,'{}',false,null,'monthly',null,'{}');
select public.complete_chore(wt,gen_random_uuid()),public.complete_chore(mt,gen_random_uuid()) from repeat_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from repeat_qa),'role','authenticated')::text,true);
select public.complete_chore(wt,gen_random_uuid()),public.complete_chore(mt,gen_random_uuid()) from repeat_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select c from repeat_qa),'role','authenticated')::text,true);
select public.complete_chore(wt,gen_random_uuid()) from repeat_qa;
do $$begin
 begin perform public.complete_chore((select wt from repeat_qa),gen_random_uuid());raise exception 'Weekly cap bypassed';exception when others then if sqlerrm<>'This chore has reached its household limit for this week.' then raise;end if;end;
 begin perform public.complete_chore((select mt from repeat_qa),gen_random_uuid());raise exception 'Monthly cap bypassed';exception when others then if sqlerrm<>'This chore has reached its household limit for this month.' then raise;end if;end;
 if exists(select 1 from jsonb_array_elements(public.chore_schedule((select h from repeat_qa))) r where (r->>'remaining')::integer<>0) then raise exception 'Exhausted chores still remaining';end if;
 if exists(select 1 from public.chore_tags where household_id=(select h from repeat_qa) and not active) then raise exception 'Configured chore inactive';end if;
 begin perform public.save_chore_rewards(h,w,'Weekly chore','',10,4,'{}',true,null,'weekly',null,'{}') from repeat_qa;raise exception 'Non-admin edited chore';exception when others then if sqlerrm='Non-admin edited chore' then raise;end if;end;
end $$;
reset role;
-- Previous-period completions do not consume this period's multi-use limit.
update public.chore_completions set chore_date=date '2000-01-01',completed_at=timestamp with time zone '2000-01-01 00:00:00Z' where household_id=(select h from repeat_qa);
set local role authenticated;
select public.complete_chore(wt,gen_random_uuid()),public.complete_chore(mt,gen_random_uuid()) from repeat_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from repeat_qa),'role','authenticated')::text,true);
do $$begin
 if (select (r->>'remaining')::integer from jsonb_array_elements(public.chore_schedule((select h from repeat_qa))) r where r->>'frequency'='weekly')<>2 then raise exception 'Weekly reset/count wrong';end if;
 if (select (r->>'remaining')::integer from jsonb_array_elements(public.chore_schedule((select h from repeat_qa))) r where r->>'frequency'='monthly')<>1 then raise exception 'Monthly reset/count wrong';end if;
 perform public.delete_chore((select h from repeat_qa),(select w from repeat_qa));
end $$;
reset role;
do $$begin
 if exists(select 1 from public.chore_tags where id=(select w from repeat_qa) and (deleted_at is null or active)) then raise exception 'Deletion no longer deactivates chores';end if;
 if not exists(select 1 from public.chore_completions where tag_id=(select w from repeat_qa)) then raise exception 'Deletion lost history';end if;
end $$;
select 'PASS: weekly and monthly multi-use save/claim, household caps, period counts/reset, always-active configuration, admin enforcement and retained deletion/history' as result;
rollback;
