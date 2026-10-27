alter table public.households add column theme text not null default 'wizard'
 check(theme in ('wizard','cats','clean','parents'));
create table public.household_teams (
 id uuid primary key default gen_random_uuid(),
 household_id uuid not null references public.households on delete cascade,
 name text not null check(length(trim(name)) between 1 and 40),
 color text not null check(color ~ '^#[0-9a-fA-F]{6}$'),
 symbol text not null default 'star' check(symbol in ('lion','snake','raven','badger','cat','paw','sponge','bubbles','heart','coffee','star')),
 preset_key text,
 active boolean not null default true,
 created_at timestamptz not null default now(),
 unique(household_id,id),unique(household_id,preset_key)
);
create unique index team_name_unique on public.household_teams(household_id,lower(trim(name)));
alter table public.household_teams enable row level security;
revoke all on public.household_teams from anon,authenticated;
grant select on public.household_teams to authenticated;
create policy team_read on public.household_teams for select to authenticated using(app_private.is_member(household_id));
alter table public.household_members add column team_id uuid;
alter table public.household_members add constraint membership_team_same_household foreign key(household_id,team_id) references public.household_teams(household_id,id);
create index membership_team_idx on public.household_members(household_id,team_id);

create function app_private.seed_theme_teams(h uuid,t text) returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.household_teams(household_id,name,color,symbol,preset_key)
 select h,x.name,x.color,x.symbol,t||':'||x.key from jsonb_to_recordset(
 case t
 when 'cats' then '[{"key":"whiskers","name":"Whisker Warriors","color":"#d478a0","symbol":"cat"},{"key":"purr","name":"Purr Patrol","color":"#9c83d6","symbol":"paw"},{"key":"claws","name":"Claw Crew","color":"#4baca1","symbol":"cat"},{"key":"naps","name":"Nap Champions","color":"#d2a34f","symbol":"paw"}]'::jsonb
 when 'clean' then '[{"key":"sponges","name":"Sponge Squad","color":"#e5b928","symbol":"sponge"},{"key":"bubbles","name":"Bubble Brigade","color":"#24a8c4","symbol":"bubbles"},{"key":"shine","name":"Shine Team","color":"#9a7dd1","symbol":"star"},{"key":"dust","name":"Dust Busters","color":"#51aa77","symbol":"sponge"}]'::jsonb
 when 'parents' then '[{"key":"mom","name":"Team Mom","color":"#ca7c80","symbol":"heart"},{"key":"dad","name":"Team Dad","color":"#668ea8","symbol":"coffee"},{"key":"helpers","name":"Little Helpers","color":"#89a17a","symbol":"star"},{"key":"family","name":"Family Crew","color":"#c69b58","symbol":"heart"}]'::jsonb
 else '[{"key":"gryffindor","name":"Gryffindor","color":"#ed5255","symbol":"lion"},{"key":"slytherin","name":"Slytherin","color":"#43d3a1","symbol":"snake"},{"key":"ravenclaw","name":"Ravenclaw","color":"#6b9df5","symbol":"raven"},{"key":"hufflepuff","name":"Hufflepuff","color":"#f1c34f","symbol":"badger"}]'::jsonb end
 ) as x(key text,name text,color text,symbol text) on conflict do nothing;
end $$;
select app_private.seed_theme_teams(id,theme) from public.households;
update public.household_members m set team_id=t.id from public.household_teams t where t.household_id=m.household_id and t.preset_key='wizard:'||m.wizard_house;

create function app_private.seed_new_household() returns trigger language plpgsql security definer set search_path='' as $$
begin perform app_private.seed_theme_teams(new.id,new.theme); return new; end $$;
create trigger seed_household_teams after insert on public.households for each row execute function app_private.seed_new_household();

create function app_private.set_household_theme(p_household uuid,p_theme text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can change its theme.'; end if;
 if p_theme is null or p_theme not in ('wizard','cats','clean','parents') then raise exception 'Choose a supported theme.'; end if;
 update public.households set theme=p_theme where id=p_household;
end $$;
create function app_private.add_theme_teams(p_household uuid) returns void language plpgsql security definer set search_path='' as $$
declare t text;
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can add teams.'; end if;
 select theme into t from public.households where id=p_household for update;
 if (select count(*) from public.household_teams where household_id=p_household)>16 then raise exception 'A household can have up to 20 teams. Rename existing teams instead.'; end if;
 perform app_private.seed_theme_teams(p_household,t);
end $$;
create function app_private.save_team(p_household uuid,p_team uuid,p_name text,p_color text,p_symbol text,p_active boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not app_private.is_owner(p_household) then raise exception 'Only the household owner can edit teams.'; end if;
 perform 1 from public.households where id=p_household for update;
 if p_team is null then
  if (select count(*) from public.household_teams where household_id=p_household)>=20 then raise exception 'A household can have up to 20 teams.'; end if;
  insert into public.household_teams(household_id,name,color,symbol,active) values(p_household,trim(p_name),p_color,p_symbol,p_active) returning id into result;
 else
  perform 1 from public.household_teams where household_id=p_household and id=p_team for update;
  if not found then raise exception 'Team not found in this household.'; end if;
  if not p_active and exists(select 1 from public.household_members where household_id=p_household and team_id=p_team) then raise exception 'Move this team’s members to another team before archiving it.'; end if;
  update public.household_teams set name=trim(p_name),color=p_color,symbol=p_symbol,active=p_active where household_id=p_household and id=p_team returning id into result;
 end if;
 return result;
 exception when unique_violation then raise exception 'A team with that name already exists in this household.';
end $$;
create function app_private.choose_team(p_household uuid,p_team uuid,p_user uuid default null) returns void language plpgsql security definer set search_path='' as $$
declare target uuid:=coalesce(p_user,auth.uid()); legacy text;
begin
 if not app_private.is_member(p_household) then raise exception 'Join this household before choosing a team.'; end if;
 if target<>auth.uid() and not app_private.is_owner(p_household) then raise exception 'Only the owner can move other members between teams.'; end if;
 -- Serialize team membership changes with archiving/configuration.
 perform 1 from public.households where id=p_household for update;
 if p_team is not null then
  select replace(preset_key,'wizard:','') into legacy from public.household_teams where household_id=p_household and id=p_team and active;
  if not found then raise exception 'Choose an active team in this household.'; end if;
 end if;
 update public.household_members set team_id=p_team,wizard_house=case when legacy in ('gryffindor','slytherin','ravenclaw','hufflepuff') then legacy else null end where household_id=p_household and user_id=target;
 if not found then raise exception 'Member not found in this household.'; end if;
end $$;
create or replace function app_private.choose_wizard_house(p_household uuid,p_house text) returns void language plpgsql security definer set search_path='' as $$
declare team uuid;
begin
 select id into team from public.household_teams where household_id=p_household and preset_key='wizard:'||p_house and active;
 if team is null then raise exception 'Choose a team from the current household settings.'; end if;
 perform app_private.choose_team(p_household,team,null);
end $$;

create function app_private.create_themed_household(p_name text,p_display_name text,p_timezone text,p_theme text) returns uuid language plpgsql security definer set search_path='' as $$
declare h uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_theme is null or p_theme not in ('wizard','cats','clean','parents') then raise exception 'Choose a supported theme.'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'Choose a valid time zone.'; end if;
 if (select count(*) from public.household_members where user_id=auth.uid() and role='owner')>=10 then raise exception 'You can own up to 10 households.'; end if;
 insert into public.households(name,timezone,theme) values(trim(p_name),p_timezone,p_theme) returning id into h;
 insert into public.household_members(household_id,user_id,display_name,role) values(h,auth.uid(),trim(p_display_name),'owner');
 insert into app_private.household_invites(household_id) values(h);
 return h;
end $$;

revoke all on function app_private.seed_theme_teams(uuid,text),app_private.seed_new_household() from public,anon,authenticated;
revoke all on function app_private.set_household_theme(uuid,text),app_private.add_theme_teams(uuid),app_private.save_team(uuid,uuid,text,text,text,boolean),app_private.choose_team(uuid,uuid,uuid),app_private.create_themed_household(text,text,text,text) from public,anon;
grant execute on function app_private.set_household_theme(uuid,text),app_private.add_theme_teams(uuid),app_private.save_team(uuid,uuid,text,text,text,boolean),app_private.choose_team(uuid,uuid,uuid),app_private.create_themed_household(text,text,text,text) to authenticated;
create function public.set_household_theme(p_household uuid,p_theme text) returns void language sql security invoker set search_path='' as $$select app_private.set_household_theme(p_household,p_theme)$$;
create function public.add_theme_teams(p_household uuid) returns void language sql security invoker set search_path='' as $$select app_private.add_theme_teams(p_household)$$;
create function public.save_team(p_household uuid,p_team uuid,p_name text,p_color text,p_symbol text,p_active boolean) returns uuid language sql security invoker set search_path='' as $$select app_private.save_team(p_household,p_team,p_name,p_color,p_symbol,p_active)$$;
create function public.choose_team(p_household uuid,p_team uuid,p_user uuid default null) returns void language sql security invoker set search_path='' as $$select app_private.choose_team(p_household,p_team,p_user)$$;
create function public.create_themed_household(p_name text,p_display_name text,p_timezone text,p_theme text) returns uuid language sql security invoker set search_path='' as $$select app_private.create_themed_household(p_name,p_display_name,p_timezone,p_theme)$$;
revoke all on function public.set_household_theme(uuid,text),public.add_theme_teams(uuid),public.save_team(uuid,uuid,text,text,text,boolean),public.choose_team(uuid,uuid,uuid),public.create_themed_household(text,text,text,text) from public,anon;
grant execute on function public.set_household_theme(uuid,text),public.add_theme_teams(uuid),public.save_team(uuid,uuid,text,text,text,boolean),public.choose_team(uuid,uuid,uuid),public.create_themed_household(text,text,text,text) to authenticated;
alter publication supabase_realtime add table public.household_teams,public.households;
