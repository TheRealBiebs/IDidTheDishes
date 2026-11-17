-- Scanning chores is enough to participate; opening the overview is optional.
create index if not exists completions_person_day_idx on public.chore_completions(household_id,user_id,chore_date);
create or replace function app_private.cat_from_completion() returns trigger
language plpgsql security definer set search_path='' as $$begin
 perform app_private.ensure_cat_week(new.household_id,new.user_id);
 return null;
end $$;
revoke all on function app_private.cat_from_completion() from public,anon,authenticated;
create trigger cat_from_completion after insert on public.chore_completions for each row execute function app_private.cat_from_completion();
