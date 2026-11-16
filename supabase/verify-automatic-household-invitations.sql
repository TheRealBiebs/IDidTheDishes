begin;
create temp table invite_qa(a uuid,b uuid,c uuid,h uuid,code uuid,old_code uuid);
grant all on invite_qa to authenticated,anon;
insert into invite_qa(a,b,c) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'invite-owner-'||a||'@example.invalid' from invite_qa
union all select b,'invite-member-'||b||'@example.invalid' from invite_qa
union all select c,'invite-outsider-'||c||'@example.invalid' from invite_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from invite_qa),'role','authenticated')::text,true);
set local role authenticated;
update invite_qa set h=public.create_household_experience('Auto invite QA','Admin','UTC','wizard','{}');
update invite_qa set code=public.invite_code(h,false);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from invite_qa),'role','authenticated')::text,true);
do $$declare joined uuid; begin
 joined:=public.join_household((select code from invite_qa),'Invited member');
 if joined<>(select h from invite_qa) or not exists(select 1 from public.household_members where household_id=joined and user_id=auth.uid() and role='member') then raise exception 'Invitation did not grant immediate regular membership'; end if;
 perform public.join_household((select code from invite_qa),'Changed name');
 if (select count(*) from public.household_members where household_id=joined and user_id=auth.uid())<>1 then raise exception 'Repeat join duplicated membership'; end if;
 if exists(select 1 from public.household_join_requests where household_id=joined and user_id=auth.uid() and status='pending') then raise exception 'Join created an approval request'; end if;
 begin perform public.invite_code(joined,true);raise exception 'Member rotated invitation';exception when others then if sqlerrm<>'Only the household admin can manage invitations.' then raise;end if;end;
 begin perform public.join_household(gen_random_uuid(),'Invalid');raise exception 'Invalid invite accepted';exception when others then if sqlerrm<>'This invitation is invalid or has been replaced.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from invite_qa),'role','authenticated')::text,true);
update invite_qa set old_code=code,code=public.invite_code(h,true);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select c from invite_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.join_household((select old_code from invite_qa),'Outsider');raise exception 'Replaced invite accepted';exception when others then if sqlerrm<>'This invitation is invalid or has been replaced.' then raise;end if;end;
 begin perform public.join_household((select code from invite_qa),' ');raise exception 'Blank name accepted';exception when others then if sqlerrm<>'Choose a name between 1 and 60 characters.' then raise;end if;end;
end $$;
reset role;
create temp table invite_fill as select gen_random_uuid() as id from generate_series(1,48);
insert into auth.users(id,email) select id,'invite-fill-'||id||'@example.invalid' from invite_fill;
insert into public.household_members(household_id,user_id,display_name,role) select (select h from invite_qa),id,'Capacity test','member' from invite_fill;
set local role authenticated;
do $$begin
 begin perform public.join_household((select code from invite_qa),'Outsider');raise exception 'Capacity exceeded';exception when others then if sqlerrm<>'This household has reached 50 members.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from invite_qa),'role','authenticated')::text,true);
select public.join_household(code,'Existing member') from invite_qa;
select set_config('request.jwt.claims','{}',true);
do $$begin
 begin perform public.join_household((select code from invite_qa),'Nobody');raise exception 'Unauthenticated join accepted';exception when others then if sqlerrm<>'Please sign in.' then raise;end if;end;
end $$;
set local role anon;
do $$begin
 begin perform public.join_household((select code from invite_qa),'Anonymous');raise exception 'Anonymous role accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: immediate member access, repeat joins, role restrictions, invalid/rotated links, names, capacity, auth; all fixtures rolled back' as result;
rollback;
