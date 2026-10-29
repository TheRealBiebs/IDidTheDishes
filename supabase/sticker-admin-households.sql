begin;
create function app_private.admin_households() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at),'[]') into result from public.households h
 where exists(select 1 from public.household_members m where m.household_id=h.id and m.user_id=auth.uid() and m.role='owner');
 return result;
end $$;
create function public.admin_households() returns jsonb language sql security invoker set search_path='' as $$select app_private.admin_households()$$;
revoke all on function app_private.admin_households(),public.admin_households() from public,anon;
grant execute on function app_private.admin_households(),public.admin_households() to authenticated;
commit;
