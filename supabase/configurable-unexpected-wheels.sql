-- Reference source for the configurable_unexpected_wheels MCP migration.
begin;
create function app_private.valid_unexpected_wheels(settings jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare k text;v jsonb;begin
 if settings is null or jsonb_typeof(settings)<>'object' then return false;end if;
 if (select count(*) from jsonb_object_keys(settings))<>3 then return false;end if;
 foreach k in array array['standard','low','high'] loop
  if jsonb_typeof(settings->k) is distinct from 'object' then return false;end if;
  if (select count(*) from jsonb_object_keys(settings->k))<>2 or jsonb_typeof(settings->k->'enabled') is distinct from 'boolean' or jsonb_typeof(settings->k->'values') is distinct from 'array' then return false;end if;
  if jsonb_array_length(settings->k->'values')<>4 then return false;end if;
  for v in select value from jsonb_array_elements(settings->k->'values') loop
   if jsonb_typeof(v)<>'number' or v::text !~ '^[0-9]{1,4}$' then return false;end if;
   if (v::text)::integer>1000 then return false;end if;
  end loop;
 end loop;
 return (settings->'standard'->>'enabled')::boolean;
end $$;
revoke all on function app_private.valid_unexpected_wheels(jsonb) from public,anon;
grant execute on function app_private.valid_unexpected_wheels(jsonb) to authenticated;
alter table public.households add column unexpected_wheels jsonb not null default '{"standard":{"enabled":true,"values":[0,1,2,3]},"low":{"enabled":false,"values":[0,1,1,2]},"high":{"enabled":false,"values":[2,3,4,5]}}';
alter table public.households add constraint household_unexpected_wheels_valid check(app_private.valid_unexpected_wheels(unexpected_wheels));
alter table public.chore_completions add column unexpected_wheel text not null default 'standard' check(unexpected_wheel in('standard','low','high'));
alter table public.chore_completions add column unexpected_reward jsonb;
alter table public.chore_completions drop constraint completion_source_valid;
alter table public.chore_completions add constraint completion_source_valid check((completion_kind='tag' and tag_id is not null) or (completion_kind='unexpected' and tag_id is null and points between 0 and 1000));

create function app_private.save_unexpected_wheels(p_household uuid,p_settings jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can configure random chore wheels.';end if;
 if not app_private.valid_unexpected_wheels(p_settings) then raise exception 'Each wheel needs four whole point values from 0 to 1000. The standard wheel must stay enabled.';end if;
 update public.households set unexpected_wheels=p_settings where id=p_household;
end $$;
create function public.save_unexpected_wheels(p_household uuid,p_settings jsonb) returns void
language sql security invoker set search_path='' as $$select app_private.save_unexpected_wheels(p_household,p_settings)$$;
revoke all on function app_private.save_unexpected_wheels(uuid,jsonb),public.save_unexpected_wheels(uuid,jsonb) from public,anon;
grant execute on function app_private.save_unexpected_wheels(uuid,jsonb),public.save_unexpected_wheels(uuid,jsonb) to authenticated;

create or replace function app_private.snapshot_calendar_sticker() returns trigger
language plpgsql security definer set search_path='' as $$begin
 if new.completion_kind='unexpected' and new.unexpected_reward->>'type'='sticker' then
  new.calendar_sticker:=new.unexpected_reward->>'sticker';
 else
  new.calendar_sticker:=coalesce((select calendar_sticker from public.chore_tags where id=new.tag_id),'star');
 end if;
 return new;
end $$;

create function app_private.log_unexpected_chore_wheel(p_household uuid,p_description text,p_request uuid,p_wheel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;h public.households;d date;n text;reward integer:=0;description text:=trim(p_description);suffix text;options jsonb;chosen integer;outcome jsonb;sticker text;
begin
 if auth.uid() is null then raise exception 'Please sign in.';end if;
 if p_request is null then raise exception 'A submission ID is required.';end if;
 if description is null or description !~ '[^[:space:]]' or length(description)>500 then raise exception 'Describe the chore in 1 to 500 characters.';end if;
 if p_wheel is null or p_wheel not in('standard','low','high') then raise exception 'Choose an available chore wheel.';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,41));
 select * into h from public.households where id=p_household for no key update;
 if not app_private.is_member(p_household) then raise exception 'Join this household before logging chores.';end if;
 select * into c from public.chore_completions where user_id=auth.uid() and request_id=p_request;
 if c.id is not null then
  if c.completion_kind<>'unexpected' or c.household_id<>p_household or c.chore<>description or c.unexpected_wheel<>p_wheel then raise exception 'This submission ID was already used for another chore or wheel.';end if;
  return to_jsonb(c);
 end if;
 if h.reward_scheme='cats' and h.cat_care_mode='chores' then raise exception 'Random chore wheels are unavailable when cat activities use specific chores.';end if;
 if not (h.unexpected_wheels->p_wheel->>'enabled')::boolean then raise exception 'This chore wheel is disabled by your household admin.';end if;
 d:=(now() at time zone h.timezone)::date;
 if h.reward_scheme='stars' then
  options:='["star","rainbow","kitty","dog","heart","sun","moon","flower","butterfly","dinosaur","rocket","unicorn","trophy","smiley","clap","fire","gem"]';
  chosen:=floor(random()*jsonb_array_length(options))::integer;sticker:=options->>chosen;
  outcome:=jsonb_build_object('type','sticker','options',options,'index',chosen,'sticker',sticker);
 else
  options:=h.unexpected_wheels->p_wheel->'values';chosen:=floor(random()*4)::integer;reward:=(options->>chosen)::integer;
  outcome:=jsonb_build_object('type','points','options',options,'index',chosen);
 end if;
 insert into public.chore_completions(household_id,tag_id,user_id,chore,points,chore_date,request_id,completion_kind,unexpected_wheel,unexpected_reward)
 values(p_household,null,auth.uid(),description,reward,d,p_request,'unexpected',p_wheel,outcome) returning * into c;
 select display_name into n from public.household_members where household_id=p_household and user_id=auth.uid();
 suffix:=case when h.reward_scheme='stars' then ' (+1 random calendar sticker)' when h.reward_scheme='poker' then ' (+'||reward||' chips)' else ' (+'||reward||' points)' end;
 insert into public.notifications(user_id,household_id,completion_id,message)
 select user_id,p_household,c.id,n||' completed an unexpected chore: '||description||suffix from public.household_members where household_id=p_household and user_id<>auth.uid();
 return to_jsonb(c);
end $$;
create function public.log_unexpected_chore_wheel(p_household uuid,p_description text,p_request uuid,p_wheel text) returns jsonb
language sql security invoker set search_path='' as $$select app_private.log_unexpected_chore_wheel(p_household,p_description,p_request,p_wheel)$$;
revoke all on function app_private.log_unexpected_chore_wheel(uuid,text,uuid,text),public.log_unexpected_chore_wheel(uuid,text,uuid,text) from public,anon;
grant execute on function app_private.log_unexpected_chore_wheel(uuid,text,uuid,text),public.log_unexpected_chore_wheel(uuid,text,uuid,text) to authenticated;
-- Keep existing clients' standard-wheel RPC available, with the same server rules.
create or replace function app_private.log_unexpected_chore(p_household uuid,p_description text,p_request uuid) returns jsonb
language sql security invoker set search_path='' as $$select app_private.log_unexpected_chore_wheel(p_household,p_description,p_request,'standard')$$;
commit;
