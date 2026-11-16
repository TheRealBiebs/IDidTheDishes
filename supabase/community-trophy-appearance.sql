-- Public case appearance only. Membership, consent, following, pagination,
-- private identities and authoritative weekly-win scoring are unchanged.
CREATE OR REPLACE FUNCTION app_private.community_board(p_household uuid, p_followed_only boolean DEFAULT false, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;h uuid;
begin
 perform app_private.community_access(p_household);
 if p_offset is null or p_offset<0 then raise exception 'Choose a valid page.';end if;
 -- Deterministic lock order. Settlement stays private; only aggregate wins
 -- and team names can leave this function, never member identities.
 for h in select household_id from app_private.community_households where enabled order by household_id loop
  perform app_private.settle_household_weeks(h);
 end loop;
 with enrolled as(
  select h.id,h.name,h.teams_enabled,h.theme,h.reward_scheme,exists(select 1 from app_private.community_follows f where f.user_id=auth.uid() and f.target_household=h.id) as following
  from public.households h join app_private.community_households e on e.household_id=h.id and e.enabled
 ), wins as(
  select r.household_id,(s->>'team_id')::uuid as id,r.teams_enabled,sum(coalesce((s->>'weekly_win_points')::integer,0))::bigint as points,(array_agg(s->>'name' order by r.week_start desc))[1] as name
  from public.household_week_results r join enrolled e on e.id=r.household_id cross join lateral jsonb_array_elements(r.team_scores) s
  group by r.household_id,s->>'team_id',r.teams_enabled
 ), scored as(
  select e.id,e.name,e.teams_enabled,e.theme,e.reward_scheme,e.following,coalesce((select sum(w.points) from wins w where w.household_id=e.id),0)::bigint as points,
   case when e.teams_enabled then coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'name',w.name,'points',w.points) order by w.points desc,w.name,w.id) from wins w where w.household_id=e.id and w.teams_enabled),'[]'::jsonb) else '[]'::jsonb end as teams
  from enrolled e
 ), ranked as(select *,dense_rank() over(order by points desc) as rank from scored),
 filtered as(select * from ranked where not coalesce(p_followed_only,false) or following or id=p_household),
 page as(select * from filtered order by points desc,lower(name),id offset p_offset limit 25)
 select jsonb_build_object('households',(select coalesce(jsonb_agg(to_jsonb(p) order by p.points desc,lower(p.name),p.id),'[]') from page p),'total',(select count(*) from filtered),'following_count',(select count(*) from enrolled where following),'score_kind','weekly_wins') into result;
 return result;
end $function$
;
notify pgrst,'reload schema';

