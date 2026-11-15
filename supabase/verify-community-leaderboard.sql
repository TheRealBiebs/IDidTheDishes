begin;
create temp table community_qa(admin_user uuid,viewer uuid,a uuid,b uuid,hidden uuid,ta uuid default gen_random_uuid(),tb uuid default gen_random_uuid(),tc uuid default gen_random_uuid());
grant all on community_qa to authenticated,anon;
insert into community_qa(admin_user,viewer) select (select id from auth.users where email='andrewpbieber@gmail.com'),(select id from auth.users where email='andrew@cyclingcicerone.com');
select set_config('request.jwt.claims',jsonb_build_object('sub',(select admin_user from community_qa),'role','authenticated')::text,true);
update community_qa set a=public.create_household_with_chores('Community QA A','Private admin name','UTC','cats','{}'),b=public.create_household_with_chores('Community QA B','Private other name','UTC','cats','{}'),hidden=public.create_household_with_chores('Community QA Hidden','Private hidden name','UTC','cats','{}');
insert into public.household_teams(id,household_id,name,color,symbol) select ta,a,'A Team','#ff0000','star' from community_qa union all select tb,b,'B Team','#0000ff','star' from community_qa union all select tc,hidden,'Hidden Team','#00ff00','star' from community_qa;
update public.household_members m set team_id=case when m.household_id=q.a then q.ta when m.household_id=q.b then q.tb else q.tc end from community_qa q where m.household_id in(q.a,q.b,q.hidden);
insert into public.household_members(household_id,user_id,display_name,role,team_id) select a,viewer,'Private viewer','member',ta from community_qa;
insert into public.chore_completions(household_id,user_id,chore,points,chore_date,request_id,completion_kind,comment) select a,admin_user,'Private chore A',2,(now() at time zone 'UTC')::date,gen_random_uuid(),'unexpected','Private comment A' from community_qa union all select b,admin_user,'Private chore B',3,(now() at time zone 'UTC')::date,gen_random_uuid(),'unexpected','Private comment B' from community_qa union all select hidden,admin_user,'Private hidden chore',3,(now() at time zone 'UTC')::date,gen_random_uuid(),'unexpected','Private hidden comment' from community_qa;
-- Prior-week points must not affect the community board.
insert into public.chore_completions(household_id,user_id,chore,points,chore_date,request_id,completion_kind) select b,admin_user,'Old private chore',3,date_trunc('week',now() at time zone 'UTC')::date-1,gen_random_uuid(),'unexpected' from community_qa;
set local role authenticated;
do $$begin
 if public.community_status((select a from community_qa))->>'joined'<>'false' then raise exception 'Default enrollment was not private';end if;
 begin perform public.community_board((select a from community_qa));raise exception 'Unjoined access allowed';exception when others then if sqlerrm<>'A household admin must join the community leaderboard first.' then raise;end if;end;
 begin perform public.set_community_sharing((select a from community_qa),true,false);raise exception 'Missing consent accepted';exception when others then if sqlerrm<>'Accept the sharing disclosure before joining.' then raise;end if;end;
 perform public.set_community_sharing((select a from community_qa),true,true);
 perform public.set_community_sharing((select b from community_qa),true,true);
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select viewer from community_qa),'role','authenticated')::text,true);
do $$declare board jsonb;own_rows jsonb;target_rows jsonb;begin
 begin perform public.community_board((select a from community_qa));raise exception 'Viewer skipped disclosure';exception when others then if sqlerrm<>'Please accept the leaderboard sharing disclosure first.' then raise;end if;end;
 begin perform public.set_community_sharing((select a from community_qa),false,false);raise exception 'Member withdrew household consent';exception when others then if sqlerrm<>'Only a household admin can join or leave the community leaderboard.' then raise;end if;end;
 perform public.accept_community((select a from community_qa),true);
 board:=public.community_board((select a from community_qa));
 if board::text like '%Private%' or board::text like '%Hidden%' then raise exception 'Private data leaked';end if;
 select r into target_rows from jsonb_array_elements(board->'households') r where r->>'id'=(select b::text from community_qa);
 if target_rows is null or (target_rows->>'points')::integer<>3 or target_rows->'teams'->0->>'name'<>'B Team' then raise exception 'Team points incorrect or old week counted';end if;
 if exists(select 1 from jsonb_object_keys(target_rows) k where k not in('id','name','following','points','teams','rank')) then raise exception 'Unexpected household disclosure';end if;
 if exists(select 1 from jsonb_object_keys(target_rows->'teams'->0) k where k not in('id','name','points')) then raise exception 'Unexpected team disclosure';end if;
 if exists(select 1 from public.chore_completions where household_id=(select b from community_qa)) then raise exception 'Raw chore RLS bypassed';end if;
 perform public.community_follow((select a from community_qa),(select b from community_qa),true);
 board:=public.community_board((select a from community_qa),true);
 if not exists(select 1 from jsonb_array_elements(board->'households') r where r->>'id'=(select b::text from community_qa)) then raise exception 'Followed household missing';end if;
 if exists(select 1 from jsonb_array_elements(board->'households') r where r->>'id' not in((select a::text from community_qa),(select b::text from community_qa))) then raise exception 'Following filter leaked unrelated household';end if;
 perform public.community_follow((select a from community_qa),(select b from community_qa),false);
 if (public.community_board((select a from community_qa),true)->>'total')::integer<>1 then raise exception 'Unfollow failed';end if;
 begin perform public.community_follow((select a from community_qa),(select hidden from community_qa),true);raise exception 'Hidden household follow allowed';exception when others then if sqlerrm<>'That household is not sharing community scores.' then raise;end if;end;
 begin perform public.community_status((select b from community_qa));raise exception 'Foreign household impersonation allowed';exception when others then if sqlerrm<>'Join this household first.' then raise;end if;end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select admin_user from community_qa),'role','authenticated')::text,true);
do $$begin
 if (public.community_board((select a from community_qa),true)->>'total')::integer<>1 then raise exception 'Follow choices leaked between users';end if;
 perform public.set_community_sharing((select b from community_qa),false,false);
 if exists(select 1 from jsonb_array_elements(public.community_board((select a from community_qa))->'households') r where r->>'id'=(select b::text from community_qa)) then raise exception 'Withdrawn scores still visible';end if;
 perform public.set_community_sharing((select a from community_qa),false,false);
 begin perform public.community_board((select a from community_qa));raise exception 'Left household still has access';exception when others then if sqlerrm<>'A household admin must join the community leaderboard first.' then raise;end if;end;
end $$;
reset role;set local role anon;
do $$begin
 begin perform public.community_board((select a from community_qa));raise exception 'Anonymous board access allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;rollback;
select 'PASS: explicit household and viewer consent, admin-only sharing, weekly aggregate-only disclosure, raw-data RLS, personal follow/unfollow and filtering, foreign/anonymous denial, and immediate withdrawal; fixtures rolled back' as result;
