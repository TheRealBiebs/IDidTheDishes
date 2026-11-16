begin;
-- Allow ON DELETE SET NULL to clear a retired chore's team reference, while
-- continuing to reject every other attempt to edit or revive deleted chores.
create or replace function app_private.prevent_deleted_chore_changes() returns trigger
language plpgsql set search_path='' as $$
begin
 if old.deleted_at is not null then
  if old.assigned_team_id is not null and new.assigned_team_id is null
    and (to_jsonb(new)-'assigned_team_id')=(to_jsonb(old)-'assigned_team_id') then return new;end if;
  raise exception 'This chore has been deleted.';
 end if;
 return new;
end $$;

create function app_private.delete_team(p_household uuid,p_team uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not app_private.is_admin(p_household) then raise exception 'Only household admins can delete teams.';end if;
 if p_team is null then raise exception 'Choose a team to delete.';end if;
 -- Match membership, configuration and weekly settlement lock order.
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can delete teams.';end if;
 perform 1 from public.household_teams where id=p_team and household_id=p_household for update;
 if not found then return;end if;
 -- Finalize any completed weeks before changing the current roster. Archived
 -- scores and weekly chore snapshots have no FK to the live team row.
 perform app_private.settle_weekly_results(p_household);
 update public.household_members set team_id=null,wizard_house=null where household_id=p_household and team_id=p_team;
 update public.chore_tags set assigned_team_id=null where household_id=p_household and assigned_team_id=p_team and deleted_at is null;
 -- Deleted chores are detached by their ON DELETE SET NULL FK as well.
 delete from public.household_teams where id=p_team and household_id=p_household;
end $$;
create function public.delete_team(p_household uuid,p_team uuid) returns void
language sql security invoker set search_path='' as $$select app_private.delete_team(p_household,p_team)$$;
revoke all on function app_private.delete_team(uuid,uuid),public.delete_team(uuid,uuid) from public,anon;
grant execute on function app_private.delete_team(uuid,uuid),public.delete_team(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
