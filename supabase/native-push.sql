-- Android tokens use the existing per-user subscriptions and durable delivery queue.
begin;
create or replace function app_private.save_native_subscription(p_token text) returns void
language plpgsql security definer set search_path='' as $$
declare endpoint_value text;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_token is null or length(p_token) not between 20 and 4096 or p_token !~ '^[A-Za-z0-9:_-]+$' then
  raise exception 'Invalid Android notification token.';
 end if;
 endpoint_value := 'fcm:' || p_token;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if not exists(select 1 from public.push_subscriptions where endpoint=endpoint_value)
    and (select count(*) from public.push_subscriptions where user_id=auth.uid())>=10 then
  raise exception 'Up to 10 devices can receive notifications per account.';
 end if;
 insert into public.push_subscriptions(user_id,endpoint,subscription)
 values(auth.uid(),endpoint_value,jsonb_build_object('platform','android','token',p_token))
 on conflict(endpoint) do update set subscription=excluded.subscription
 where public.push_subscriptions.user_id=auth.uid();
 if not found then raise exception 'This device subscription belongs to another account. Please enable notifications again.'; end if;
end $$;
create or replace function public.save_native_subscription(p_token text) returns void
language sql security invoker set search_path='' as $$select app_private.save_native_subscription(p_token)$$;
revoke all on function app_private.save_native_subscription(text),public.save_native_subscription(text) from public,anon,authenticated,service_role;
grant execute on function app_private.save_native_subscription(text),public.save_native_subscription(text) to authenticated;

-- Only service_role can call this wrapper or its private implementation.
create or replace function app_private.push_runtime() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service access required.'; end if;
 select jsonb_object_agg(name,decrypted_secret) into result from vault.decrypted_secrets
 where name in ('dishes_push_webhook','dishes_vapid_private','dishes_vapid_public','dishes_fcm_service_account');
 return result;
end $$;
revoke all on function app_private.push_runtime(),public.push_runtime() from public,anon,authenticated;
grant execute on function app_private.push_runtime(),public.push_runtime() to service_role;
commit;
