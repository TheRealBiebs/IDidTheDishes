create or replace function app_private.delete_chore(p_household uuid,p_chore uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can delete chores.';end if;
 -- Same inventory-first lock order as claim/scan. Include unassigned rows so
 -- a concurrent claim cannot bind this chore while it is being retired.
 lock table app_private.sticker_inventory in exclusive mode;
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can delete chores.';end if;
 perform 1 from public.chore_tags where id=p_chore and household_id=p_household for update;
 if not found then raise exception 'Chore not found in this household.';end if;
 if exists(select 1 from public.chore_tags where id=p_chore and deleted_at is not null) then return;end if;
 update public.sticker_release_requests set status='released',reviewed_at=now() where status='pending' and token in(select token from app_private.sticker_inventory where chore_tag_id=p_chore and household_id=p_household);
 update app_private.sticker_inventory set chore_tag_id=null,household_id=null,generation=generation+1 where chore_tag_id=p_chore and household_id=p_household;
 update public.chore_tags set active=false,deleted_at=now(),token=gen_random_uuid() where id=p_chore;
end $$;
