-- IDidTheDishes application schema. Applied remotely with Supabase migrations.
-- Browser roles read through RLS; mutations use narrowly scoped RPCs.
create schema if not exists app_private;
revoke all on schema app_private from public, anon;
grant usage on schema app_private to authenticated, service_role;

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80),
  timezone text not null,
  created_at timestamptz not null default now()
);
create table public.household_members (
  household_id uuid not null references public.households on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 60),
  role text not null check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (household_id,user_id)
);
create index members_user_idx on public.household_members(user_id);
create table app_private.household_invites (
  household_id uuid primary key references public.households on delete cascade,
  code uuid not null unique default gen_random_uuid()
);
create table public.chore_tags (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households on delete cascade,
  token uuid not null unique default gen_random_uuid(),
  chore text not null check (length(trim(chore)) between 1 and 100),
  location text not null default '' check (length(location)<=80),
  points integer not null check (points between 1 and 1000),
  daily_limit integer not null check (daily_limit between 1 and 100),
  eligible_users uuid[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index tags_household_idx on public.chore_tags(household_id);
create table public.chore_completions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households on delete cascade,
  tag_id uuid not null references public.chore_tags,
  user_id uuid not null references auth.users on delete cascade,
  chore text not null,
  points integer not null,
  completed_at timestamptz not null default now(),
  chore_date date not null,
  request_id uuid not null,
  unique(user_id,request_id)
);
create index completions_household_date_idx on public.chore_completions(household_id,chore_date desc);
create index completions_tag_date_idx on public.chore_completions(tag_id,chore_date);
create index completions_user_idx on public.chore_completions(user_id);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  household_id uuid not null references public.households on delete cascade,
  completion_id uuid not null references public.chore_completions on delete cascade,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_created_idx on public.notifications(user_id,created_at desc);
create index notifications_household_idx on public.notifications(household_id);
create index notifications_completion_idx on public.notifications(completion_id);
create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  endpoint text not null unique,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);
create index push_user_idx on public.push_subscriptions(user_id);
create table app_private.push_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications on delete cascade,
  subscription_id uuid not null references public.push_subscriptions on delete cascade,
  attempts integer not null default 0,
  next_attempt timestamptz not null default now(),
  status text not null default 'pending' check(status in ('pending','processing','sent','failed')),
  last_error text,
  unique(notification_id,subscription_id)
);
create index push_pending_idx on app_private.push_jobs(next_attempt) where status in ('pending','processing');

create function app_private.is_member(h uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.household_members where household_id=h and user_id=auth.uid())
$$;
create function app_private.is_owner(h uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.household_members where household_id=h and user_id=auth.uid() and role='owner')
$$;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.chore_tags enable row level security;
alter table public.chore_completions enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subscriptions enable row level security;
alter table app_private.household_invites enable row level security;
alter table app_private.push_jobs enable row level security;
create policy household_read on public.households for select to authenticated using(app_private.is_member(id));
create policy member_read on public.household_members for select to authenticated using(app_private.is_member(household_id));
create policy tag_read on public.chore_tags for select to authenticated using(app_private.is_member(household_id));
create policy completion_read on public.chore_completions for select to authenticated using(app_private.is_member(household_id));
create policy notification_read on public.notifications for select to authenticated using(user_id=(select auth.uid()) and app_private.is_member(household_id));
create policy subscription_read on public.push_subscriptions for select to authenticated using(user_id=(select auth.uid()));
revoke all on public.households,public.household_members,public.chore_tags,public.chore_completions,public.notifications,public.push_subscriptions from anon,authenticated;
grant select on public.households,public.household_members,public.chore_tags,public.chore_completions,public.notifications,public.push_subscriptions to authenticated;

create function app_private.create_household(p_name text,p_display_name text,p_timezone text) returns uuid
language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'Choose a valid time zone.'; end if;
 if (select count(*) from public.household_members where user_id=auth.uid() and role='owner')>=10 then raise exception 'You can own up to 10 households.'; end if;
 insert into public.households(name,timezone) values(trim(p_name),p_timezone) returning id into h;
 insert into public.household_members values(h,auth.uid(),trim(p_display_name),'owner',now());
 insert into app_private.household_invites(household_id) values(h);
 return h;
end $$;
create function app_private.join_household(p_code uuid,p_display_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select household_id into h from app_private.household_invites where code=p_code;
 if h is null then raise exception 'This invitation is invalid or has been replaced.'; end if;
 perform 1 from public.households where id=h for update;
 if (select count(*) from public.household_members where household_id=h)>=50 then raise exception 'This household has reached 50 members.'; end if;
 insert into public.household_members values(h,auth.uid(),trim(p_display_name),'member',now()) on conflict do nothing;
 return h;
end $$;
create function app_private.invite_code(p_household uuid,p_rotate boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare c uuid;
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can manage invitations.'; end if;
 if p_rotate then update app_private.household_invites set code=gen_random_uuid() where household_id=p_household; end if;
 select code into c from app_private.household_invites where household_id=p_household;
 return c;
end $$;
create function app_private.save_tag(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare t uuid;
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can configure stickers.'; end if;
 if p_eligible is null then raise exception 'Choose everyone or specific members.'; end if;
 if exists(select 1 from unnest(p_eligible) u where not exists(select 1 from public.household_members m where m.household_id=p_household and m.user_id=u)) then raise exception 'Choose members of this household.'; end if;
 if p_tag is null then
  if (select count(*) from public.chore_tags where household_id=p_household)>=100 then raise exception 'A household can have up to 100 stickers.'; end if;
  insert into public.chore_tags(household_id,chore,location,points,daily_limit,eligible_users,active) values(p_household,trim(p_chore),trim(p_location),p_points,p_limit,p_eligible,p_active) returning id into t;
 else
  update public.chore_tags set chore=trim(p_chore),location=trim(p_location),points=p_points,daily_limit=p_limit,eligible_users=p_eligible,active=p_active where id=p_tag and household_id=p_household returning id into t;
  if t is null then raise exception 'Sticker not found.'; end if;
 end if;
 return t;
end $$;
create function app_private.resolve_tag(p_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.chore_tags;
begin
 select * into t from public.chore_tags where token=p_token;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'This sticker is not available to your account. Join its household first.'; end if;
 return to_jsonb(t);
end $$;
create function app_private.complete_chore(p_token uuid,p_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select * into t from public.chore_tags where token=p_token for update;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'Join this sticker’s household before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id<>t.id then raise exception 'This scan request was already used.'; end if;
  return to_jsonb(c);
 end if;
 if not t.active then raise exception 'This sticker is paused.'; end if;
 if cardinality(t.eligible_users)>0 and not auth.uid()=any(t.eligible_users) then raise exception 'This chore is assigned to other household members.'; end if;
 select (now() at time zone timezone)::date into d from public.households where id=t.household_id;
 select count(*) into count_today from public.chore_completions where tag_id=t.id and chore_date=d;
 if count_today>=t.daily_limit then raise exception 'This chore has reached its household limit for today.'; end if;
 -- A fresh browser window from the same physical tap must not award again.
 if exists(select 1 from public.chore_completions where tag_id=t.id and user_id=auth.uid() and completed_at>now()-interval '30 seconds') then raise exception 'Already logged just now. Wait 30 seconds before another completion.'; end if;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id) values(t.household_id,t.id,auth.uid(),t.chore,t.points,d,p_request) returning * into c;
 select display_name into n from public.household_members where household_id=t.household_id and user_id=auth.uid();
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||' (+'||t.points||' points)' from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $$;
create function app_private.read_notifications() returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 update public.notifications set read_at=now() where user_id=auth.uid() and read_at is null;
end $$;
create function app_private.save_subscription(p_subscription jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if length(p_subscription::text)>4096 or p_subscription->>'endpoint' !~ '^https://(fcm[.]googleapis[.]com|updates[.]push[.]services[.]mozilla[.]com|web[.]push[.]apple[.]com|[a-zA-Z0-9-]+[.]notify[.]windows[.]com)/' or length(coalesce(p_subscription#>>'{keys,p256dh}','')) not between 80 and 200 or length(coalesce(p_subscription#>>'{keys,auth}','')) not between 16 and 100 then raise exception 'Unsupported push subscription.'; end if;
 insert into public.push_subscriptions(user_id,endpoint,subscription) values(auth.uid(),p_subscription->>'endpoint',p_subscription)
 on conflict(endpoint) do update set user_id=auth.uid(),subscription=excluded.subscription;
end $$;
create function app_private.remove_subscription(p_endpoint text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 delete from public.push_subscriptions where user_id=auth.uid() and endpoint=p_endpoint;
end $$;

-- Exposed API wrappers use invoker security; privileged code stays private.
create function public.create_household(p_name text,p_display_name text,p_timezone text) returns uuid language sql security invoker set search_path='' as $$select app_private.create_household(p_name,p_display_name,p_timezone)$$;
create function public.join_household(p_code uuid,p_display_name text) returns uuid language sql security invoker set search_path='' as $$select app_private.join_household(p_code,p_display_name)$$;
create function public.invite_code(p_household uuid,p_rotate boolean default false) returns uuid language sql security invoker set search_path='' as $$select app_private.invite_code(p_household,p_rotate)$$;
create function public.save_tag(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean) returns uuid language sql security invoker set search_path='' as $$select app_private.save_tag(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active)$$;
create function public.resolve_tag(p_token uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.resolve_tag(p_token)$$;
create function public.complete_chore(p_token uuid,p_request uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.complete_chore(p_token,p_request)$$;
create function public.read_notifications() returns void language sql security invoker set search_path='' as $$select app_private.read_notifications()$$;
create function public.save_subscription(p_subscription jsonb) returns void language sql security invoker set search_path='' as $$select app_private.save_subscription(p_subscription)$$;
create function public.remove_subscription(p_endpoint text) returns void language sql security invoker set search_path='' as $$select app_private.remove_subscription(p_endpoint)$$;

-- Durable push queue: immediate wakeup plus a one-minute retry worker.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;
create function app_private.wake_push() returns void language plpgsql security definer set search_path='' as $$
declare secret text;
begin
 select decrypted_secret into secret from vault.decrypted_secrets where name='dishes_push_webhook';
 if secret is not null then
  perform net.http_post(url:='https://oqciivgizvuzuxxzhglq.supabase.co/functions/v1/chore-push',headers:=jsonb_build_object('Content-Type','application/json','x-webhook-secret',secret),body:='{}'::jsonb,timeout_milliseconds:=10000);
 end if;
end $$;
create function app_private.queue_push() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into app_private.push_jobs(notification_id,subscription_id) select new.id,id from public.push_subscriptions where user_id=new.user_id;
 if found then perform app_private.wake_push(); end if;
 return new;
end $$;
create trigger queue_chore_notification after insert on public.notifications for each row execute function app_private.queue_push();

create function app_private.push_runtime() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service access required.'; end if;
 select jsonb_object_agg(name,decrypted_secret) into result from vault.decrypted_secrets where name in ('dishes_push_webhook','dishes_vapid_private','dishes_vapid_public');
 return result;
end $$;
create function app_private.claim_push_jobs() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service access required.'; end if;
 with candidates as(select id from app_private.push_jobs where status in ('pending','processing') and next_attempt<=now() and attempts<5 order by next_attempt for update skip locked limit 20),
 claimed as(update app_private.push_jobs j set status='processing',attempts=attempts+1,next_attempt=now()+interval '2 minutes' from candidates c where j.id=c.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'subscription_id',s.id,'subscription',s.subscription,'message',n.message,'household_id',n.household_id,'notification_id',n.id)),'[]') into result from claimed j join public.push_subscriptions s on s.id=j.subscription_id join public.notifications n on n.id=j.notification_id;
 return result;
end $$;
create function app_private.finish_push_job(p_job uuid,p_success boolean,p_expired boolean,p_error text) returns void language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service access required.'; end if;
 if p_expired then delete from public.push_subscriptions where id=(select subscription_id from app_private.push_jobs where id=p_job); return; end if;
 update app_private.push_jobs set status=case when p_success then 'sent' when attempts>=5 then 'failed' else 'pending' end,last_error=left(p_error,500),next_attempt=now()+interval '1 minute' * power(2,attempts) where id=p_job;
end $$;
create function public.push_runtime() returns jsonb language sql security invoker set search_path='' as $$select app_private.push_runtime()$$;
create function public.claim_push_jobs() returns jsonb language sql security invoker set search_path='' as $$select app_private.claim_push_jobs()$$;
create function public.finish_push_job(p_job uuid,p_success boolean,p_expired boolean,p_error text) returns void language sql security invoker set search_path='' as $$select app_private.finish_push_job(p_job,p_success,p_expired,p_error)$$;

-- Explicit allowlists: no browser-accessible mutations beyond these APIs.
revoke all on all functions in schema app_private from public,anon,authenticated,service_role;
grant execute on function app_private.is_member(uuid),app_private.is_owner(uuid),app_private.create_household(text,text,text),app_private.join_household(uuid,text),app_private.invite_code(uuid,boolean),app_private.save_tag(uuid,uuid,text,text,integer,integer,uuid[],boolean),app_private.resolve_tag(uuid),app_private.complete_chore(uuid,uuid),app_private.read_notifications(),app_private.save_subscription(jsonb),app_private.remove_subscription(text) to authenticated;
revoke all on function public.create_household(text,text,text),public.join_household(uuid,text),public.invite_code(uuid,boolean),public.save_tag(uuid,uuid,text,text,integer,integer,uuid[],boolean),public.resolve_tag(uuid),public.complete_chore(uuid,uuid),public.read_notifications(),public.save_subscription(jsonb),public.remove_subscription(text) from public,anon;
grant execute on function public.create_household(text,text,text),public.join_household(uuid,text),public.invite_code(uuid,boolean),public.save_tag(uuid,uuid,text,text,integer,integer,uuid[],boolean),public.resolve_tag(uuid),public.complete_chore(uuid,uuid),public.read_notifications(),public.save_subscription(jsonb),public.remove_subscription(text) to authenticated;
revoke all on function public.push_runtime(),public.claim_push_jobs(),public.finish_push_job(uuid,boolean,boolean,text) from public,anon,authenticated;
grant execute on function public.push_runtime(),public.claim_push_jobs(),public.finish_push_job(uuid,boolean,boolean,text),app_private.push_runtime(),app_private.claim_push_jobs(),app_private.finish_push_job(uuid,boolean,boolean,text) to service_role;

alter publication supabase_realtime add table public.notifications,public.chore_completions,public.chore_tags,public.household_members;
select cron.schedule('dishes-push-retry','* * * * *',$job$select app_private.wake_push() where exists(select 1 from app_private.push_jobs where status in ('pending','processing') and attempts<5 and next_attempt<=now())$job$);
