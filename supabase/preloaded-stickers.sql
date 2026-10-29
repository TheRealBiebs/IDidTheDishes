begin;
create table app_private.platform_admins(user_id uuid primary key references auth.users on delete cascade,created_at timestamptz not null default now());
alter table app_private.platform_admins enable row level security;
create function app_private.is_platform_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from app_private.platform_admins where user_id=auth.uid())
$$;
create table app_private.sticker_batches(id uuid primary key default gen_random_uuid(),label text not null check(length(trim(label)) between 1 and 80),created_by uuid references auth.users on delete set null,created_at timestamptz not null default now());
create index sticker_batch_creator_idx on app_private.sticker_batches(created_by);
create table app_private.sticker_inventory(
 token uuid primary key default gen_random_uuid(),batch_id uuid references app_private.sticker_batches on delete restrict,
 chore_tag_id uuid unique references public.chore_tags on delete restrict,
 household_id uuid references public.households on delete restrict,
 generation integer not null default 0,written_at timestamptz,locked_at timestamptz,
 created_at timestamptz not null default now(),check((chore_tag_id is null)=(household_id is null))
);
create index sticker_batch_idx on app_private.sticker_inventory(batch_id,created_at);
create index sticker_household_idx on app_private.sticker_inventory(household_id);
alter table app_private.sticker_batches enable row level security;
alter table app_private.sticker_inventory enable row level security;
-- Preserve every existing sticker URL and its completion history.
insert into app_private.sticker_inventory(token,chore_tag_id,household_id,written_at)
 select token,id,household_id,now() from public.chore_tags;
create table public.sticker_release_requests(
 id uuid primary key default gen_random_uuid(),token uuid not null references app_private.sticker_inventory,
 generation integer not null,owner_household_id uuid not null references public.households on delete cascade,
 requester_household_id uuid not null references public.households on delete cascade,
 requester_id uuid not null references auth.users on delete cascade,chore text not null,
 status text not null default 'pending' check(status in ('pending','released','declined','obsolete')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,
 unique(token,generation,requester_household_id),check(owner_household_id<>requester_household_id)
);
create index release_owner_idx on public.sticker_release_requests(owner_household_id,status,created_at);
create index release_requester_house_idx on public.sticker_release_requests(requester_household_id);
create index release_requester_user_idx on public.sticker_release_requests(requester_id);
alter table public.sticker_release_requests enable row level security;
create policy release_requests_read on public.sticker_release_requests for select to authenticated
 using(app_private.is_admin(owner_household_id) or app_private.is_member(requester_household_id));
revoke all on public.sticker_release_requests from public,anon,authenticated;
grant select on public.sticker_release_requests to authenticated;
-- Private inventories can only be read through the narrowly scoped functions below.
revoke all on app_private.platform_admins,app_private.sticker_batches,app_private.sticker_inventory from public,anon,authenticated;

create function app_private.create_sticker_batch(p_label text,p_count integer) returns uuid
language plpgsql security definer set search_path='' as $$
declare batch uuid;
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 if p_count is null or p_count not between 1 and 200 then raise exception 'Create between 1 and 200 stickers per batch.';end if;
 insert into app_private.sticker_batches(label,created_by) values(trim(p_label),auth.uid()) returning id into batch;
 insert into app_private.sticker_inventory(batch_id) select batch from generate_series(1,p_count);
 return batch;
end $$;
create function app_private.sticker_batches() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 select coalesce(jsonb_agg(to_jsonb(b)),'[]') into result from (
 select b.id,b.label,b.created_at,count(i.token) as count,count(i.written_at) as written,count(i.locked_at) as locked
 from app_private.sticker_batches b left join app_private.sticker_inventory i on i.batch_id=b.id
 group by b.id order by b.created_at desc limit 100) b;return result;
end $$;
create function app_private.batch_stickers(p_batch uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('token',token,'written_at',written_at,'locked_at',locked_at,'claimed',household_id is not null) order by created_at,token),'[]') into result from app_private.sticker_inventory where batch_id=p_batch;
 return result;
end $$;
create function app_private.mark_sticker_written(p_token uuid,p_locked boolean) returns void language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory;begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found then raise exception 'Sticker is not in the issued inventory.';end if;
 if s.household_id is not null then raise exception 'Do not write or lock a sticker that has already been claimed.';end if;
 update app_private.sticker_inventory set written_at=coalesce(written_at,now()),locked_at=case when p_locked then coalesce(locked_at,now()) else locked_at end where token=p_token;
end $$;
create function app_private.inspect_sticker(p_token uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s app_private.sticker_inventory;t public.chore_tags;member boolean;begin
 select * into s from app_private.sticker_inventory where token=p_token;
 if not found then return jsonb_build_object('status','invalid');end if;
 if s.chore_tag_id is null then return jsonb_build_object('status',case when s.written_at is null then 'preparing' else 'available' end);end if;
 select * into t from public.chore_tags where id=s.chore_tag_id;
 member:=app_private.is_member(s.household_id);
 -- Public visitors receive only the chore title, never household/member details,
 -- location, schedules, invitation codes, or scoring/eligibility information.
 return jsonb_build_object('status','assigned','chore',t.chore,'member',member)
  ||case when member then jsonb_build_object('household_id',s.household_id,'admin',app_private.is_admin(s.household_id),'tag',to_jsonb(t)) else '{}'::jsonb end;
end $$;
create function app_private.household_stickers(p_household uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('chore_tag_id',chore_tag_id,'token',token,'locked',locked_at is not null)),'[]') into result from app_private.sticker_inventory where household_id=p_household;
 return result;
end $$;
create function app_private.claim_sticker(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory;chore_id uuid;begin
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found or s.written_at is null then raise exception 'This sticker has not been provisioned and verified yet.';end if;
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only a household admin can claim stickers.';end if;
 if s.household_id is not null then
  if s.household_id=p_household and s.chore_tag_id=p_chore then return p_chore;end if;
  raise exception 'This sticker is already claimed. Its current household must release it first.';
 end if;
 if p_chore is not null and exists(select 1 from app_private.sticker_inventory where chore_tag_id=p_chore) then raise exception 'That chore already has a sticker. Release it before assigning a different one.';end if;
 chore_id:=app_private.save_tag(p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active);
 update public.chore_tags set token=p_token where id=chore_id;
 update app_private.sticker_inventory set household_id=p_household,chore_tag_id=chore_id,generation=generation+1 where token=p_token;
 return chore_id;
end $$;
create function app_private.release_sticker(p_token uuid) returns void language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory;begin
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found or s.household_id is null then raise exception 'This sticker is not claimed.';end if;
 perform 1 from public.households where id=s.household_id for no key update;
 if not app_private.is_admin(s.household_id) then raise exception 'Only its current household admin can release this sticker.';end if;
 -- Rotate only the internal chore token. The immutable physical URL stays valid;
 -- old completion records keep referencing their original chore and household.
 update public.chore_tags set token=gen_random_uuid() where id=s.chore_tag_id;
 update app_private.sticker_inventory set household_id=null,chore_tag_id=null,generation=generation+1 where token=p_token;
 update public.sticker_release_requests set status='released',reviewed_at=now() where token=p_token and status='pending';
end $$;
create function app_private.request_sticker_release(p_token uuid,p_household uuid) returns void language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory;title text;begin
 if not app_private.is_member(p_household) then raise exception 'Choose one of your households.';end if;
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found or s.household_id is null then raise exception 'This sticker is not currently claimed.';end if;
 if s.household_id=p_household then raise exception 'This sticker already belongs to your household.';end if;
 if exists(select 1 from public.sticker_release_requests where token=p_token and generation=s.generation and requester_household_id=p_household and status='declined') then raise exception 'Your household’s release request was declined. Contact the current household admin.';end if;
 if exists(select 1 from public.sticker_release_requests where token=p_token and generation=s.generation and requester_household_id=p_household) then return;end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,32));
 if (select count(*) from public.sticker_release_requests where requester_id=auth.uid() and status='pending')>=10 then raise exception 'You can have up to 10 pending release requests.';end if;
 select chore into title from public.chore_tags where id=s.chore_tag_id;
 insert into public.sticker_release_requests(token,generation,owner_household_id,requester_household_id,requester_id,chore) values(p_token,s.generation,s.household_id,p_household,auth.uid(),title);
end $$;
create function app_private.review_sticker_release(p_request uuid,p_release boolean) returns void language plpgsql security definer set search_path='' as $$
declare r public.sticker_release_requests;s app_private.sticker_inventory;begin
 select * into r from public.sticker_release_requests where id=p_request;
 if not found then raise exception 'Release request not found.';end if;
 select * into s from app_private.sticker_inventory where token=r.token for update;
 perform 1 from public.households where id=r.owner_household_id for no key update;
 if not app_private.is_admin(r.owner_household_id) then raise exception 'Only the original household admin can review this request.';end if;
 if r.status<>'pending' then return;end if;
 if s.household_id is distinct from r.owner_household_id or s.generation<>r.generation then
  update public.sticker_release_requests set status='obsolete',reviewed_at=now() where id=p_request;return;
 end if;
 if p_release is null then raise exception 'Choose release or decline.';end if;
 if p_release then perform app_private.release_sticker(r.token);
 else update public.sticker_release_requests set status='declined',reviewed_at=now() where id=p_request;end if;
end $$;
alter table public.chore_tags add column starter_key text;
create unique index household_starter_chore_idx on public.chore_tags(household_id,starter_key) where starter_key is not null;

-- Canonical starter catalog and guarded public wrappers are appended below.

create function app_private.starter_chore_catalog() returns jsonb language sql immutable set search_path='' as $$select '[{"key":"dishes","name":"Do the dishes","points":10,"limit":2},{"key":"dishwasher","name":"Load or unload the dishwasher","points":10,"limit":2},{"key":"trash","name":"Take out the trash","points":10,"limit":1},{"key":"recycling","name":"Take out the recycling","points":10,"limit":1},{"key":"counters","name":"Wipe kitchen counters","points":5,"limit":3},{"key":"vacuum","name":"Vacuum the floors","points":15,"limit":1},{"key":"sweep","name":"Sweep the floors","points":10,"limit":1},{"key":"laundry","name":"Wash a load of laundry","points":15,"limit":2},{"key":"fold","name":"Fold and put away laundry","points":10,"limit":2},{"key":"bathroom","name":"Clean the bathroom","points":25,"limit":1},{"key":"pets","name":"Feed the pets","points":5,"limit":2},{"key":"plants","name":"Water the plants","points":5,"limit":1}]'::jsonb$$;
create function app_private.add_starter_chores(p_household uuid,p_keys text[]) returns integer language plpgsql security definer set search_path='' as $$
declare item jsonb;new_id uuid;added integer:=0;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only a household admin can add starter chores.';end if;
 if p_keys is null or cardinality(p_keys)>12 or exists(select 1 from unnest(p_keys) k where k is null or not exists(select 1 from jsonb_array_elements(app_private.starter_chore_catalog()) x where x->>'key'=k)) then raise exception 'Choose chores from the starter list.';end if;
 for item in select value from jsonb_array_elements(app_private.starter_chore_catalog()) where value->>'key'=any(p_keys) loop
  if not exists(select 1 from public.chore_tags where household_id=p_household and starter_key=item->>'key') then
   new_id:=app_private.save_tag(p_household,null,item->>'name','',(item->>'points')::integer,(item->>'limit')::integer,'{}',true);
   update public.chore_tags set starter_key=item->>'key' where id=new_id;added:=added+1;
  end if;
 end loop;return added;
end $$;
create function app_private.create_household_with_chores(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare h uuid;begin
 h:=app_private.create_themed_household(p_name,p_display_name,p_timezone,p_theme);
 perform app_private.add_starter_chores(h,p_starters);return h;
end $$;
CREATE OR REPLACE FUNCTION app_private.complete_chore(p_token uuid, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chore_tags; c public.chore_completions; d date; n text; count_today integer; scheme text; suffix text;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 perform 1 from app_private.sticker_inventory where token=p_token and chore_tag_id is not null for update;
 if not found then raise exception 'This sticker is unassigned or is not a valid issued sticker.';end if;
 select * into t from public.chore_tags where id=(select chore_tag_id from app_private.sticker_inventory where token=p_token) for update;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'Join this stickerâ€™s household before logging its chore.'; end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.tag_id<>t.id then raise exception 'This scan request was already used.'; end if;
  return to_jsonb(c);
 end if;
 if not t.active then raise exception 'This sticker is paused.'; end if;
 if cardinality(t.eligible_users)>0 and not auth.uid()=any(t.eligible_users) then raise exception 'This chore is assigned to other household members.'; end if;
 select (now() at time zone timezone)::date,reward_scheme into d,scheme from public.households where id=t.household_id;
 select count(*) into count_today from public.chore_completions where tag_id=t.id and chore_date=d;
 if count_today>=t.daily_limit then raise exception 'This chore has reached its household limit for today.'; end if;
 if exists(select 1 from public.chore_completions where tag_id=t.id and user_id=auth.uid() and completed_at>now()-interval '30 seconds') then raise exception 'Already logged just now. Wait 30 seconds before another completion.'; end if;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id)
 values(t.household_id,t.id,auth.uid(),t.chore,t.points,d,p_request) returning * into c;
 select display_name into n from public.household_members where household_id=t.household_id and user_id=auth.uid();
 suffix := case scheme when 'stars' then ' (+1 gold star)' when 'adventure' then '' else ' (+'||t.points||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,t.household_id,c.id,n||' completed '||t.chore||suffix from public.household_members where household_id=t.household_id and user_id<>auth.uid();
 return to_jsonb(c);
end $function$
;
CREATE OR REPLACE FUNCTION app_private.resolve_tag(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chore_tags;
begin
 select c.* into t from public.chore_tags c join app_private.sticker_inventory s on s.chore_tag_id=c.id where s.token=p_token;
 if t.id is null or not app_private.is_member(t.household_id) then raise exception 'This sticker is not available to your account. Join its household first.'; end if;
 return to_jsonb(t);
end $function$
;
create function public.is_platform_admin() returns boolean language sql security invoker set search_path='' as $$select app_private.is_platform_admin()$$;
revoke all on function public.is_platform_admin(),app_private.is_platform_admin() from public,anon;
grant execute on function public.is_platform_admin(),app_private.is_platform_admin() to authenticated;
create function public.create_sticker_batch(p_label text,p_count integer) returns uuid language sql security invoker set search_path='' as $$select app_private.create_sticker_batch(p_label,p_count)$$;
revoke all on function public.create_sticker_batch(text,integer),app_private.create_sticker_batch(text,integer) from public,anon;
grant execute on function public.create_sticker_batch(text,integer),app_private.create_sticker_batch(text,integer) to authenticated;
create function public.sticker_batches() returns jsonb language sql security invoker set search_path='' as $$select app_private.sticker_batches()$$;
revoke all on function public.sticker_batches(),app_private.sticker_batches() from public,anon;
grant execute on function public.sticker_batches(),app_private.sticker_batches() to authenticated;
create function public.batch_stickers(p_batch uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.batch_stickers(p_batch)$$;
revoke all on function public.batch_stickers(uuid),app_private.batch_stickers(uuid) from public,anon;
grant execute on function public.batch_stickers(uuid),app_private.batch_stickers(uuid) to authenticated;
create function public.mark_sticker_written(p_token uuid,p_locked boolean) returns void language sql security invoker set search_path='' as $$select app_private.mark_sticker_written(p_token,p_locked)$$;
revoke all on function public.mark_sticker_written(uuid,boolean),app_private.mark_sticker_written(uuid,boolean) from public,anon;
grant execute on function public.mark_sticker_written(uuid,boolean),app_private.mark_sticker_written(uuid,boolean) to authenticated;
create function public.inspect_sticker(p_token uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.inspect_sticker(p_token)$$;
revoke all on function public.inspect_sticker(uuid),app_private.inspect_sticker(uuid) from public,anon;
grant execute on function public.inspect_sticker(uuid),app_private.inspect_sticker(uuid) to authenticated;
create function public.household_stickers(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.household_stickers(p_household)$$;
revoke all on function public.household_stickers(uuid),app_private.household_stickers(uuid) from public,anon;
grant execute on function public.household_stickers(uuid),app_private.household_stickers(uuid) to authenticated;
create function public.claim_sticker(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean) returns uuid language sql security invoker set search_path='' as $$select app_private.claim_sticker(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active)$$;
revoke all on function public.claim_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean),app_private.claim_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean) from public,anon;
grant execute on function public.claim_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean),app_private.claim_sticker(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean) to authenticated;
create function public.release_sticker(p_token uuid) returns void language sql security invoker set search_path='' as $$select app_private.release_sticker(p_token)$$;
revoke all on function public.release_sticker(uuid),app_private.release_sticker(uuid) from public,anon;
grant execute on function public.release_sticker(uuid),app_private.release_sticker(uuid) to authenticated;
create function public.request_sticker_release(p_token uuid,p_household uuid) returns void language sql security invoker set search_path='' as $$select app_private.request_sticker_release(p_token,p_household)$$;
revoke all on function public.request_sticker_release(uuid,uuid),app_private.request_sticker_release(uuid,uuid) from public,anon;
grant execute on function public.request_sticker_release(uuid,uuid),app_private.request_sticker_release(uuid,uuid) to authenticated;
create function public.review_sticker_release(p_request uuid,p_release boolean) returns void language sql security invoker set search_path='' as $$select app_private.review_sticker_release(p_request,p_release)$$;
revoke all on function public.review_sticker_release(uuid,boolean),app_private.review_sticker_release(uuid,boolean) from public,anon;
grant execute on function public.review_sticker_release(uuid,boolean),app_private.review_sticker_release(uuid,boolean) to authenticated;
create function public.starter_chore_catalog() returns jsonb language sql security invoker set search_path='' as $$select app_private.starter_chore_catalog()$$;
revoke all on function public.starter_chore_catalog(),app_private.starter_chore_catalog() from public,anon;
grant execute on function public.starter_chore_catalog(),app_private.starter_chore_catalog() to authenticated;
create function public.add_starter_chores(p_household uuid,p_keys text[]) returns integer language sql security invoker set search_path='' as $$select app_private.add_starter_chores(p_household,p_keys)$$;
revoke all on function public.add_starter_chores(uuid,text[]),app_private.add_starter_chores(uuid,text[]) from public,anon;
grant execute on function public.add_starter_chores(uuid,text[]),app_private.add_starter_chores(uuid,text[]) to authenticated;
create function public.create_household_with_chores(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[]) returns uuid language sql security invoker set search_path='' as $$select app_private.create_household_with_chores(p_name,p_display_name,p_timezone,p_theme,p_starters)$$;
revoke all on function public.create_household_with_chores(text,text,text,text,text[]),app_private.create_household_with_chores(text,text,text,text,text[]) from public,anon;
grant execute on function public.create_household_with_chores(text,text,text,text,text[]),app_private.create_household_with_chores(text,text,text,text,text[]) to authenticated;
grant usage on schema app_private to anon;
grant execute on function public.inspect_sticker(uuid),app_private.inspect_sticker(uuid) to anon;
alter publication supabase_realtime add table public.sticker_release_requests;
commit;
