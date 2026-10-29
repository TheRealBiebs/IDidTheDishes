begin;
-- Inventory is intentionally accessed only through guarded definer functions.
create policy platform_admins_client_deny on app_private.platform_admins for all to anon,authenticated using(false) with check(false);
create policy sticker_batches_client_deny on app_private.sticker_batches for all to anon,authenticated using(false) with check(false);
create policy sticker_inventory_client_deny on app_private.sticker_inventory for all to anon,authenticated using(false) with check(false);
commit;
