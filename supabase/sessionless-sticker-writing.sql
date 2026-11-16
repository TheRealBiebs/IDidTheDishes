-- Each sticker is issued independently. No writing-session/batch row is needed.
create or replace function app_private.reserve_workshop_sticker(p_token uuid) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 if p_token is null then raise exception 'A unique sticker token is required.';end if;
 -- Keep the client token across retries, including interrupted responses.
 insert into app_private.sticker_inventory(token) values(p_token) on conflict(token) do nothing;
 return p_token;
end $$;
create or replace function app_private.workshop_sticker(p_token uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 -- Exact lookup also recovers pending stickers from the previous batch writer.
 return (select jsonb_build_object('token',token,'written_at',written_at,'locked_at',locked_at,'claimed',household_id is not null)
  from app_private.sticker_inventory where token=p_token);
end $$;
create or replace function public.reserve_workshop_sticker(p_token uuid) returns uuid language sql security invoker set search_path='' as $$select app_private.reserve_workshop_sticker(p_token)$$;
create or replace function public.workshop_sticker(p_token uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.workshop_sticker(p_token)$$;
revoke all on function app_private.reserve_workshop_sticker(uuid),app_private.workshop_sticker(uuid),public.reserve_workshop_sticker(uuid),public.workshop_sticker(uuid) from public,anon;
grant execute on function app_private.reserve_workshop_sticker(uuid),app_private.workshop_sticker(uuid),public.reserve_workshop_sticker(uuid),public.workshop_sticker(uuid) to authenticated;
