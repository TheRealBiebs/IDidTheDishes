begin;
-- Keep the older creation API working for installed clients. New clients use
-- one transaction for theme, rewards and starter chores.
create function app_private.create_household_setup(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[],p_reward_scheme text) returns uuid
language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first.';end if;
 if p_reward_scheme is null or p_reward_scheme not in ('points','stars','adventure') then raise exception 'Choose a supported reward system.';end if;
 h:=app_private.create_household_with_chores(p_name,p_display_name,p_timezone,p_theme,p_starters);
 update public.households set reward_scheme=p_reward_scheme where id=h;
 return h;
end $$;
create function public.create_household_setup(p_name text,p_display_name text,p_timezone text,p_theme text,p_starters text[],p_reward_scheme text) returns uuid
language sql security invoker set search_path='' as $$select app_private.create_household_setup(p_name,p_display_name,p_timezone,p_theme,p_starters,p_reward_scheme)$$;

create function app_private.delete_household(p_household uuid,p_confirmation text) returns void
language plpgsql security definer set search_path='' as $$
declare household_name text;
begin
 if auth.uid() is null or not app_private.is_admin(p_household) then raise exception 'Only a household admin can delete this household.';end if;
 -- Deletion is rare: briefly serialize inventory operations before locking the
 -- household, matching the inventory-first order of scan/claim/release RPCs.
 -- This also prevents a new claim from appearing during sticker detachment.
 lock table app_private.sticker_inventory in exclusive mode;
 select name into household_name from public.households where id=p_household for update;
 if not found or not app_private.is_admin(p_household) then raise exception 'Only a household admin can delete this household.';end if;
 if p_confirmation is distinct from household_name then raise exception 'Type the household name exactly to confirm deletion.';end if;
 update app_private.sticker_inventory set chore_tag_id=null,household_id=null,generation=generation+1 where household_id=p_household;
 -- Explicit order handles the non-cascading completion/tag and member/team FKs.
 delete from public.chore_completions where household_id=p_household;
 delete from public.household_members where household_id=p_household;
 delete from public.households where id=p_household;
 -- Household FKs cascade chores, teams, invites, requests and notifications;
 -- notification FKs cascade push jobs. Accounts and push subscriptions remain.
end $$;
create function public.delete_household(p_household uuid,p_confirmation text) returns void
language sql security invoker set search_path='' as $$select app_private.delete_household(p_household,p_confirmation)$$;
revoke all on function app_private.create_household_setup(text,text,text,text,text[],text),public.create_household_setup(text,text,text,text,text[],text),app_private.delete_household(uuid,text),public.delete_household(uuid,text) from public,anon;
grant execute on function app_private.create_household_setup(text,text,text,text,text[],text),public.create_household_setup(text,text,text,text,text[],text),app_private.delete_household(uuid,text),public.delete_household(uuid,text) to authenticated;
commit;
