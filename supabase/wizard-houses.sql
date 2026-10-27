-- A member chooses a wizarding house independently in each household.
-- Weekly team totals are the sum of server-issued points for current members.
alter table public.household_members add column wizard_house text
  check (wizard_house in ('gryffindor','slytherin','ravenclaw','hufflepuff'));

create function app_private.choose_wizard_house(p_household uuid,p_house text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_house is null or p_house not in ('gryffindor','slytherin','ravenclaw','hufflepuff') then raise exception 'Choose one of the four houses.'; end if;
 update public.household_members set wizard_house=p_house where household_id=p_household and user_id=auth.uid();
 if not found then raise exception 'Join this household before choosing a house.'; end if;
end $$;
revoke all on function app_private.choose_wizard_house(uuid,text) from public,anon;
grant execute on function app_private.choose_wizard_house(uuid,text) to authenticated;
create function public.choose_wizard_house(p_household uuid,p_house text) returns void
language sql security invoker set search_path='' as $$select app_private.choose_wizard_house(p_household,p_house)$$;
revoke all on function public.choose_wizard_house(uuid,text) from public,anon;
grant execute on function public.choose_wizard_house(uuid,text) to authenticated;
