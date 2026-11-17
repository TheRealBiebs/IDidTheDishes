CREATE OR REPLACE FUNCTION app_private.settle_household_weeks(p_household uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare h public.households;w date;current_week date;boundary timestamptz;scheme text;look text;raw_scores jsonb;scores jsonb;r uuid;enabled boolean;
begin
 select * into h from public.households where id=p_household for no key update;
 if h.id is null then return;end if;
 perform app_private.settle_cat_weeks(p_household);
 current_week:=date_trunc('week',now() at time zone h.timezone)::date;
 w:=date_trunc('week',h.weekly_competition_started_at at time zone h.timezone)::date;
 select greatest(w,coalesce(max(week_start)+7,w)) into w from public.household_week_results where household_id=p_household;
 while w<current_week loop
  boundary:=(w+7)::timestamp at time zone h.timezone;
  select payload->>'reward_scheme',payload->>'theme',coalesce((payload->>'teams_enabled')::boolean,true) into scheme,look,enabled from app_private.weekly_history where household_id=p_household and kind='household' and effective_at<boundary order by effective_at desc,id desc limit 1;
  scheme:=coalesce(scheme,h.reward_scheme);look:=coalesce(look,h.theme);enabled:=coalesce(enabled,h.teams_enabled);
  if enabled then
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  totals as(
   select t.entity_id as team_id,t.payload->>'name' as name,t.payload->>'color' as color,t.payload->>'symbol' as symbol,count(c.id) as chores,coalesce(sum(c.points),0) as points
   from teams_at_end t left join members_at_end m on m.payload->>'team_id'=t.entity_id::text and not coalesce((m.payload->>'_deleted')::boolean,false)
   left join public.chore_completions c on c.household_id=p_household and c.user_id=m.entity_id and c.chore_date>=w and c.chore_date<w+7
   where not coalesce((t.payload->>'_deleted')::boolean,false) group by t.entity_id,t.payload
  ) select coalesce(jsonb_agg(to_jsonb(totals)),'[]'::jsonb) into raw_scores from totals;
  else
   with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
   totals as(select m.entity_id as team_id,m.payload->>'display_name' as name,'#7e9dce'::text as color,'star'::text as symbol,'individual'::text as kind,count(c.id) as chores,coalesce(sum(c.points),0) as points
    from members_at_end m left join public.chore_completions c on c.household_id=p_household and c.user_id=m.entity_id and c.chore_date>=w and c.chore_date<w+7
    where not coalesce((m.payload->>'_deleted')::boolean,false) group by m.entity_id,m.payload)
   select coalesce(jsonb_agg(to_jsonb(totals)),'[]'::jsonb) into raw_scores from totals;
  end if;
  scores:=app_private.rank_week_teams(raw_scores,scheme);
  if scheme='cats' and exists(select 1 from app_private.cat_weeks cw where cw.household_id=p_household and cw.week_start=w) then
   enabled:=false;
   select coalesce(jsonb_agg(jsonb_build_object('team_id',cw.user_id,'name',coalesce(m.display_name,'Former member'),'color','#c99da9','symbol','cat','kind','individual','cat_type',cw.variant,'chores',app_private.cat_satisfied_days(cw),'points',(select coalesce(sum(c.points),0) from public.chore_completions c where c.household_id=p_household and c.user_id=cw.user_id and c.chore_date>=w and c.chore_date<w+7),'score',app_private.cat_satisfied_days(cw),'winner',cw.earned_at is not null,'weekly_win_points',case when cw.earned_at is not null then 1 else 0 end) order by cw.user_id),'[]'::jsonb) into scores
   from app_private.cat_weeks cw left join public.household_members m on m.household_id=cw.household_id and m.user_id=cw.user_id where cw.household_id=p_household and cw.week_start=w;
  end if;
  insert into public.household_week_results(household_id,week_start,week_end,timezone,reward_scheme,theme,team_scores,teams_enabled) values(p_household,w,w+7,h.timezone,scheme,look,scores,enabled) returning id into r;
  with members_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='member' and effective_at<boundary order by entity_id,effective_at desc,id desc),
  teams_at_end as(select distinct on(entity_id) entity_id,payload from app_private.weekly_history where household_id=p_household and kind='team' and effective_at<boundary order by entity_id,effective_at desc,id desc)
  insert into public.weekly_result_chores(result_id,completion_id,team_id,completed_at,proof_path,details)
  select r,c.id,case when enabled then t.entity_id else m.entity_id end,c.completed_at,c.proof_path,to_jsonb(c)||jsonb_build_object('display_name',coalesce(m.payload->>'display_name','Former member'),'team_id',case when enabled then t.entity_id else m.entity_id end,'team_name',case when enabled then t.payload->>'name' else m.payload->>'display_name' end,'team_color',case when enabled then t.payload->>'color' else '#7e9dce' end)
  from public.chore_completions c left join members_at_end m on m.entity_id=c.user_id
  left join teams_at_end t on t.entity_id::text=m.payload->>'team_id' and not coalesce((m.payload->>'_deleted')::boolean,false) and not coalesce((t.payload->>'_deleted')::boolean,false)
  where c.household_id=p_household and c.chore_date>=w and c.chore_date<w+7;
  w:=w+7;
 end loop;
end $function$;

CREATE OR REPLACE FUNCTION app_private.weekly_hall(p_household uuid, p_before date DEFAULT NULL::date, p_limit integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare weeks jsonb;standings jsonb;more boolean;
begin
 if p_limit not between 1 and 100 or p_limit is null then raise exception 'Choose 1 to 100 weekly results.';end if;
 perform app_private.settle_weekly_results(p_household);
 select coalesce(jsonb_agg(to_jsonb(q) order by week_start desc),'[]'::jsonb) into weeks from (select * from public.household_week_results where household_id=p_household and (p_before is null or week_start<p_before) order by week_start desc limit p_limit) q;
 select count(*)>p_limit into more from public.household_week_results where household_id=p_household and (p_before is null or week_start<p_before);
 standings:=app_private.household_trophy_entries(p_household);
 return jsonb_build_object('weeks',weeks,'standings',standings,'has_more',more,'started_at',(select weekly_competition_started_at from public.households where id=p_household));
end $function$;
