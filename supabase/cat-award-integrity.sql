create policy cat_weeks_private on app_private.cat_weeks to anon,authenticated using(false) with check(false);
create policy cat_care_private on app_private.cat_care to anon,authenticated using(false) with check(false);

-- Closed cat weeks award every seven-day qualifier. Later comments/trait edits
-- must not turn that archived result into a highest-points competition.
create or replace function app_private.rank_week_teams(p_scores jsonb,p_scheme text) returns jsonb
language sql immutable set search_path='' as $$
 select case when p_scheme='cats' and exists(select 1 from jsonb_array_elements(p_scores) t where t ? 'cat_type') then p_scores else (
  with scored as(select value||jsonb_build_object('score',case when p_scheme in('stars','adventure') then coalesce((value->>'chores')::bigint,0) else coalesce((value->>'points')::bigint,0) end) as item from jsonb_array_elements(p_scores)),
  ranked as(select item,(item->>'score')::bigint as score,max((item->>'score')::bigint) over() as high from scored)
  select coalesce(jsonb_agg(item||jsonb_build_object('winner',score>0 and score=high,'weekly_win_points',case when score>0 and score=high then 1 else 0 end) order by score desc,item->>'name'),'[]'::jsonb) from ranked
 ) end
$$;
