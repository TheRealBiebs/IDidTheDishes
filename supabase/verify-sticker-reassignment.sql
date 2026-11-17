begin;
create temp table assignment_qa(a uuid,b uuid,c uuid,h uuid,other_h uuid,team_a uuid,team_b uuid,source uuid,target uuid,occupied uuid,foreign_chore uuid,token uuid);
grant all on assignment_qa to authenticated,anon;
insert into assignment_qa(a,b,c,team_a,team_b) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'assignment-a-'||a||'@example.invalid' from assignment_qa union all select b,'assignment-b-'||b||'@example.invalid' from assignment_qa union all select c,'assignment-c-'||c||'@example.invalid' from assignment_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from assignment_qa),'role','authenticated')::text,true);
set local role authenticated;
update assignment_qa set h=public.create_household_experience('Assignment QA','Admin','UTC','wizard','{}'),other_h=public.create_household_experience('Other QA','Admin','UTC','wizard','{}');
select public.set_household_experience(h,'wizard',true) from assignment_qa;
reset role;
insert into public.household_teams(id,household_id,name,color,symbol) select team_a,h,'Team A','#ff0000','star' from assignment_qa union all select team_b,h,'Team B','#0000ff','star' from assignment_qa;
update public.household_members set team_id=(select team_a from assignment_qa) where household_id=(select h from assignment_qa);
insert into public.household_members(household_id,user_id,display_name,role,team_id) select h,b,'Person B','member',team_b from assignment_qa union all select h,c,'Person C','member',team_a from assignment_qa;
set local role authenticated;
update assignment_qa set source=public.save_chore_rewards(h,null,'Personal chore','',10,3,array[b],true,0,'weekly',null,'{}'),target=public.save_chore_rewards(h,null,'Team chore','',20,3,'{}',true,0,'weekly',team_a,'{}'),occupied=public.save_chore_rewards(h,null,'Occupied chore','',5,1,'{}',true,0,'daily',null,'{}'),foreign_chore=public.save_chore_rewards(other_h,null,'Foreign chore','',5,1,'{}',true,0,'daily',null,'{}');
reset role;
insert into app_private.sticker_inventory(token,chore_tag_id,household_id,written_at) select t.token,t.id,t.household_id,now() from public.chore_tags t where id in(select source from assignment_qa union all select occupied from assignment_qa);
update assignment_qa set token=(select t.token from public.chore_tags t where t.id=source);
set local role authenticated;
do $$begin
 begin perform public.complete_chore((select token from assignment_qa),gen_random_uuid());raise exception 'Wrong person completed chore';exception when others then if sqlerrm<>'This chore is assigned to other household members.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from assignment_qa),'role','authenticated')::text,true);
select public.complete_chore(token,gen_random_uuid()) from assignment_qa;
do $$begin
 if not exists(select 1 from jsonb_array_elements(public.chore_schedule((select h from assignment_qa))) r where r->>'id'=(select source::text from assignment_qa) and (r->>'assigned_to_me')::boolean) then raise exception 'Personal assignment missing from dashboard';end if;
 begin perform public.reassign_sticker((select token from assignment_qa),(select target from assignment_qa));raise exception 'Member moved sticker';exception when others then if sqlerrm<>'Only its current household admin can reassign this sticker.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from assignment_qa),'role','authenticated')::text,true);
select public.reassign_sticker(token,target),public.reassign_sticker(token,target) from assignment_qa;
do $$begin
 begin perform public.reassign_sticker((select token from assignment_qa),(select occupied from assignment_qa));raise exception 'Occupied destination accepted';exception when others then if sqlerrm<>'That chore already has a sticker. Release it before assigning a different one.' then raise;end if;end;
 begin perform public.reassign_sticker((select token from assignment_qa),(select foreign_chore from assignment_qa));raise exception 'Foreign destination accepted';exception when others then if sqlerrm<>'Choose a chore in this household.' then raise;end if;end;
 if (public.inspect_sticker((select token from assignment_qa))->'tag'->>'id')<>(select target::text from assignment_qa) then raise exception 'Move lost physical binding';end if;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from assignment_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.complete_chore((select token from assignment_qa),gen_random_uuid());raise exception 'Wrong team completed chore';exception when others then if sqlerrm<>'This chore is assigned to another team.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select c from assignment_qa),'role','authenticated')::text,true);
select public.complete_chore(token,gen_random_uuid()) from assignment_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from assignment_qa),'role','authenticated')::text,true);
select public.release_sticker(token) from assignment_qa;
reset role;
do $$begin
 if not exists(select 1 from public.chore_completions where tag_id=(select source from assignment_qa) and points=10) or not exists(select 1 from public.chore_completions where tag_id=(select target from assignment_qa) and points=20) then raise exception 'Reassignment changed history';end if;
 if (select daily_limit from public.chore_tags where id=(select target from assignment_qa))<>3 then raise exception 'Destination configuration changed';end if;
 if exists(select 1 from app_private.sticker_inventory where token=(select token from assignment_qa) and household_id is not null) then raise exception 'Release broken';end if;
end $$;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$begin
 begin perform public.reassign_sticker((select token from assignment_qa),(select target from assignment_qa));raise exception 'Anonymous moved sticker';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: atomic/idempotent reassignment, owner-only and same-household guards, occupied destination rejection, preserved history/settings, person/team scan restrictions, person dashboard assignments and release' as result;
rollback;
