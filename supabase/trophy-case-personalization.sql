begin;
create table app_private.trophy_case_styles(
 household_id uuid not null references public.households on delete cascade,case_id uuid not null,
 frame text not null check(frame ~ '^#[0-9a-fA-F]{6}$'),backdrop text not null check(backdrop ~ '^#[0-9a-fA-F]{6}$'),
 finish text not null check(finish in('wood','brass','modern')),primary key(household_id,case_id)
);
alter table app_private.trophy_case_styles enable row level security;
create policy trophy_case_styles_private on app_private.trophy_case_styles to anon,authenticated using(false) with check(false);
revoke all on app_private.trophy_case_styles from public,anon,authenticated;
create function app_private.save_trophy_case(p_household uuid,p_case uuid,p_frame text,p_backdrop text,p_finish text) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if p_case is null or not(app_private.is_admin(p_household) or p_case=auth.uid() or exists(select 1 from public.household_members where household_id=p_household and user_id=auth.uid() and team_id=p_case)) then raise exception 'You can customize only your own or your team’s case.';end if;
 if not exists(select 1 from public.household_members where household_id=p_household and user_id=p_case) and not exists(select 1 from public.household_teams where household_id=p_household and id=p_case) then raise exception 'Trophy case not found.';end if;
 if p_frame is null or p_frame !~ '^#[0-9a-fA-F]{6}$' or p_backdrop is null or p_backdrop !~ '^#[0-9a-fA-F]{6}$' or p_finish is null or p_finish not in('wood','brass','modern') then raise exception 'Choose valid colors and a supported finish.';end if;
 insert into app_private.trophy_case_styles values(p_household,p_case,p_frame,p_backdrop,p_finish) on conflict(household_id,case_id) do update set frame=excluded.frame,backdrop=excluded.backdrop,finish=excluded.finish;
 return jsonb_build_object('frame',p_frame,'backdrop',p_backdrop,'finish',p_finish);
end $$;
create function public.save_trophy_case(p_household uuid,p_case uuid,p_frame text,p_backdrop text,p_finish text) returns jsonb language sql security invoker set search_path='' as $$select app_private.save_trophy_case(p_household,p_case,p_frame,p_backdrop,p_finish)$$;
revoke all on function app_private.save_trophy_case(uuid,uuid,text,text,text),public.save_trophy_case(uuid,uuid,text,text,text) from public,anon;
grant execute on function app_private.save_trophy_case(uuid,uuid,text,text,text),public.save_trophy_case(uuid,uuid,text,text,text) to authenticated;

create or replace function app_private.trophy_items(p_household uuid) returns table(entity_id uuid,entity_name text,item jsonb)
language sql stable security definer set search_path='' as $$
 select (s->>'team_id')::uuid,s->>'name',jsonb_build_object('id',r.id::text||':'||(s->>'team_id')||':'||n,'mode',r.reward_scheme,'symbol',coalesce(s->>'symbol','star'),'color',coalesce(s->>'color','#c8a55b'),'week_start',r.week_start,'won_on',r.week_end,'name',s->>'name','points',coalesce((s->>'points')::bigint,0),'chores',coalesce((s->>'chores')::integer,0),'personal_points',(select coalesce(sum((details->>'points')::bigint),0) from public.weekly_result_chores where result_id=r.id and details->>'user_id'=auth.uid()::text))
 from public.household_week_results r cross join lateral jsonb_array_elements(r.team_scores) s cross join lateral generate_series(1,coalesce((s->>'weekly_win_points')::integer,0)) n
 where r.household_id=p_household and not(r.reward_scheme='cats' and exists(select 1 from app_private.cat_weeks c where c.household_id=r.household_id and c.week_start=r.week_start))
 union all select c.user_id,coalesce(m.display_name,'Former member'),jsonb_build_object('id',c.id,'mode','cats','cat_type',c.variant,'cat_name',c.cat_name,'week_start',c.week_start,'won_on',c.week_start+7,'color','#c99da9','points',coalesce(c.award_points,(select coalesce(sum(points),0) from public.chore_completions where household_id=c.household_id and user_id=c.user_id and chore_date>=c.week_start and chore_date<c.week_start+7)),'chores',c.award_chores,'satisfied_days',coalesce(c.award_days,app_private.cat_satisfied_days(c)),'required_days',c.required_days,'name',coalesce(m.display_name,'Former member'))
 from app_private.cat_weeks c left join public.household_members m on m.household_id=c.household_id and m.user_id=c.user_id where c.household_id=p_household and c.earned_at is not null
$$;
create function app_private.case_trophy_items(p_household uuid) returns table(entity_id uuid,entity_name text,item jsonb)
language sql stable security definer set search_path='' as $$
 select coalesce(t.id,a.entity_id),coalesce(t.name,a.entity_name),a.item from app_private.trophy_items(p_household) a
 join public.households h on h.id=p_household
 left join public.household_members m on m.household_id=p_household and m.user_id=a.entity_id and h.teams_enabled
 left join public.household_teams t on t.household_id=p_household and t.id=m.team_id
$$;
create or replace function app_private.household_trophy_entries(p_household uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with awards as(select * from app_private.case_trophy_items(p_household)),current_competitors as(
 select t.id,t.name,t.color from public.household_teams t join public.households h on h.id=t.household_id where h.id=p_household and h.teams_enabled and t.active
 union select m.user_id,m.display_name,'#c99da9' from public.household_members m join public.households h on h.id=m.household_id where h.id=p_household and (not h.teams_enabled or m.team_id is null)
 ),competitors as(select * from current_competitors union select a.entity_id,(array_agg(a.entity_name order by a.item->>'week_start' desc))[1],(array_agg(a.item->>'color' order by a.item->>'week_start' desc))[1] from awards a where not exists(select 1 from current_competitors c where c.id=a.entity_id) group by a.entity_id),
 totals as(select c.id,c.name,c.color,count(a.item)::integer as weekly_points,coalesce(jsonb_agg(a.item order by a.item->>'week_start',a.item->>'id') filter(where a.item is not null),'[]'::jsonb) as trophies,
 coalesce((select jsonb_build_object('frame',frame,'backdrop',backdrop,'finish',finish) from app_private.trophy_case_styles where household_id=p_household and case_id=c.id),'{}'::jsonb) as appearance,
 (app_private.is_admin(p_household) or c.id=auth.uid() or exists(select 1 from public.household_members where household_id=p_household and user_id=auth.uid() and team_id=c.id)) as can_customize
 from competitors c left join awards a on a.entity_id=c.id group by c.id,c.name,c.color)
 select coalesce(jsonb_agg(to_jsonb(t) order by t.weekly_points desc,t.name,t.id),'[]'::jsonb) from totals t
$$;
revoke all on function app_private.case_trophy_items(uuid) from public,anon,authenticated;
commit;
