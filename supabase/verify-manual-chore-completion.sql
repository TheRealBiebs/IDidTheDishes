begin;
create temp table manual_qa(a uuid,b uuid,o uuid,h uuid,chore uuid,cooldown uuid,personal uuid,team_chore uuid,team uuid,token uuid,req uuid,completion uuid);
grant all on manual_qa to authenticated,anon;
insert into manual_qa(a,b,o,team,token,req) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email) select a,'manual-a-'||a||'@example.invalid' from manual_qa union all select b,'manual-b-'||b||'@example.invalid' from manual_qa union all select o,'manual-o-'||o||'@example.invalid' from manual_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from manual_qa),'role','authenticated')::text,true);
set local role authenticated;
update manual_qa set h=public.create_household_experience('Manual QA','Admin','UTC','parents','{}');
select public.set_household_experience(h,'parents',true) from manual_qa;
reset role;
insert into public.household_teams(id,household_id,name,color,symbol) select team,h,'Assigned team','#112233','star' from manual_qa;
update public.household_members set team_id=(select team from manual_qa) where household_id=(select h from manual_qa);
insert into public.household_members(household_id,user_id,display_name,role) select h,b,'Member B','member' from manual_qa;
set local role authenticated;
update manual_qa set chore=public.save_chore_rewards(h,null,'Manual chore','',10,2,'{}',true,0,'daily',null,'{}','rainbow'),cooldown=public.save_chore_rewards(h,null,'Cooldown chore','',10,3,'{}',true,60,'daily',null,'{}'),personal=public.save_chore_rewards(h,null,'Personal chore','',10,2,array[a],true,0,'daily',null,'{}'),team_chore=public.save_chore_rewards(h,null,'Team chore','',10,2,'{}',true,0,'daily',team,'{}');
update manual_qa set completion=(public.complete_chore_by_id(chore,req)->>'id')::uuid;
do $$declare again jsonb;begin
 again:=public.complete_chore_by_id((select chore from manual_qa),(select req from manual_qa));
 if again->>'id'<>(select completion::text from manual_qa) or again->>'calendar_sticker'<>'rainbow' then raise exception 'Manual retry/snapshot failed';end if;
 begin perform public.complete_chore_by_id((select personal from manual_qa),(select req from manual_qa));raise exception 'Request reused for other chore';exception when others then if sqlerrm<>'This scan request was already used.' then raise;end if;end;
 perform public.complete_chore_by_id((select cooldown from manual_qa),gen_random_uuid());
end $$;
reset role;
do $$begin
 if exists(select 1 from app_private.sticker_inventory where chore_tag_id=(select chore from manual_qa)) then raise exception 'Manual completion required a sticker';end if;
 if (select count(*) from public.chore_completions where tag_id=(select chore from manual_qa))<>1 then raise exception 'Manual retry duplicated points';end if;
 if not exists(select 1 from public.notifications where completion_id=(select completion from manual_qa) and user_id=(select b from manual_qa)) then raise exception 'Manual completion did not notify household';end if;
end $$;
insert into app_private.sticker_inventory(token,chore_tag_id,household_id,written_at) select token,chore,h,now() from manual_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from manual_qa),'role','authenticated')::text,true);
set local role authenticated;
select public.complete_chore(token,gen_random_uuid()) from manual_qa;
do $$begin
 begin perform public.complete_chore_by_id((select chore from manual_qa),gen_random_uuid());raise exception 'Mixed manual/NFC cap bypassed';exception when others then if sqlerrm<>'This chore has reached its household limit for today.' then raise;end if;end;
 begin perform public.complete_chore_by_id((select cooldown from manual_qa),gen_random_uuid());raise exception 'Cooldown bypassed';exception when others then if sqlerrm not like 'This chore is cooling down.%' then raise;end if;end;
 begin perform public.complete_chore_by_id((select personal from manual_qa),gen_random_uuid());raise exception 'Person restriction bypassed';exception when others then if sqlerrm<>'This chore is assigned to other household members.' then raise;end if;end;
 begin perform public.complete_chore_by_id((select team_chore from manual_qa),gen_random_uuid());raise exception 'Team restriction bypassed';exception when others then if sqlerrm<>'This chore is assigned to another team.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select o from manual_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.complete_chore_by_id((select chore from manual_qa),gen_random_uuid());raise exception 'Outsider logged chore';exception when others then if sqlerrm<>'Join the household for this sticker before logging its chore.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from manual_qa),'role','authenticated')::text,true);
select public.delete_chore(h,personal) from manual_qa;
do $$begin
 begin perform public.complete_chore_by_id((select personal from manual_qa),gen_random_uuid());raise exception 'Deleted chore logged';exception when others then if sqlerrm<>'Join the household for this sticker before logging its chore.' then raise;end if;end;
 begin perform app_private.complete_chore_entry((select chore from manual_qa),gen_random_uuid());raise exception 'Internal completion endpoint exposed';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$begin
 begin perform public.complete_chore_by_id((select chore from manual_qa),gen_random_uuid());raise exception 'Anonymous logged chore';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: manual completion without inventory, same NFC limits/permissions/cooldown/notifications, reward snapshots, retry idempotency, deleted/foreign/anonymous guards' as result;
rollback;
