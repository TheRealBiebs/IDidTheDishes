begin;
CREATE OR REPLACE FUNCTION app_private.seed_theme_teams(h uuid, t text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 insert into public.household_teams(household_id,name,color,symbol,preset_key)
 select h,x.name,x.color,x.symbol,t||':'||x.key from jsonb_to_recordset(
 case t
 when 'cats' then '[{"key":"whiskers","name":"Whisker Warriors","color":"#d478a0","symbol":"cat"},{"key":"purr","name":"Purr Patrol","color":"#9c83d6","symbol":"paw"},{"key":"claws","name":"Claw Crew","color":"#4baca1","symbol":"cat"},{"key":"naps","name":"Nap Champions","color":"#d2a34f","symbol":"paw"}]'::jsonb
 when 'clean' then '[{"key":"sponges","name":"Sponge Squad","color":"#e5b928","symbol":"sponge"},{"key":"bubbles","name":"Bubble Brigade","color":"#24a8c4","symbol":"bubbles"},{"key":"shine","name":"Shine Team","color":"#9a7dd1","symbol":"star"},{"key":"dust","name":"Dust Busters","color":"#51aa77","symbol":"sponge"}]'::jsonb
 when 'parents' then '[{"key":"mom","name":"Team Mom","color":"#ca7c80","symbol":"heart"},{"key":"dad","name":"Team Dad","color":"#668ea8","symbol":"coffee"},{"key":"helpers","name":"Little Helpers","color":"#89a17a","symbol":"star"},{"key":"family","name":"Family Crew","color":"#c69b58","symbol":"heart"}]'::jsonb
 else '[{"key":"gryffindor","name":"Ember Guild","color":"#ed5255","symbol":"lion"},{"key":"slytherin","name":"Moonstone Circle","color":"#43d3a1","symbol":"snake"},{"key":"ravenclaw","name":"Stormwatch Order","color":"#6b9df5","symbol":"raven"},{"key":"hufflepuff","name":"Sunstone Fellowship","color":"#f1c34f","symbol":"badger"}]'::jsonb end
 ) as x(key text,name text,color text,symbol text) on conflict do nothing;
end $function$

;
-- Keep legacy preset keys/API values so existing memberships and old clients
-- retain their identity. Rename only untouched defaults, never custom teams.
do $$declare r record;candidate text;suffix integer;begin
 for r in select t.id,t.household_id,m.new_name from public.household_teams t join (values
 ('wizard:gryffindor','Gryffindor','Ember Guild'),('wizard:slytherin','Slytherin','Moonstone Circle'),('wizard:ravenclaw','Ravenclaw','Stormwatch Order'),('wizard:hufflepuff','Hufflepuff','Sunstone Fellowship')
 ) m(preset_key,old_name,new_name) on t.preset_key=m.preset_key and lower(trim(t.name))=lower(m.old_name)
 loop
  candidate:=r.new_name;suffix:=2;
  while exists(select 1 from public.household_teams where household_id=r.household_id and id<>r.id and lower(trim(name))=lower(candidate)) loop
   candidate:=r.new_name||' '||suffix;suffix:=suffix+1;
  end loop;
  update public.household_teams set name=candidate where id=r.id;
 end loop;
end $$;
commit;
