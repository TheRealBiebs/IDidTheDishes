-- A browser subscription moving to another account must not inherit queued pushes.
create or replace function app_private.save_subscription(p_subscription jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if length(p_subscription::text)>4096 or p_subscription->>'endpoint' !~ '^https://(fcm[.]googleapis[.]com|updates[.]push[.]services[.]mozilla[.]com|web[.]push[.]apple[.]com|[a-zA-Z0-9-]+[.]notify[.]windows[.]com)/' or length(coalesce(p_subscription#>>'{keys,p256dh}','')) not between 80 and 200 or length(coalesce(p_subscription#>>'{keys,auth}','')) not between 16 and 100 then raise exception 'Unsupported push subscription.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));

 if not exists(select 1 from public.push_subscriptions where endpoint=p_subscription->>'endpoint') and (select count(*) from public.push_subscriptions where user_id=auth.uid())>=10 then raise exception 'Up to 10 devices can receive notifications per account.'; end if;
 insert into public.push_subscriptions(user_id,endpoint,subscription) values(auth.uid(),p_subscription->>'endpoint',p_subscription)
 on conflict(endpoint) do update set subscription=excluded.subscription where public.push_subscriptions.user_id=auth.uid();
 if not found then raise exception 'This device subscription belongs to another account. Please enable notifications again.'; end if;
end $$;
create policy private_invites_deny on app_private.household_invites for all to authenticated using(false) with check(false);
create policy private_push_deny on app_private.push_jobs for all to authenticated using(false) with check(false);
