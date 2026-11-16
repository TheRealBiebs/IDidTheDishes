begin;
create table app_private.household_tutorials(
 household_id uuid not null references public.households on delete cascade,
 user_id uuid not null references auth.users on delete cascade,
 version integer not null default 1 check(version>0),
 status text not null check(status in ('active','completed','skipped')),
 step text not null check(step ~ '^[a-z0-9-]{1,60}$'),
 updated_at timestamptz not null default now(),
 primary key(household_id,user_id,version)
);
create index household_tutorial_user_idx on app_private.household_tutorials(user_id);
alter table app_private.household_tutorials enable row level security;
create policy household_tutorial_client_deny on app_private.household_tutorials for all to anon,authenticated using(false) with check(false);
revoke all on app_private.household_tutorials from public,anon,authenticated;
create function app_private.household_tutorial(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not app_private.is_member(p_household) then raise exception 'Join this household before using its tutorial.';end if;
 select jsonb_build_object('version',version,'status',status,'step',step) into result from app_private.household_tutorials where household_id=p_household and user_id=auth.uid() and version=1;
 return coalesce(result,jsonb_build_object('version',1,'status','not_started','step',null));
end $$;
create function public.household_tutorial(p_household uuid) returns jsonb
language sql security invoker set search_path='' as $$select app_private.household_tutorial(p_household)$$;
create function app_private.save_household_tutorial(p_household uuid,p_step text,p_status text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for key share;
 if auth.uid() is null or not app_private.is_member(p_household) then raise exception 'Join this household before using its tutorial.';end if;
 if p_status is null or p_status not in ('active','completed','skipped') or p_step is null or p_step !~ '^[a-z0-9-]{1,60}$' then raise exception 'Choose a valid tutorial step and status.';end if;
 insert into app_private.household_tutorials(household_id,user_id,version,status,step) values(p_household,auth.uid(),1,p_status,p_step)
 on conflict(household_id,user_id,version) do update set status=excluded.status,step=excluded.step,updated_at=now();
end $$;
create function public.save_household_tutorial(p_household uuid,p_step text,p_status text) returns void
language sql security invoker set search_path='' as $$select app_private.save_household_tutorial(p_household,p_step,p_status)$$;
revoke all on function app_private.household_tutorial(uuid),public.household_tutorial(uuid),app_private.save_household_tutorial(uuid,text,text),public.save_household_tutorial(uuid,text,text) from public,anon;
grant execute on function app_private.household_tutorial(uuid),public.household_tutorial(uuid),app_private.save_household_tutorial(uuid,text,text),public.save_household_tutorial(uuid,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
