create or replace function app_private.household_dashboard(p_household uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d date; w date; result jsonb;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.'; end if;
 select (now() at time zone timezone)::date into d from public.households where id=p_household;
 w:=date_trunc('week',d::timestamp)::date;
 select jsonb_build_object(
  'today',d,'week_start',w,
  'today_count',(select count(*) from public.chore_completions where household_id=p_household and chore_date=d),
  'today_points',(select coalesce(sum(points),0) from public.chore_completions where household_id=p_household and chore_date=d),
  'week_count',(select count(*) from public.chore_completions where household_id=p_household and chore_date>=w),
  'week_points',(select coalesce(sum(points),0) from public.chore_completions where household_id=p_household and chore_date>=w),
  'scores',(select coalesce(jsonb_agg(row_to_json(s)),'[]') from (select m.user_id,m.display_name,m.role,count(c.id) as chores,coalesce(sum(c.points),0) as points from public.household_members m left join public.chore_completions c on c.household_id=m.household_id and c.user_id=m.user_id and c.chore_date>=w where m.household_id=p_household group by m.user_id,m.display_name,m.role,m.joined_at order by sum(c.points) desc nulls last,m.joined_at) s),
  'tag_counts',(select coalesce(jsonb_object_agg(tag_id,n),'{}') from (select tag_id,count(*) n from public.chore_completions where household_id=p_household and chore_date=d group by tag_id) counts),
  'activity',(select coalesce(jsonb_agg(row_to_json(a)),'[]') from (select c.*,m.display_name from public.chore_completions c join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household order by completed_at desc limit 50) a)
 ) into result;
 return result;
end $$;
revoke all on function app_private.household_dashboard(uuid) from public,anon;
grant execute on function app_private.household_dashboard(uuid) to authenticated;
create or replace function public.household_dashboard(p_household uuid) returns jsonb language sql security invoker set search_path='' as $$select app_private.household_dashboard(p_household)$$;
revoke all on function public.household_dashboard(uuid) from public,anon;
grant execute on function public.household_dashboard(uuid) to authenticated;
