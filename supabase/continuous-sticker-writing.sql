begin;
create function app_private.start_sticker_session(p_label text) returns uuid
language plpgsql security definer set search_path='' as $$
declare batch uuid;
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 insert into app_private.sticker_batches(label,created_by) values(trim(p_label),auth.uid()) returning id into batch;
 return batch;
end $$;
create function app_private.reserve_sticker(p_batch uuid,p_token uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare existing_batch uuid;
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 perform 1 from app_private.sticker_batches where id=p_batch for update;
 if not found then raise exception 'Choose an existing writing session.';end if;
 if p_token is null then raise exception 'A unique sticker token is required.';end if;
 -- The client keeps this random token until verified. Retrying the reservation
 -- after an interrupted response cannot allocate another URL for the same tap.
 insert into app_private.sticker_inventory(token,batch_id) values(p_token,p_batch) on conflict(token) do nothing;
 select batch_id into existing_batch from app_private.sticker_inventory where token=p_token;
 if existing_batch is distinct from p_batch then raise exception 'This token belongs to another batch.';end if;
 return p_token;
end $$;
create function public.start_sticker_session(p_label text) returns uuid language sql security invoker set search_path='' as $$select app_private.start_sticker_session(p_label)$$;
create function public.reserve_sticker(p_batch uuid,p_token uuid) returns uuid language sql security invoker set search_path='' as $$select app_private.reserve_sticker(p_batch,p_token)$$;
revoke all on function app_private.start_sticker_session(text),public.start_sticker_session(text),app_private.reserve_sticker(uuid,uuid),public.reserve_sticker(uuid,uuid) from public,anon;
grant execute on function app_private.start_sticker_session(text),public.start_sticker_session(text),app_private.reserve_sticker(uuid,uuid),public.reserve_sticker(uuid,uuid) to authenticated;
commit;
