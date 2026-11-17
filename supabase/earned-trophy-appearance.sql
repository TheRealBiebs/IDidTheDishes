-- Trophy appearance comes from the award snapshot, never the current theme.
create function app_private.trophy_items(p_household uuid) returns table(entity_id uuid,entity_name text,item jsonb)
language sql stable security definer set search_path='' as $$
 select (s->>'team_id')::uuid,s->>'name',jsonb_build_object('id',r.id::text||':'||(s->>'team_id')||':'||n,'mode',r.reward_scheme,'symbol',coalesce(s->>'symbol','star'),'color',coalesce(s->>'color','#c8a55b'),'week_start',r.week_start,'name',s->>'name')
 from public.household_week_results r cross join lateral jsonb_array_elements(r.team_scores) s
 cross join lateral generate_series(1,coalesce((s->>'weekly_win_points')::integer,0)) n
 where r.household_id=p_household and not(r.reward_scheme='cats' and exists(select 1 from app_private.cat_weeks c where c.household_id=r.household_id and c.week_start=r.week_start))
 union all
 select c.user_id,coalesce(m.display_name,'Former member'),jsonb_build_object('id',c.id,'mode','cats','cat_type',c.variant,'week_start',c.week_start,'color','#c99da9')
 from app_private.cat_weeks c left join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id
 where c.household_id=p_household and c.earned_at is not null
$$;
create function app_private.household_trophy_entries(p_household uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with awards as(select * from app_private.trophy_items(p_household)),current_competitors as(
 select t.id,t.name,t.color from public.household_teams t join public.households h on h.id=t.household_id where h.id=p_household and h.teams_enabled and t.active
 union select m.user_id,m.display_name,'#c99da9' from public.household_members m join public.households h on h.id=m.household_id where h.id=p_household and (not h.teams_enabled or h.reward_scheme='cats')
 ),competitors as(select * from current_competitors union select a.entity_id,(array_agg(a.entity_name order by a.item->>'week_start' desc))[1],(array_agg(a.item->>'color' order by a.item->>'week_start' desc))[1] from awards a
 where not exists(select 1 from current_competitors c where c.id=a.entity_id) group by a.entity_id
 ),totals as(select c.id,c.name,c.color,count(a.item)::integer as weekly_points,coalesce(jsonb_agg(a.item order by a.item->>'week_start',a.item->>'id') filter(where a.item is not null),'[]'::jsonb) as trophies
 from competitors c left join awards a on a.entity_id=c.id group by c.id,c.name,c.color)
 select coalesce(jsonb_agg(to_jsonb(t) order by t.weekly_points desc,t.name,t.id),'[]'::jsonb) from totals t
$$;
revoke all on function app_private.trophy_items(uuid),app_private.household_trophy_entries(uuid) from public,anon,authenticated;

create or replace function app_private.household_weekly_scores(p_household uuid) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 perform app_private.settle_weekly_results(p_household);
 return app_private.household_trophy_entries(p_household);
end $$;
