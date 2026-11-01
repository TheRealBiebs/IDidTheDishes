-- Self-contained verification. Every fixture is rolled back by the inner
-- exception block; the migration fails if any assertion fails.
do $$
declare a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();client uuid:=gen_random_uuid();h uuid;ta uuid;tb uuid;tag uuid;rid uuid;week date;boundary timestamptz;answer jsonb;
begin
 begin
  insert into auth.users(id,email,raw_user_meta_data) values(a,'weekly-a-'||a||'@example.invalid','{}'),(b,'weekly-b-'||b||'@example.invalid','{}');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
  h:=app_private.create_household_with_chores('Weekly rollback QA','Alice','America/Los_Angeles','wizard',array['dishes']);
  select id into ta from public.household_teams where household_id=h and preset_key='wizard:gryffindor';
  select id into tb from public.household_teams where household_id=h and preset_key='wizard:slytherin';
  update public.household_members set team_id=ta where household_id=h and user_id=a;
  insert into public.household_members(household_id,user_id,display_name,role,team_id) values(h,b,'Bob','member',tb);
  week:=date_trunc('week',now() at time zone 'America/Los_Angeles')::date-7;
  boundary:=(week+7)::timestamp at time zone 'America/Los_Angeles';
  update public.households set weekly_competition_started_at=week::timestamp at time zone 'America/Los_Angeles' where id=h;
  update app_private.weekly_history set effective_at=boundary-interval '1 day' where household_id=h;
  select id into tag from public.chore_tags where household_id=h limit 1;
  insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id)
  values(h,tag,a,'First chore',10,week+1,gen_random_uuid()),(h,tag,a,'Second chore',20,week+2,gen_random_uuid()),(h,tag,b,'Winning chore',40,week+3,gen_random_uuid());
  -- All three changes are after the boundary but before anyone reads results.
  update public.household_members set team_id=ta where household_id=h and user_id=b;
  update public.household_teams set name='Renamed after reset' where id=tb;
  update public.households set reward_scheme='stars' where id=h;
  answer:=public.weekly_hall(h);
  if jsonb_array_length(answer->'weeks')<>1 then raise exception 'Incorrect closed-week count';end if;
  rid:=(answer#>>'{weeks,0,id}')::uuid;
  if answer#>>'{weeks,0,reward_scheme}'<>'points' then raise exception 'Reward change rewrote closed week';end if;
  if answer#>>'{weeks,0,team_scores,0,team_id}'<>tb::text or answer#>>'{weeks,0,team_scores,0,score}'<>'40' or answer#>>'{weeks,0,team_scores,0,weekly_win_points}'<>'1' then raise exception 'Membership change rewrote winner';end if;
  if answer#>>'{weeks,0,team_scores,0,name}'='Renamed after reset' then raise exception 'Team rename rewrote archived name';end if;
  perform public.weekly_hall(h);
  if (select count(*) from public.household_week_results where household_id=h)<>1 then raise exception 'Award duplicated';end if;
  answer:=public.weekly_chores(rid);
  if (answer->>'total')::integer<>3 then raise exception 'Missing archived chores';end if;
  answer:=public.weekly_chores(rid,tb);
  if (answer->>'total')::integer<>1 or answer#>>'{chores,0,display_name}'<>'Bob' then raise exception 'Historical team filter failed';end if;
  update public.chore_completions set points=999 where household_id=h;
  answer:=public.weekly_chores(rid,tb);
  if answer#>>'{chores,0,points}'<>'40' then raise exception 'Archived chore changed';end if;
  if public.pending_weekly_result(h) is null then raise exception 'Missing first-visit celebration';end if;
  if not public.claim_weekly_result(rid,client) then raise exception 'First device could not claim';end if;
  if public.claim_weekly_result(rid,gen_random_uuid()) then raise exception 'Second device claimed the same celebration';end if;
  if not public.claim_weekly_result(rid,client) then raise exception 'Claim retry was not idempotent';end if;
  answer:=public.weekly_chores(rid,null,1,1);
  if jsonb_array_length(answer->'chores')<>1 or (answer->>'total')::integer<>3 then raise exception 'History pagination failed';end if;
  perform public.ack_weekly_result(rid);
  if public.claim_weekly_result(rid,gen_random_uuid()) then raise exception 'Seen celebration was claimable';end if;
  if public.pending_weekly_result(h) is not null then raise exception 'Celebration replayed after acknowledgement';end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
  begin perform public.weekly_hall(h);raise exception 'Foreign household results exposed';exception when others then if sqlerrm<>'Join this household to view weekly results.' then raise;end if;end;
  begin perform public.weekly_chores(rid);raise exception 'Foreign chore archive exposed';exception when others then if sqlerrm<>'Join this household to view weekly results.' then raise;end if;end;
  raise exception using errcode='ZX001',message='Weekly fixture verification passed; roll back fixtures';
 exception when sqlstate 'ZX001' then null;
 end;
end $$;
