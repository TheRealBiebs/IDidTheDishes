begin;
create table app_private.community_households(
 household_id uuid primary key references public.households on delete cascade,
 enabled boolean not null default false,approved_by uuid references auth.users on delete set null,updated_at timestamptz not null default now()
);
create table app_private.community_consents(
 household_id uuid not null references public.households on delete cascade,user_id uuid not null references auth.users on delete cascade,
 accepted_at timestamptz not null default now(),primary key(household_id,user_id)
);
create index community_consent_user_idx on app_private.community_consents(user_id);
create table app_private.community_follows(
 user_id uuid not null references auth.users on delete cascade,target_household uuid not null references public.households on delete cascade,
 created_at timestamptz not null default now(),primary key(user_id,target_household)
);
create index community_follow_target_idx on app_private.community_follows(target_household);
create index community_approved_by_idx on app_private.community_households(approved_by);
alter table app_private.community_households enable row level security;
alter table app_private.community_consents enable row level security;
alter table app_private.community_follows enable row level security;
create policy community_enrollment_private on app_private.community_households to anon,authenticated using(false) with check(false);
create policy community_consent_private on app_private.community_consents to anon,authenticated using(false) with check(false);
create policy community_follow_private on app_private.community_follows to anon,authenticated using(false) with check(false);
revoke all on app_private.community_households,app_private.community_consents,app_private.community_follows from public,anon,authenticated;

create function app_private.community_access(p_household uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if not exists(select 1 from app_private.community_households where household_id=p_household and enabled) then raise exception 'A household admin must join the community leaderboard first.';end if;
 if not exists(select 1 from app_private.community_consents where household_id=p_household and user_id=auth.uid()) then raise exception 'Please accept the leaderboard sharing disclosure first.';end if;
end $$;
revoke all on function app_private.community_access(uuid) from public,anon,authenticated;

create function app_private.community_status(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 return jsonb_build_object('joined',exists(select 1 from app_private.community_households where household_id=p_household and enabled),'accepted',exists(select 1 from app_private.community_consents where household_id=p_household and user_id=auth.uid()));
end $$;
create function public.community_status(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.community_status(p_household)$$;

create function app_private.set_community_sharing(p_household uuid,p_enabled boolean,p_accept boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only a household admin can join or leave the community leaderboard.';end if;
 if p_enabled is null then raise exception 'Choose whether to share household scores.';end if;
 if p_enabled and p_accept is distinct from true then raise exception 'Accept the sharing disclosure before joining.';end if;
 insert into app_private.community_households(household_id,enabled,approved_by) values(p_household,p_enabled,auth.uid())
 on conflict(household_id) do update set enabled=excluded.enabled,approved_by=excluded.approved_by,updated_at=now();
 if p_enabled then
  insert into app_private.community_consents(household_id,user_id) values(p_household,auth.uid()) on conflict do nothing;
 else
  delete from app_private.community_consents where household_id=p_household;
 end if;
end $$;
create function public.set_community_sharing(p_household uuid,p_enabled boolean,p_accept boolean) returns void language sql security invoker set search_path='' as $$select app_private.set_community_sharing(p_household,p_enabled,p_accept)$$;

create function app_private.accept_community(p_household uuid,p_accept boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if p_accept is distinct from true then raise exception 'Accept the sharing disclosure before viewing.';end if;
 if not exists(select 1 from app_private.community_households where household_id=p_household and enabled) then raise exception 'A household admin must join the community leaderboard first.';end if;
 insert into app_private.community_consents(household_id,user_id) values(p_household,auth.uid()) on conflict do nothing;
end $$;
create function public.accept_community(p_household uuid,p_accept boolean) returns void language sql security invoker set search_path='' as $$select app_private.accept_community(p_household,p_accept)$$;

create function app_private.community_follow(p_household uuid,p_target uuid,p_follow boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform app_private.community_access(p_household);
 if p_follow is null then raise exception 'Choose follow or unfollow.';end if;
 if p_follow then
  if p_target=p_household then raise exception 'Your household is already included.';end if;
  if not exists(select 1 from app_private.community_households where household_id=p_target and enabled) then raise exception 'That household is not sharing community scores.';end if;
  insert into app_private.community_follows(user_id,target_household) values(auth.uid(),p_target) on conflict do nothing;
 else
  delete from app_private.community_follows where user_id=auth.uid() and target_household=p_target;
 end if;
end $$;
create function public.community_follow(p_household uuid,p_target uuid,p_follow boolean) returns void language sql security invoker set search_path='' as $$select app_private.community_follow(p_household,p_target,p_follow)$$;

create function app_private.community_board(p_household uuid,p_followed_only boolean default false,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform app_private.community_access(p_household);
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid page.';end if;
 with enrolled as (
  select h.id,h.name,date_trunc('week',now() at time zone h.timezone)::date as week_start,
   (now() at time zone h.timezone)::date as today,
   exists(select 1 from app_private.community_follows f where f.user_id=auth.uid() and f.target_household=h.id) as following
  from public.households h join app_private.community_households e on e.household_id=h.id and e.enabled
 ), team_points as (
  select e.id as household_id,t.id,t.name,coalesce(sum(c.points),0)::bigint as points
  from enrolled e join public.household_teams t on t.household_id=e.id and t.active
  left join public.household_members m on m.household_id=e.id and m.team_id=t.id
  left join public.chore_completions c on c.household_id=e.id and c.user_id=m.user_id and c.chore_date>=e.week_start and c.chore_date<=e.today
  group by e.id,t.id,t.name
 ), scored as (
  select e.id,e.name,e.following,coalesce(sum(t.points),0)::bigint as points,
   coalesce(jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'points',t.points) order by t.points desc,t.name,t.id) filter(where t.id is not null),'[]') as teams
  from enrolled e left join team_points t on t.household_id=e.id group by e.id,e.name,e.following
 ), ranked as (
  select *,dense_rank() over(order by points desc) as rank from scored
 ), filtered as (
  select * from ranked where not coalesce(p_followed_only,false) or following or id=p_household
 ), page as (
  select * from filtered order by points desc,lower(name),id offset p_offset limit 25
 )
 select jsonb_build_object('households',(select coalesce(jsonb_agg(to_jsonb(p) order by p.points desc,lower(p.name),p.id),'[]') from page p),'total',(select count(*) from filtered),'following_count',(select count(*) from enrolled where following),'week_rule','Household-local Monday resets') into result;
 return result;
end $$;
create function public.community_board(p_household uuid,p_followed_only boolean default false,p_offset integer default 0) returns jsonb language sql security invoker set search_path='' as $$select app_private.community_board(p_household,p_followed_only,p_offset)$$;

revoke all on function app_private.community_status(uuid),public.community_status(uuid),app_private.set_community_sharing(uuid,boolean,boolean),public.set_community_sharing(uuid,boolean,boolean),app_private.accept_community(uuid,boolean),public.accept_community(uuid,boolean),app_private.community_follow(uuid,uuid,boolean),public.community_follow(uuid,uuid,boolean),app_private.community_board(uuid,boolean,integer),public.community_board(uuid,boolean,integer) from public,anon;
grant execute on function app_private.community_status(uuid),public.community_status(uuid),app_private.set_community_sharing(uuid,boolean,boolean),public.set_community_sharing(uuid,boolean,boolean),app_private.accept_community(uuid,boolean),public.accept_community(uuid,boolean),app_private.community_follow(uuid,uuid,boolean),public.community_follow(uuid,uuid,boolean),app_private.community_board(uuid,boolean,integer),public.community_board(uuid,boolean,integer) to authenticated;
notify pgrst, 'reload schema';
commit;
