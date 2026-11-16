begin;
create table app_private.app_feedback(
 id uuid primary key default gen_random_uuid(),
 user_id uuid references auth.users on delete set null,
 request_id uuid not null,
 author_name text not null,
 author_email text,
 household_id uuid references public.households on delete set null,
 household_name text,
 category text not null check(category in ('general','idea','bug')),
 message text not null check(length(btrim(message)) between 1 and 4000 and message ~ '[^[:space:]]'),
 platform text not null check(platform in ('web','pwa','android','ios')),
 screen text not null default '' check(length(screen)<=80),
 status text not null default 'new' check(status in ('new','reviewed')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(user_id,request_id)
);
create index app_feedback_user_created on app_private.app_feedback(user_id,created_at desc);
create index app_feedback_created on app_private.app_feedback(created_at desc,id desc);
create index app_feedback_status_created on app_private.app_feedback(status,created_at desc,id desc);
create index app_feedback_household on app_private.app_feedback(household_id) where household_id is not null;
alter table app_private.app_feedback enable row level security;
create policy feedback_client_deny on app_private.app_feedback for all to anon,authenticated using(false) with check(false);
revoke all on app_private.app_feedback from public,anon,authenticated;

create function app_private.submit_app_feedback(p_request uuid,p_category text,p_message text,p_household uuid default null,p_platform text default 'web',p_screen text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare existing app_private.app_feedback;name text;email text;house_name text;result uuid;
begin
 if auth.uid() is null then raise exception 'Sign in to send feedback.';end if;
 if p_request is null then raise exception 'A feedback request ID is required.';end if;
 if p_category is null or p_category not in ('general','idea','bug') then raise exception 'Choose feedback, idea, or bug report.';end if;
 if p_message is null or p_message !~ '[^[:space:]]' or length(btrim(p_message)) not between 1 and 4000 then raise exception 'Write a message between 1 and 4000 characters.';end if;
 if p_platform is null or p_platform not in ('web','pwa','android','ios') or p_screen is null or length(p_screen)>80 then raise exception 'Invalid feedback context.';end if;
 if p_household is not null and not app_private.is_member(p_household) then raise exception 'Only include a household you belong to.';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('app-feedback:'||auth.uid()::text,0));
 select * into existing from app_private.app_feedback where user_id=auth.uid() and request_id=p_request;
 if existing.id is not null then
  if existing.category is distinct from p_category or existing.message is distinct from btrim(p_message) or existing.household_id is distinct from p_household or existing.platform is distinct from p_platform or existing.screen is distinct from p_screen then raise exception 'This feedback request was already submitted with different contents.';end if;
  return existing.id;
 end if;
 if (select count(*) from app_private.app_feedback where user_id=auth.uid() and created_at>now()-interval '1 hour')>=10 then raise exception 'You have sent several reports recently. Please try again in an hour.';end if;
 select left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),nullif(btrim(raw_user_meta_data->>'full_name'),''),nullif(btrim(raw_user_meta_data->>'name'),''),'Chip In member'),80),u.email into name,email from auth.users u where u.id=auth.uid();
 if not found then raise exception 'Sign in to send feedback.';end if;
 if p_household is not null then select h.name into house_name from public.households h where id=p_household;end if;
 insert into app_private.app_feedback(user_id,request_id,author_name,author_email,household_id,household_name,category,message,platform,screen)
 values(auth.uid(),p_request,name,email,p_household,house_name,p_category,btrim(p_message),p_platform,p_screen) returning id into result;
 return result;
end $$;
create function public.submit_app_feedback(p_request uuid,p_category text,p_message text,p_household uuid default null,p_platform text default 'web',p_screen text default '') returns uuid
language sql security invoker set search_path='' as $$select app_private.submit_app_feedback(p_request,p_category,p_message,p_household,p_platform,p_screen)$$;

create function app_private.platform_feedback(p_status text default null,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;total integer;new_count integer;
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 if p_status is not null and p_status not in ('new','reviewed') then raise exception 'Choose a valid feedback status.';end if;
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid page.';end if;
 select count(*) into total from app_private.app_feedback where p_status is null or status=p_status;
 select count(*) into new_count from app_private.app_feedback where status='new';
 select coalesce(jsonb_agg(to_jsonb(f)-'request_id'-'user_id' order by created_at desc,id desc),'[]'::jsonb) into rows
 from(select * from app_private.app_feedback where p_status is null or status=p_status order by created_at desc,id desc offset p_offset limit 25) f;
 return jsonb_build_object('feedback',rows,'total',total,'new_count',new_count);
end $$;
create function public.platform_feedback(p_status text default null,p_offset integer default 0) returns jsonb
language sql security invoker set search_path='' as $$select app_private.platform_feedback(p_status,p_offset)$$;

create function app_private.review_app_feedback(p_feedback uuid,p_reviewed boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_platform_admin() then raise exception 'Platform admin access required.';end if;
 if p_reviewed is null then raise exception 'Choose new or reviewed.';end if;
 update app_private.app_feedback set status=case when p_reviewed then 'reviewed' else 'new' end,reviewed_at=case when p_reviewed then now() else null end where id=p_feedback;
 if not found then raise exception 'Feedback not found.';end if;
end $$;
create function public.review_app_feedback(p_feedback uuid,p_reviewed boolean) returns void
language sql security invoker set search_path='' as $$select app_private.review_app_feedback(p_feedback,p_reviewed)$$;
revoke all on function app_private.submit_app_feedback(uuid,text,text,uuid,text,text),public.submit_app_feedback(uuid,text,text,uuid,text,text),app_private.platform_feedback(text,integer),public.platform_feedback(text,integer),app_private.review_app_feedback(uuid,boolean),public.review_app_feedback(uuid,boolean) from public,anon;
grant execute on function app_private.submit_app_feedback(uuid,text,text,uuid,text,text),public.submit_app_feedback(uuid,text,text,uuid,text,text),app_private.platform_feedback(text,integer),public.platform_feedback(text,integer),app_private.review_app_feedback(uuid,boolean),public.review_app_feedback(uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
