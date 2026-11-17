-- The existing daily_limit column stores the limit for the selected period.
create or replace function app_private.save_scheduled_chore(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 result:=app_private.save_tag_with_cooldown(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,true,p_cooldown_minutes);
 perform app_private.configure_chore_schedule(p_household,result,p_frequency,p_team);
 return result;
end $$;
create or replace function app_private.claim_scheduled_sticker(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 result:=app_private.claim_sticker_with_cooldown(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,true,p_cooldown_minutes);
 perform app_private.configure_chore_schedule(p_household,result,p_frequency,p_team);
 return result;
end $$;

-- Keep old clients compatible, but configured live chores can no longer be paused.
-- Soft-deleted chores remain inactive and retain their completion history.
create or replace function app_private.configured_chore_active() returns trigger
language plpgsql set search_path='' as $$begin
 new.active:=(new.deleted_at is null);
 return new;
end $$;
revoke all on function app_private.configured_chore_active() from public,anon,authenticated;
create trigger configured_chore_active before insert or update of active,deleted_at on public.chore_tags
for each row execute function app_private.configured_chore_active();
update public.chore_tags set active=true where deleted_at is null and not active;
