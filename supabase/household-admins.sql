-- `owner` remains the stored admin role for compatibility with installed clients.
begin;
create function app_private.is_admin(h uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.household_members where household_id=h and user_id=auth.uid() and role='owner')
$$;
revoke all on function app_private.is_admin(uuid) from public,anon;
grant execute on function app_private.is_admin(uuid) to authenticated;
create or replace function app_private.is_owner(h uuid) returns boolean
language sql stable security invoker set search_path='' as $$select app_private.is_admin(h)$$;

create function app_private.set_household_admin(p_household uuid,p_user uuid,p_admin boolean) returns void
language plpgsql security definer set search_path='' as $$
declare existing_role text;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only a household admin can manage admins.'; end if;
 if p_admin is null then raise exception 'Choose an admin role.'; end if;
 select role into existing_role from public.household_members where household_id=p_household and user_id=p_user for update;
 if not found then raise exception 'Choose an existing member of this household.'; end if;
 if existing_role='owner' and not p_admin and (select count(*) from public.household_members where household_id=p_household and role='owner')<=1 then
  raise exception 'Every household needs at least one admin. Transfer your role or add another admin first.';
 end if;
 update public.household_members set role=case when p_admin then 'owner' else 'member' end where household_id=p_household and user_id=p_user;
end $$;
create function app_private.transfer_household_admin(p_household uuid,p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only a household admin can transfer their role.'; end if;
 if p_user is null or p_user=auth.uid() then raise exception 'Choose another household member.'; end if;
 perform 1 from public.household_members where household_id=p_household and user_id=p_user for update;
 if not found then raise exception 'Choose an existing member of this household.'; end if;
 update public.household_members set role='owner' where household_id=p_household and user_id=p_user;
 update public.household_members set role='member' where household_id=p_household and user_id=auth.uid();
end $$;

create table public.household_join_requests (
 id uuid primary key default gen_random_uuid(),
 household_id uuid not null references public.households on delete cascade,
 user_id uuid not null references auth.users on delete cascade,
 display_name text not null check(length(trim(display_name)) between 1 and 60),
 status text not null default 'pending' check(status in ('pending','approved','declined')),
 created_at timestamptz not null default now(),
 decided_at timestamptz,
 decided_by uuid references auth.users on delete set null,
 unique(household_id,user_id)
);
create index join_request_household_pending_idx on public.household_join_requests(household_id,created_at) where status='pending';
create index join_request_user_idx on public.household_join_requests(user_id,created_at desc);
create index join_request_decider_idx on public.household_join_requests(decided_by) where decided_by is not null;
alter table public.household_join_requests enable row level security;
create policy join_requests_read on public.household_join_requests for select to authenticated
 using(user_id=(select auth.uid()) or app_private.is_admin(household_id));
revoke all on public.household_join_requests from public,anon,authenticated;
grant select on public.household_join_requests to authenticated;

-- Invitations request access; only an admin's approval inserts a membership.
create or replace function app_private.join_household(p_code uuid,p_display_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select household_id into h from app_private.household_invites where code=p_code;
 if h is null then raise exception 'This invitation is invalid or has been replaced.'; end if;
 perform 1 from public.households where id=h for no key update;
 if not exists(select 1 from app_private.household_invites where household_id=h and code=p_code) then raise exception 'This invitation has been replaced.'; end if;
 if app_private.is_member(h) then return h; end if;
 if (select count(*) from public.household_members where household_id=h)>=50 then raise exception 'This household has reached 50 members.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,17));
 if not exists(select 1 from public.household_join_requests where household_id=h and user_id=auth.uid() and status='pending')
    and (select count(*) from public.household_join_requests where user_id=auth.uid() and status='pending')>=10 then raise exception 'You can have up to 10 pending household requests.'; end if;
 if not exists(select 1 from public.household_join_requests where household_id=h and user_id=auth.uid() and status='pending')
    and (select count(*) from public.household_join_requests where household_id=h and status='pending')>=200 then raise exception 'This household has too many pending requests. Ask an admin to review them.'; end if;
 insert into public.household_join_requests(household_id,user_id,display_name) values(h,auth.uid(),trim(p_display_name))
 on conflict(household_id,user_id) do update set display_name=excluded.display_name,status='pending',created_at=now(),decided_at=null,decided_by=null;
 return h;
end $$;
create function app_private.decide_join_request(p_request uuid,p_approve boolean) returns void
language plpgsql security definer set search_path='' as $$
declare r public.household_join_requests; target_status text;
begin
 select * into r from public.household_join_requests where id=p_request;
 if not found then raise exception 'Join request not found.'; end if;
 perform 1 from public.households where id=r.household_id for no key update;
 if not app_private.is_admin(r.household_id) then raise exception 'Only a household admin can approve or decline members.'; end if;
 if p_approve is null then raise exception 'Choose approve or decline.'; end if;
 select * into r from public.household_join_requests where id=p_request for update;
 target_status:=case when p_approve then 'approved' else 'declined' end;
 if r.status=target_status then return; end if;
 if r.status<>'pending' then raise exception 'This request has already been reviewed.'; end if;
 if p_approve then
  if not exists(select 1 from public.household_members where household_id=r.household_id and user_id=r.user_id)
    and (select count(*) from public.household_members where household_id=r.household_id)>=50 then raise exception 'This household has reached 50 members.'; end if;
  insert into public.household_members(household_id,user_id,display_name,role) values(r.household_id,r.user_id,r.display_name,'member') on conflict do nothing;
 end if;
 update public.household_join_requests set status=target_status,decided_at=now(),decided_by=auth.uid() where id=p_request;
end $$;
create function app_private.my_join_requests() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) into result from (
  select j.id,j.household_id,h.name as household_name,j.status,j.created_at
  from public.household_join_requests j join public.households h on h.id=j.household_id
  where j.user_id=auth.uid() and j.status<>'approved'
  order by (j.status='pending') desc,j.created_at desc limit 60
 ) r;
 return result;
end $$;

create function public.set_household_admin(p_household uuid,p_user uuid,p_admin boolean) returns void language sql security invoker set search_path='' as $$select app_private.set_household_admin(p_household,p_user,p_admin)$$;
create function public.transfer_household_admin(p_household uuid,p_user uuid) returns void language sql security invoker set search_path='' as $$select app_private.transfer_household_admin(p_household,p_user)$$;
create function public.decide_join_request(p_request uuid,p_approve boolean) returns void language sql security invoker set search_path='' as $$select app_private.decide_join_request(p_request,p_approve)$$;
create function public.my_join_requests() returns jsonb language sql security invoker set search_path='' as $$select app_private.my_join_requests()$$;
revoke all on function app_private.set_household_admin(uuid,uuid,boolean),app_private.transfer_household_admin(uuid,uuid),app_private.decide_join_request(uuid,boolean),app_private.my_join_requests(),public.set_household_admin(uuid,uuid,boolean),public.transfer_household_admin(uuid,uuid),public.decide_join_request(uuid,boolean),public.my_join_requests() from public,anon;
grant execute on function app_private.set_household_admin(uuid,uuid,boolean),app_private.transfer_household_admin(uuid,uuid),app_private.decide_join_request(uuid,boolean),app_private.my_join_requests(),public.set_household_admin(uuid,uuid,boolean),public.transfer_household_admin(uuid,uuid),public.decide_join_request(uuid,boolean),public.my_join_requests() to authenticated;
alter publication supabase_realtime add table public.household_join_requests;
create or replace function app_private.create_household(p_name text,p_display_name text,p_timezone text) returns uuid
language sql security invoker set search_path='' as $$select app_private.create_themed_household(p_name,p_display_name,p_timezone,'wizard')$$;

-- Guard existing mutations with the same household lock as role changes.
CREATE OR REPLACE FUNCTION app_private.add_theme_teams(p_household uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t text;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can add teams.'; end if;
 select theme into t from public.households where id=p_household for no key update;
 if (select count(*) from public.household_teams where household_id=p_household)>16 then raise exception 'A household can have up to 20 teams. Rename existing teams instead.'; end if;
 perform app_private.seed_theme_teams(p_household,t);
end $function$
;

CREATE OR REPLACE FUNCTION app_private.choose_team(p_household uuid, p_team uuid, p_user uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare target uuid:=coalesce(p_user,auth.uid()); legacy text;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household before choosing a team.'; end if;
 if target<>auth.uid() and not app_private.is_admin(p_household) then raise exception 'Only an admin can move other members between teams.'; end if;
 -- Serialize team membership changes with archiving/configuration.
 perform 1 from public.households where id=p_household for no key update;
 if p_team is not null then
  select replace(preset_key,'wizard:','') into legacy from public.household_teams where household_id=p_household and id=p_team and active;
  if not found then raise exception 'Choose an active team in this household.'; end if;
 end if;
 update public.household_members set team_id=p_team,wizard_house=case when legacy in ('gryffindor','slytherin','ravenclaw','hufflepuff') then legacy else null end where household_id=p_household and user_id=target;
 if not found then raise exception 'Member not found in this household.'; end if;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.invite_code(p_household uuid, p_rotate boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c uuid;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can manage invitations.'; end if;
 if p_rotate then update app_private.household_invites set code=gen_random_uuid() where household_id=p_household; end if;
 select code into c from app_private.household_invites where household_id=p_household;
 return c;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.save_tag(p_household uuid, p_tag uuid, p_chore text, p_location text, p_points integer, p_limit integer, p_eligible uuid[], p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t uuid;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can configure stickers.'; end if;
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
end $function$
;

CREATE OR REPLACE FUNCTION app_private.save_team(p_household uuid, p_team uuid, p_name text, p_color text, p_symbol text, p_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result uuid;
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can edit teams.'; end if;
 perform 1 from public.households where id=p_household for no key update;
 if p_team is null then
  if (select count(*) from public.household_teams where household_id=p_household)>=20 then raise exception 'A household can have up to 20 teams.'; end if;
  insert into public.household_teams(household_id,name,color,symbol,active) values(p_household,trim(p_name),p_color,p_symbol,p_active) returning id into result;
 else
  perform 1 from public.household_teams where household_id=p_household and id=p_team for update;
  if not found then raise exception 'Team not found in this household.'; end if;
  if not p_active and exists(select 1 from public.household_members where household_id=p_household and team_id=p_team) then raise exception 'Move this team’s members to another team before archiving it.'; end if;
  update public.household_teams set name=trim(p_name),color=p_color,symbol=p_symbol,active=p_active where household_id=p_household and id=p_team returning id into result;
 end if;
 return result;
 exception when unique_violation then raise exception 'A team with that name already exists in this household.';
end $function$
;

CREATE OR REPLACE FUNCTION app_private.set_household_theme(p_household uuid, p_theme text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can change its theme.'; end if;
 if p_theme is null or p_theme not in ('wizard','cats','clean','parents') then raise exception 'Choose a supported theme.'; end if;
 update public.households set theme=p_theme where id=p_household;
end $function$
;

CREATE OR REPLACE FUNCTION app_private.set_reward_scheme(p_household uuid, p_scheme text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only the household admin can change its reward system.'; end if;
 if p_scheme is null or p_scheme not in ('points','stars','adventure') then raise exception 'Choose a supported reward system.'; end if;
 update public.households set reward_scheme=p_scheme where id=p_household;
end $function$
;
commit;
