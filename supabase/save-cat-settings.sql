create function public.save_cat_settings(p_household uuid,p_target integer,p_days integer) returns void
language plpgsql security invoker set search_path='' as $$begin
 perform app_private.set_cat_daily_target(p_household,p_target);
 perform app_private.set_cat_required_days(p_household,p_days);
end $$;
revoke all on function public.save_cat_settings(uuid,integer,integer) from public,anon;
grant execute on function public.save_cat_settings(uuid,integer,integer) to authenticated;
