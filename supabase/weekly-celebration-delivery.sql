begin;
create table app_private.weekly_delivery_claims(
 user_id uuid not null references auth.users on delete cascade,result_id uuid not null references public.household_week_results on delete cascade,
 client_id uuid not null,expires_at timestamptz not null,primary key(user_id,result_id)
);
create index weekly_delivery_result_idx on app_private.weekly_delivery_claims(result_id);
create index weekly_seen_result_idx on app_private.weekly_celebrations(result_id);
alter table app_private.weekly_delivery_claims enable row level security;
create policy weekly_delivery_private on app_private.weekly_delivery_claims to anon,authenticated using(false) with check(false);
revoke all on app_private.weekly_delivery_claims from public,anon,authenticated;
create function app_private.claim_weekly_result(p_result uuid,p_client uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare claimed boolean:=false;
begin
 if p_client is null or not exists(select 1 from public.household_week_results where id=p_result and app_private.is_member(household_id)) then raise exception 'Join this household to view weekly results.';end if;
 if exists(select 1 from app_private.weekly_celebrations where user_id=auth.uid() and result_id=p_result) then return false;end if;
 insert into app_private.weekly_delivery_claims(user_id,result_id,client_id,expires_at) values(auth.uid(),p_result,p_client,clock_timestamp()+interval '3 minutes')
 on conflict(user_id,result_id) do update set client_id=excluded.client_id,expires_at=excluded.expires_at
 where weekly_delivery_claims.client_id=p_client or weekly_delivery_claims.expires_at<clock_timestamp()
 returning true into claimed;
 return coalesce(claimed,false);
end $$;
create function public.claim_weekly_result(p_result uuid,p_client uuid) returns boolean language sql security invoker set search_path='' as $$select app_private.claim_weekly_result(p_result,p_client)$$;
revoke all on function app_private.claim_weekly_result(uuid,uuid),public.claim_weekly_result(uuid,uuid) from public,anon;
grant execute on function app_private.claim_weekly_result(uuid,uuid),public.claim_weekly_result(uuid,uuid) to authenticated;
commit;
