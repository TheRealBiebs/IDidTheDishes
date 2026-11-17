begin;
insert into auth.users(id,email,raw_user_meta_data) values('f9000000-0000-4000-8000-000000000001','cat-care-admin@example.invalid','{}'),('f9000000-0000-4000-8000-000000000002','cat-care-member@example.invalid','{}');
select set_config('request.jwt.claims','{"sub":"f9000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
create temp table cat_activity_qa(h uuid,other_house uuid,feed uuid,play uuid,cuddle uuid,other_tag uuid,bonus uuid,w uuid,c uuid,day date,week date);
grant all on cat_activity_qa to authenticated;
insert into cat_activity_qa(h,other_house) select public.create_household_with_chores('Rollback cat activities','Admin','UTC','cats','{}'),public.create_household_with_chores('Rollback other cats','Admin','UTC','cats','{}');
insert into public.household_members(household_id,user_id,display_name,role) select h,'f9000000-0000-4000-8000-000000000002','Member','member' from cat_activity_qa;
update cat_activity_qa set day=current_date,week=date_trunc('week',current_date)::date;
set local role authenticated;
update cat_activity_qa set feed=public.save_tag_with_cooldown(h,null,'Brush your teeth','',20,3,'{}',true,0),play=public.save_tag_with_cooldown(h,null,'Clean your room','',1,3,'{}',true,0),cuddle=public.save_tag_with_cooldown(h,null,'Read a book','',1,3,'{}',true,0),bonus=public.save_tag_with_cooldown(h,null,'Unrelated huge chore','',1000,3,'{}',true,0),other_tag=public.save_tag_with_cooldown(other_house,null,'Someone else’s chore','',1,3,'{}',true,0);
update cat_activity_qa set c=(public.complete_chore_by_id(feed,gen_random_uuid())->>'id')::uuid;
do $$declare d jsonb;c jsonb;begin
 d:=public.cat_dashboard((select h from cat_activity_qa));select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if not (c->>'satisfied')::boolean or jsonb_array_length(c->'actions')<>0 then raise exception 'Points day did not count before care';end if;
 if d->>'timezone'<>'UTC' then raise exception 'Missing household timezone';end if;
 perform public.care_for_cat((select h from cat_activity_qa),'feed');perform public.care_for_cat((select h from cat_activity_qa),'play');d:=public.care_for_cat((select h from cat_activity_qa),'cuddle');
 select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if jsonb_array_length(c->'actions')<>3 then raise exception 'Activities blocked at full target';end if;
 d:=public.care_for_cat((select h from cat_activity_qa),'feed');select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if jsonb_array_length(c->'actions')<>3 then raise exception 'Care retry duplicated activity';end if;
 begin perform public.save_cat_care_settings((select h from cat_activity_qa),20,1,'chores',jsonb_build_object('feed',(select other_tag from cat_activity_qa),'play',(select play from cat_activity_qa),'cuddle',(select cuddle from cat_activity_qa)));raise exception 'Foreign chore accepted';exception when others then if sqlerrm<>'Each cat activity must use an available chore from this household.' then raise;end if;end;
 begin perform public.save_cat_care_settings((select h from cat_activity_qa),20,1,'chores','{}');raise exception 'Missing mappings accepted';exception when others then if sqlerrm<>'Choose a household chore for each cat activity.' then raise;end if;end;
end $$;
reset role;
-- Clear optional clicks so chore-based satisfaction can be verified without any interaction.
delete from app_private.cat_care where week_id in(select id from app_private.cat_weeks where household_id=(select h from cat_activity_qa));
set local role authenticated;
select public.save_cat_care_settings(h,10000,1,'chores',jsonb_build_object('feed',feed,'play',play,'cuddle',cuddle)) from cat_activity_qa;
select public.complete_chore_by_id(bonus,gen_random_uuid()) from cat_activity_qa;
do $$declare d jsonb;c jsonb;begin
 d:=public.cat_dashboard((select h from cat_activity_qa));select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if c->>'care_mode'<>'chores' or (c->>'satisfied')::boolean or (c#>>'{activities,1,unlocked}')::boolean then raise exception 'Unrelated points unlocked mapped care %',c;end if;
 if (c#>>'{activities,0,chore}')<>'Brush your teeth' or not(c#>>'{activities,0,unlocked}')::boolean then raise exception 'Mapped feed not unlocked';end if;
 begin perform public.care_for_cat((select h from cat_activity_qa),'play');raise exception 'Locked play accepted';exception when others then if sqlerrm<>'Complete the required chores to unlock this activity.' then raise;end if;end;
end $$;
select public.complete_chore_by_id(play,gen_random_uuid()) from cat_activity_qa;
select public.complete_chore_by_id(cuddle,gen_random_uuid()) from cat_activity_qa;
do $$declare d jsonb;c jsonb;begin
 d:=public.cat_dashboard((select h from cat_activity_qa));select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if not(c->>'satisfied')::boolean or jsonb_array_length(c->'actions')<>0 then raise exception 'Mapped day needed clicks to count';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"f9000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$declare d jsonb;c jsonb;begin
 begin perform public.save_cat_care_settings((select h from cat_activity_qa),1,1,'points','{}');raise exception 'Member changed settings';exception when others then if sqlerrm<>'Only household admins can configure cat care.' then raise;end if;end;
 d:=public.cat_dashboard((select h from cat_activity_qa));select value into c from jsonb_array_elements(d->'cats') where value->>'user_id'=auth.uid()::text;
 if (c->>'satisfied')::boolean then raise exception 'Another member’s chores counted for this cat';end if;
end $$;
reset role;
-- Past days retain their points requirements; today's mapping is immediate.
do $$declare c app_private.cat_weeks;i int;begin
 select * into c from app_private.cat_weeks where household_id=(select h from cat_activity_qa) and user_id='f9000000-0000-4000-8000-000000000001' and week_start=(select week from cat_activity_qa);
 for i in 0..6 loop
  if c.care_plans->i->>'mode'<>(case when c.week_start+i<(select day from cat_activity_qa) then 'points' else 'chores' end) then raise exception 'Past/future care plan changed incorrectly';end if;
 end loop;
end $$;
-- A closed week with linked chores earns a trophy without any care clicks.
insert into app_private.cat_weeks(household_id,user_id,week_start,eligible_from,variant,targets,timezone,required_days,companion_id,cat_name,care_plans)
select h,'f9000000-0000-4000-8000-000000000001',week-7,week-7,0,array_fill(10000,array[7]),'UTC',1,gen_random_uuid(),'Routine cat',(select jsonb_agg(jsonb_build_object('mode','chores','chores',jsonb_build_object('feed',feed,'play',play,'cuddle',cuddle)) order by i) from generate_series(0,6)i) from cat_activity_qa;
insert into public.chore_completions(household_id,user_id,tag_id,chore,points,base_points,completion_kind,completed_at,chore_date,request_id)
select q.h,'f9000000-0000-4000-8000-000000000001',t,'Archived routine chore',0,0,'tag',(q.week-7)::timestamp at time zone 'UTC',q.week-7,gen_random_uuid() from cat_activity_qa q cross join lateral unnest(array[q.feed,q.play,q.cuddle])t;
select app_private.settle_cat_weeks(h) from cat_activity_qa;
do $$begin
 if not exists(select 1 from app_private.cat_weeks where household_id=(select h from cat_activity_qa) and week_start=(select week-7 from cat_activity_qa) and earned_at is not null and award_days=1 and award_points=22) then raise exception 'Routine trophy required clicks or points';end if;
 if has_function_privilege('authenticated','app_private.cat_day_progress(app_private.cat_weeks,date)','execute') then raise exception 'Private progress helper exposed';end if;
end $$;
select 'PASS: full-target care remains available, points and mapped chores count independently of clicks, per-member completion, admin/household guards, past-day snapshots and no-click trophy award' result;
rollback;
