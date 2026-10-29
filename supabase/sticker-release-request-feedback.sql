begin;
create or replace function app_private.request_sticker_release(p_token uuid,p_household uuid) returns void language plpgsql security definer set search_path='' as $$
declare s app_private.sticker_inventory;title text;begin
 if not app_private.is_member(p_household) then raise exception 'Choose one of your households.';end if;
 select * into s from app_private.sticker_inventory where token=p_token for update;
 if not found or s.household_id is null then raise exception 'This sticker is not currently claimed.';end if;
 if s.household_id=p_household then raise exception 'This sticker already belongs to your household.';end if;
 if exists(select 1 from public.sticker_release_requests where token=p_token and generation=s.generation and requester_household_id=p_household and status='declined') then raise exception 'Your household’s release request was declined. Contact the current household admin.';end if;
 if exists(select 1 from public.sticker_release_requests where token=p_token and generation=s.generation and requester_household_id=p_household) then return;end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,32));
 if (select count(*) from public.sticker_release_requests where requester_id=auth.uid() and status='pending')>=10 then raise exception 'You can have up to 10 pending release requests.';end if;
 select chore into title from public.chore_tags where id=s.chore_tag_id;
 insert into public.sticker_release_requests(token,generation,owner_household_id,requester_household_id,requester_id,chore) values(p_token,s.generation,s.household_id,p_household,auth.uid(),title);
end $$;
commit;
