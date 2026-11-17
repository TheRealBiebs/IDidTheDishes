CREATE OR REPLACE FUNCTION app_private.cat_dashboard(p_household uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare h public.households;u uuid;d date;w date;result jsonb;begin
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household to see its cats.';end if;
 if h.reward_scheme<>'cats' then raise exception 'Choose cat mode to care for cats.';end if;
 d:=(now() at time zone h.timezone)::date;w:=date_trunc('week',d::timestamp)::date;
 for u in select user_id from public.household_members where household_id=p_household loop perform app_private.ensure_cat_week(p_household,u);end loop;
 perform app_private.settle_cat_weeks(p_household);
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'user_id',c.user_id,'name',m.display_name,'variant',c.variant,'cat_name',c.cat_name,'required_days',c.required_days,'companion_id',c.companion_id,'eligible_from',c.eligible_from,
 'points',app_private.cat_day_points(p_household,c.user_id,d),'target',c.targets[d-w+1],
 'actions',coalesce((select to_jsonb(actions) from app_private.cat_care where week_id=c.id and day=d),'[]'::jsonb),
 'days',(select jsonb_agg(jsonb_build_object('day',w+i,'eligible',w+i>=c.eligible_from,'points',app_private.cat_day_points(p_household,c.user_id,w+i),'target',c.targets[i+1],'satisfied',w+i>=c.eligible_from and w+i<=d and app_private.cat_day_points(p_household,c.user_id,w+i)>=c.targets[i+1]) order by i) from generate_series(0,6) i)) order by m.joined_at,c.user_id),'[]'::jsonb)
 into result from app_private.cat_weeks c join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household and c.week_start=w;
 return jsonb_build_object('day',d,'week_start',w,'target',h.cat_daily_target,'required_days',h.cat_required_days,'cats',result);
end $function$;
