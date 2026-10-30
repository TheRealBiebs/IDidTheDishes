begin;
alter table public.chore_completions
 add column quality text check(quality in ('shabbily','good_enough','perfection')),
 add column starting_condition text check(starting_condition in ('maintenance','standard','disaster')),
 add column comment text check(length(comment)<=2000),
 add column proof_path text,
 add column details_updated_at timestamptz;
create unique index completion_proof_path_idx on public.chore_completions(proof_path) where proof_path is not null;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chore-proof','chore-proof',false,3145728,array['image/jpeg','image/png','image/webp']);
-- Paths are household/user/completion/random-file.jpg. Only the author can
-- upload for an existing completion; unfinished uploads are never public.
create policy chore_proof_upload on storage.objects for insert to authenticated with check(
 bucket_id='chore-proof' and exists(select 1 from public.chore_completions c where c.id::text=split_part(name,'/',3) and c.household_id::text=split_part(name,'/',1) and c.user_id=(select auth.uid()) and c.user_id::text=split_part(name,'/',2) and app_private.is_member(c.household_id))
);
create policy chore_proof_read on storage.objects for select to authenticated using(
 bucket_id='chore-proof' and exists(select 1 from public.chore_completions c where c.proof_path=name and app_private.is_member(c.household_id))
);
create policy chore_proof_cleanup on storage.objects for delete to authenticated using(
 bucket_id='chore-proof' and owner_id=(select auth.uid())::text and not exists(select 1 from public.chore_completions c where c.proof_path=name)
);
-- SELECT is also required to remove an author's unattached upload after a
-- failed save. This does not give other members access to unfinished uploads.
create policy chore_proof_pending_read on storage.objects for select to authenticated using(
 bucket_id='chore-proof' and owner_id=(select auth.uid())::text and split_part(name,'/',2)=(select auth.uid())::text
);

create function app_private.save_chore_details(p_completion uuid,p_quality text,p_condition text,p_comment text,p_photo_path text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;
begin
 select * into c from public.chore_completions where id=p_completion for update;
 if c.id is null or auth.uid() is null or c.user_id<>auth.uid() or not app_private.is_member(c.household_id) then raise exception 'Only the member who logged this chore can add its details.';end if;
 if p_quality is not null and p_quality not in ('shabbily','good_enough','perfection') then raise exception 'Choose a supported quality rating.';end if;
 if p_condition is not null and p_condition not in ('maintenance','standard','disaster') then raise exception 'Choose a supported starting condition.';end if;
 if length(p_comment)>2000 then raise exception 'Comments can contain up to 2000 characters.';end if;
 if p_photo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='chore-proof' and o.name=p_photo_path and o.owner_id=auth.uid()::text and split_part(o.name,'/',1)=c.household_id::text and split_part(o.name,'/',2)=auth.uid()::text and split_part(o.name,'/',3)=c.id::text) then raise exception 'Upload photo proof for this completion first.';end if;
 update public.chore_completions set quality=p_quality,starting_condition=p_condition,comment=nullif(trim(p_comment),''),proof_path=p_photo_path,details_updated_at=now() where id=c.id returning * into c;
 return to_jsonb(c);
end $$;
create function public.save_chore_details(p_completion uuid,p_quality text,p_condition text,p_comment text,p_photo_path text) returns jsonb language sql security invoker set search_path='' as $$select app_private.save_chore_details(p_completion,p_quality,p_condition,p_comment,p_photo_path)$$;
create function app_private.complete_chore_with_details(p_token uuid,p_request uuid,p_quality text,p_condition text,p_comment text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result:=app_private.complete_chore(p_token,p_request);
 -- All values are validated inside the same completion transaction.
 return app_private.save_chore_details((result->>'id')::uuid,p_quality,p_condition,p_comment,result->>'proof_path');
end $$;
create function public.complete_chore_with_details(p_token uuid,p_request uuid,p_quality text,p_condition text,p_comment text) returns jsonb language sql security invoker set search_path='' as $$select app_private.complete_chore_with_details(p_token,p_request,p_quality,p_condition,p_comment)$$;
revoke all on function app_private.save_chore_details(uuid,text,text,text,text),public.save_chore_details(uuid,text,text,text,text),app_private.complete_chore_with_details(uuid,uuid,text,text,text),public.complete_chore_with_details(uuid,uuid,text,text,text) from public,anon;
grant execute on function app_private.save_chore_details(uuid,text,text,text,text),public.save_chore_details(uuid,text,text,text,text),app_private.complete_chore_with_details(uuid,uuid,text,text,text),public.complete_chore_with_details(uuid,uuid,text,text,text) to authenticated;

create or replace function app_private.inspect_sticker(p_token uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s app_private.sticker_inventory;t public.chore_tags;member boolean;look jsonb;team jsonb;
begin
 select * into s from app_private.sticker_inventory where token=p_token;
 if not found then return jsonb_build_object('status','invalid');end if;
 if s.chore_tag_id is null then return jsonb_build_object('status',case when s.written_at is null then 'preparing' else 'available' end);end if;
 select * into t from public.chore_tags where id=s.chore_tag_id;
 select jsonb_build_object('theme',theme,'reward_scheme',reward_scheme) into look from public.households where id=s.household_id;
 member:=app_private.is_member(s.household_id);
 if member then
  select jsonb_build_object('name',x.name,'color',x.color,'symbol',x.symbol) into team from public.household_members m join public.household_teams x on x.id=m.team_id and x.household_id=m.household_id where m.household_id=s.household_id and m.user_id=auth.uid();
 end if;
 return jsonb_build_object('status','assigned','chore',t.chore,'member',member,'appearance',look)
  ||case when member then jsonb_build_object('household_id',s.household_id,'admin',app_private.is_admin(s.household_id),'tag',to_jsonb(t),'team',team) else '{}'::jsonb end;
end $$;
commit;
