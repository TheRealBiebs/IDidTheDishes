begin;
create table public.chore_likes(
 completion_id uuid not null references public.chore_completions on delete cascade,
 household_id uuid not null references public.households on delete cascade,
 user_id uuid not null references auth.users on delete cascade,liked boolean not null,notified boolean not null default false,
 primary key(completion_id,user_id)
);
create index chore_likes_household_idx on public.chore_likes(household_id);
create index chore_likes_user_idx on public.chore_likes(user_id);
create table public.chore_comments(
 id uuid primary key default gen_random_uuid(),completion_id uuid not null references public.chore_completions on delete cascade,
 household_id uuid not null references public.households on delete cascade,user_id uuid not null references auth.users on delete cascade,
 body text not null check(length(body) between 1 and 1000 and body~'[^[:space:]]'),request_id uuid not null,
 created_at timestamptz not null default now(),unique(user_id,request_id)
);
create index chore_comments_thread_idx on public.chore_comments(completion_id,created_at desc,id desc);
create index chore_comments_household_idx on public.chore_comments(household_id);
alter table public.chore_likes enable row level security;
alter table public.chore_comments enable row level security;
create policy chore_likes_read on public.chore_likes for select to authenticated using(app_private.is_member(household_id));
create policy chore_comments_read on public.chore_comments for select to authenticated using(app_private.is_member(household_id));
revoke all on public.chore_likes,public.chore_comments from public,anon,authenticated;
grant select on public.chore_likes,public.chore_comments to authenticated;

create function app_private.chore_social(p_completion uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c public.chore_completions;result jsonb;
begin
 select * into c from public.chore_completions where id=p_completion;
 if c.id is null or not app_private.is_member(c.household_id) then raise exception 'This chore is not available to your household.';end if;
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid comment page.';end if;
 select jsonb_build_object('completion',to_jsonb(c),'likes_count',(select count(*) from public.chore_likes where completion_id=c.id and liked),
  'liked_by_me',exists(select 1 from public.chore_likes where completion_id=c.id and user_id=auth.uid() and liked),
  'liked_by',(select coalesce(jsonb_agg(name order by name),'[]') from (select coalesce(m.display_name,'Former household member') as name from public.chore_likes l left join public.household_members m on m.household_id=l.household_id and m.user_id=l.user_id where l.completion_id=c.id and l.liked order by name,l.user_id limit 25) names),
  'comments',(select coalesce(jsonb_agg(to_jsonb(rows) order by rows.created_at desc,rows.id desc),'[]') from (select s.id,s.body,s.created_at,coalesce(m.display_name,'Former household member') as display_name from public.chore_comments s left join public.household_members m on m.household_id=s.household_id and m.user_id=s.user_id where s.completion_id=c.id order by s.created_at desc,s.id desc offset p_offset limit 50) rows),
  'total_comments',(select count(*) from public.chore_comments where completion_id=c.id)) into result;
 return result;
end $$;
create function public.chore_social(p_completion uuid,p_offset integer default 0) returns jsonb language sql security invoker set search_path='' as $$select app_private.chore_social(p_completion,p_offset)$$;

create function app_private.set_chore_like(p_completion uuid,p_liked boolean) returns void
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;sent boolean;n text;
begin
 select * into c from public.chore_completions where id=p_completion for update;
 if c.id is null or not app_private.is_member(c.household_id) then raise exception 'This chore is not available to your household.';end if;
 if p_liked is null then raise exception 'Choose like or unlike.';end if;
 select notified into sent from public.chore_likes where completion_id=c.id and user_id=auth.uid();
 insert into public.chore_likes(completion_id,household_id,user_id,liked,notified) values(c.id,c.household_id,auth.uid(),p_liked,p_liked)
 on conflict(completion_id,user_id) do update set liked=excluded.liked,notified=public.chore_likes.notified or excluded.notified;
 if p_liked and not coalesce(sent,false) and c.user_id<>auth.uid() and exists(select 1 from public.household_members where household_id=c.household_id and user_id=c.user_id) then
  select display_name into n from public.household_members where household_id=c.household_id and user_id=auth.uid();
  insert into public.notifications(user_id,household_id,completion_id,message) values(c.user_id,c.household_id,c.id,n||' liked your chore: '||c.chore||'.');
 end if;
end $$;
create function public.set_chore_like(p_completion uuid,p_liked boolean) returns void language sql security invoker set search_path='' as $$select app_private.set_chore_like(p_completion,p_liked)$$;

create function app_private.add_chore_comment(p_completion uuid,p_body text,p_request uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;existing public.chore_comments;result uuid;clean text:=btrim(p_body);n text;
begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 if p_request is null then raise exception 'A comment submission ID is required.';end if;
 if clean is null or length(clean) not between 1 and 1000 or clean!~'[^[:space:]]' then raise exception 'Write a comment of 1 to 1000 characters.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,63));
 select * into c from public.chore_completions where id=p_completion for update;
 if c.id is null or not app_private.is_member(c.household_id) then raise exception 'This chore is not available to your household.';end if;
 select * into existing from public.chore_comments where user_id=auth.uid() and request_id=p_request;
 if existing.id is not null then
  if existing.completion_id<>c.id or existing.body<>clean then raise exception 'This submission ID was already used for another comment.';end if;
  return existing.id;
 end if;
 insert into public.chore_comments(completion_id,household_id,user_id,body,request_id) values(c.id,c.household_id,auth.uid(),clean,p_request) returning id into result;
 if c.user_id<>auth.uid() and exists(select 1 from public.household_members where household_id=c.household_id and user_id=c.user_id) then
  select display_name into n from public.household_members where household_id=c.household_id and user_id=auth.uid();
  insert into public.notifications(user_id,household_id,completion_id,message) values(c.user_id,c.household_id,c.id,n||' commented on '||c.chore||': '||left(clean,240)||case when length(clean)>240 then '...' else '' end);
 end if;
 return result;
end $$;
create function public.add_chore_comment(p_completion uuid,p_body text,p_request uuid) returns uuid language sql security invoker set search_path='' as $$select app_private.add_chore_comment(p_completion,p_body,p_request)$$;

revoke all on function app_private.chore_social(uuid,integer),public.chore_social(uuid,integer),app_private.set_chore_like(uuid,boolean),public.set_chore_like(uuid,boolean),app_private.add_chore_comment(uuid,text,uuid),public.add_chore_comment(uuid,text,uuid) from public,anon;
grant execute on function app_private.chore_social(uuid,integer),public.chore_social(uuid,integer),app_private.set_chore_like(uuid,boolean),public.set_chore_like(uuid,boolean),app_private.add_chore_comment(uuid,text,uuid),public.add_chore_comment(uuid,text,uuid) to authenticated;
alter publication supabase_realtime add table public.chore_likes,public.chore_comments;

create or replace function app_private.claim_push_jobs() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Service access required.';end if;
 with candidates as(select id from app_private.push_jobs where status in('pending','processing') and next_attempt<=now() and attempts<5 order by next_attempt for update skip locked limit 20),
 claimed as(update app_private.push_jobs j set status='processing',attempts=attempts+1,next_attempt=now()+interval '2 minutes' from candidates c where j.id=c.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',j.id,'subscription_id',s.id,'subscription',s.subscription,'message',n.message,'household_id',n.household_id,'notification_id',n.id,'completion_id',n.completion_id)),'[]') into result from claimed j join public.push_subscriptions s on s.id=j.subscription_id join public.notifications n on n.id=j.notification_id;
 return result;
end $$;
notify pgrst, 'reload schema';
commit;
