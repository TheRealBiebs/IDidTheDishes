begin;
create temp table tutorial_qa(a uuid,b uuid,h uuid,other_h uuid);
grant all on tutorial_qa to authenticated,anon;
insert into tutorial_qa(a,b) select (select id from auth.users where email='andrewpbieber@gmail.com'),(select id from auth.users where email='andrew@cyclingcicerone.com');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from tutorial_qa),'role','authenticated')::text,true);
set local role authenticated;
update tutorial_qa set h=public.create_household_experience('Tutorial QA','Admin','UTC','wizard','{}'),other_h=public.create_household_experience('Other tutorial QA','Admin','UTC','cats','{}');
do $$begin
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'not_started' then raise exception 'New member did not receive a tutorial';end if;
 perform public.save_household_tutorial((select h from tutorial_qa),'create-chore','active');
 if public.household_tutorial((select h from tutorial_qa))->>'step'<>'create-chore' then raise exception 'Tutorial progress was not saved';end if;
 if public.household_tutorial((select other_h from tutorial_qa))->>'status'<>'not_started' then raise exception 'Household progress was not isolated';end if;
end $$;
reset role;
insert into public.household_members(household_id,user_id,display_name,role) select h,b,'Member','member' from tutorial_qa;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select b from tutorial_qa),'role','authenticated')::text,true);
set local role authenticated;
do $$begin
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'not_started' then raise exception 'Another member inherited the admin tutorial';end if;
 perform public.save_household_tutorial((select h from tutorial_qa),'help','completed');
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'completed' then raise exception 'Member could not finish own tutorial';end if;
 begin perform public.household_tutorial((select other_h from tutorial_qa));raise exception 'Foreign household progress read';exception when others then if sqlerrm<>'Join this household before using its tutorial.' then raise;end if;end;
 begin perform public.save_household_tutorial((select other_h from tutorial_qa),'overview','skipped');raise exception 'Foreign household progress changed';exception when others then if sqlerrm<>'Join this household before using its tutorial.' then raise;end if;end;
 begin perform public.save_household_tutorial((select h from tutorial_qa),'overview','unknown');raise exception 'Invalid status accepted';exception when others then if sqlerrm<>'Choose a valid tutorial step and status.' then raise;end if;end;
 begin perform public.save_household_tutorial((select h from tutorial_qa),'<script>','active');raise exception 'Invalid step accepted';exception when others then if sqlerrm<>'Choose a valid tutorial step and status.' then raise;end if;end;
 begin perform count(*) from app_private.household_tutorials;raise exception 'Client could read private progress directly';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select a from tutorial_qa),'role','authenticated')::text,true);
do $$begin
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'active' or public.household_tutorial((select h from tutorial_qa))->>'step'<>'create-chore' then raise exception 'Member overwrote the admin tutorial';end if;
 perform public.save_household_tutorial((select h from tutorial_qa),'help','completed');
 perform public.save_household_tutorial((select h from tutorial_qa),'overview','active');
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'active' then raise exception 'Replay did not reset the tour';end if;
 perform public.save_household_tutorial((select h from tutorial_qa),'overview','skipped');
 if public.household_tutorial((select h from tutorial_qa))->>'status'<>'skipped' then raise exception 'Skip was not remembered';end if;
end $$;
reset role;
do $$begin
 if (select count(*) from app_private.household_tutorials where household_id=(select h from tutorial_qa))<>2 then raise exception 'Progress created duplicate records';end if;
end $$;
set local role anon;
do $$begin
 begin perform public.household_tutorial((select h from tutorial_qa));raise exception 'Anonymous tutorial access allowed';exception when insufficient_privilege then null;end;
 begin perform public.save_household_tutorial((select h from tutorial_qa),'overview','skipped');raise exception 'Anonymous tutorial write allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: private per-user/per-household tour state, first-run default, resumable steps, completion, replay, skip, validation, ordinary-member access, foreign-household and anonymous/direct access denial; rolled back' as result;
