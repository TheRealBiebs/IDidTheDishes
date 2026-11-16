-- Valid admin-issued invitations grant membership directly, without approval.
create or replace function app_private.join_household(p_code uuid,p_display_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 select household_id into h from app_private.household_invites where code=p_code;
 if h is null then raise exception 'This invitation is invalid or has been replaced.'; end if;
 -- Share the admin/invitation lock: rotation and concurrent joins serialize.
 perform 1 from public.households where id=h for no key update;
 if not exists(select 1 from app_private.household_invites where household_id=h and code=p_code) then raise exception 'This invitation has been replaced.'; end if;
 if app_private.is_member(h) then return h; end if;
 if p_display_name is null or length(trim(p_display_name)) not between 1 and 60 then raise exception 'Choose a name between 1 and 60 characters.'; end if;
 if (select count(*) from public.household_members where household_id=h)>=50 then raise exception 'This household has reached 50 members.'; end if;
 insert into public.household_members(household_id,user_id,display_name,role)
 values(h,auth.uid(),trim(p_display_name),'member') on conflict do nothing;
 update public.household_join_requests set status='approved',decided_at=now(),decided_by=null
 where household_id=h and user_id=auth.uid() and status='pending';
 return h;
end $$;
revoke all on function app_private.join_household(uuid,text),public.join_household(uuid,text) from public,anon;
grant execute on function app_private.join_household(uuid,text),public.join_household(uuid,text) to authenticated;

-- Honor existing pending invitations too; never grant admin rights or exceed capacity.
do $$declare h uuid; r record; begin
 for h in select distinct household_id from public.household_join_requests where status='pending' order by household_id loop
  perform 1 from public.households where id=h for no key update;
  for r in select * from public.household_join_requests where household_id=h and status='pending' order by created_at,id for update loop
   if not exists(select 1 from public.household_members where household_id=h and user_id=r.user_id) then
    if (select count(*) from public.household_members where household_id=h)>=50 then continue; end if;
    insert into public.household_members(household_id,user_id,display_name,role) values(h,r.user_id,r.display_name,'member') on conflict do nothing;
   end if;
   update public.household_join_requests set status='approved',decided_at=now(),decided_by=null where id=r.id;
  end loop;
 end loop;
end $$;
