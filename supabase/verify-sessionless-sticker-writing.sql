begin;
create temp table writer_qa(a uuid,b uuid,token uuid,legacy_token uuid,batch uuid,batches bigint);
grant all on writer_qa to authenticated,anon;
insert into writer_qa(a,b,token,legacy_token,batches) select gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),count(*) from app_private.sticker_batches;
insert into auth.users(id,email) select a,'writer-admin-'||a||'@example.invalid' from writer_qa union all select b,'writer-member-'||b||'@example.invalid' from writer_qa;
insert into app_private.platform_admins(user_id) select a from writer_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from writer_qa),'role','authenticated')::text,true);
set local role authenticated;
do $$declare t uuid:=(select token from writer_qa);begin
 if public.reserve_workshop_sticker(t)<>t then raise exception 'Reservation changed token';end if;
 perform public.reserve_workshop_sticker(t);
 if public.workshop_sticker(t)->>'token'<>t::text then raise exception 'Reserved sticker not found';end if;
 if public.inspect_sticker(t)->>'status'<>'preparing' then raise exception 'Unverified sticker became claimable';end if;
 perform public.mark_sticker_written(t,true);
 if public.inspect_sticker(t)->>'status'<>'available' or public.workshop_sticker(t)->>'locked_at' is null then raise exception 'Verified sticker was not ready/locked';end if;
 if public.workshop_sticker(gen_random_uuid()) is not null then raise exception 'Unknown sticker found';end if;
 begin perform public.reserve_workshop_sticker(null);raise exception 'Null token accepted';exception when others then if sqlerrm<>'A unique sticker token is required.' then raise;end if;end;
end $$;
reset role;
do $$begin
 if (select count(*) from app_private.sticker_batches)<>(select batches from writer_qa) then raise exception 'Writing created a session';end if;
 if (select count(*) from app_private.sticker_inventory where token=(select token from writer_qa))<>1 then raise exception 'Retry duplicated inventory';end if;
 if exists(select 1 from app_private.sticker_inventory where token=(select token from writer_qa) and batch_id is not null) then raise exception 'Sticker requires a session';end if;
end $$;
insert into app_private.sticker_batches(label,created_by) select 'Legacy recovery QA',a from writer_qa;
update writer_qa set batch=(select id from app_private.sticker_batches where label='Legacy recovery QA' and created_by=writer_qa.a);
insert into app_private.sticker_inventory(token,batch_id) select legacy_token,batch from writer_qa;
set local role authenticated;
do $$begin
 if public.workshop_sticker((select legacy_token from writer_qa)) is null then raise exception 'Legacy pending sticker cannot be recovered';end if;
 perform public.mark_sticker_written((select legacy_token from writer_qa),false);
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from writer_qa),'role','authenticated')::text,true);
do $$begin
 begin perform public.reserve_workshop_sticker(gen_random_uuid());raise exception 'Ordinary member issued inventory';exception when others then if sqlerrm<>'Platform admin access required.' then raise;end if;end;
 begin perform public.workshop_sticker((select token from writer_qa));raise exception 'Ordinary member read inventory';exception when others then if sqlerrm<>'Platform admin access required.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$begin
 begin perform public.reserve_workshop_sticker(gen_random_uuid());raise exception 'Anonymous issued inventory';exception when insufficient_privilege then null;end;
 begin perform public.workshop_sticker((select token from writer_qa));raise exception 'Anonymous read inventory';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: sessionless unique inventory, idempotency, verification/locking, old sticker recovery and platform-only access; fixtures rolled back' as result;
rollback;
