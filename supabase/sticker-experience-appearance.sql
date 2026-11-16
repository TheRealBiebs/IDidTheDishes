CREATE OR REPLACE FUNCTION app_private.inspect_sticker(p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare s app_private.sticker_inventory;t public.chore_tags;member boolean;look jsonb;team jsonb;
begin
 select * into s from app_private.sticker_inventory where token=p_token;
 if not found then return jsonb_build_object('status','invalid');end if;
 if s.chore_tag_id is null then return jsonb_build_object('status',case when s.written_at is null then 'preparing' else 'available' end);end if;
 select * into t from public.chore_tags where id=s.chore_tag_id;
 select jsonb_build_object('theme',theme,'reward_scheme',reward_scheme,'teams_enabled',teams_enabled) into look from public.households where id=s.household_id;
 member:=app_private.is_member(s.household_id);
 if member and (select teams_enabled from public.households where id=s.household_id) then
  select jsonb_build_object('name',x.name,'color',x.color,'symbol',x.symbol) into team from public.household_members m join public.household_teams x on x.id=m.team_id and x.household_id=m.household_id where m.household_id=s.household_id and m.user_id=auth.uid();
 end if;
 return jsonb_build_object('status','assigned','chore',t.chore,'member',member,'appearance',look)
  ||case when member then jsonb_build_object('household_id',s.household_id,'admin',app_private.is_admin(s.household_id),'tag',to_jsonb(t),'team',team) else '{}'::jsonb end;
end $function$
;

