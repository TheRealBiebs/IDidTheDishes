begin;
create function app_private.proof_is_unattached(p_path text) returns boolean
language sql stable security definer set search_path='' as $$select not exists(select 1 from public.chore_completions where proof_path=p_path)$$;
revoke all on function app_private.proof_is_unattached(text) from public,anon;
grant execute on function app_private.proof_is_unattached(text) to authenticated;
alter policy chore_proof_cleanup on storage.objects using(bucket_id='chore-proof' and owner_id=(select auth.uid())::text and app_private.proof_is_unattached(name));
alter policy chore_proof_pending_read on storage.objects using(bucket_id='chore-proof' and owner_id=(select auth.uid())::text and exists(select 1 from public.chore_completions c where c.id::text=split_part(name,'/',3) and c.user_id=(select auth.uid()) and app_private.is_member(c.household_id)));
commit;
