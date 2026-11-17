begin;
alter table public.chore_tags add column calendar_sticker text not null default 'star' check(calendar_sticker in('star','rainbow','kitty','dog','heart','sun','moon','flower','butterfly','dinosaur','rocket','unicorn','trophy','smiley','clap','fire','gem'));
alter table public.chore_completions add column calendar_sticker text not null default 'star' check(calendar_sticker in('star','rainbow','kitty','dog','heart','sun','moon','flower','butterfly','dinosaur','rocket','unicorn','trophy','smiley','clap','fire','gem'));
create function app_private.snapshot_calendar_sticker() returns trigger
language plpgsql security definer set search_path='' as $$begin
 new.calendar_sticker:=coalesce((select calendar_sticker from public.chore_tags where id=new.tag_id),'star');return new;
end $$;
revoke all on function app_private.snapshot_calendar_sticker() from public,anon,authenticated;
create trigger snapshot_calendar_sticker before insert on public.chore_completions for each row execute function app_private.snapshot_calendar_sticker();
create function app_private.set_calendar_sticker(p_household uuid,p_tag uuid,p_sticker text) returns void
language plpgsql security definer set search_path='' as $$begin
 perform 1 from public.households where id=p_household for no key update;
 if not app_private.is_admin(p_household) then raise exception 'Only household admins can choose chore stickers.';end if;
 if p_sticker is null or p_sticker not in('star','rainbow','kitty','dog','heart','sun','moon','flower','butterfly','dinosaur','rocket','unicorn','trophy','smiley','clap','fire','gem') then raise exception 'Choose a supported calendar sticker.';end if;
 update public.chore_tags set calendar_sticker=p_sticker where id=p_tag and household_id=p_household and deleted_at is null;
 if not found then raise exception 'Chore not found.';end if;
end $$;
revoke all on function app_private.set_calendar_sticker(uuid,uuid,text) from public,anon;
grant execute on function app_private.set_calendar_sticker(uuid,uuid,text) to authenticated;
drop function public.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb);
create function public.save_chore_rewards(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb,p_sticker text default null) returns uuid
language plpgsql security invoker set search_path='' as $$declare result uuid;begin
 result:=app_private.save_chore_rewards(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team,p_adjustments);
 if p_sticker is not null then perform app_private.set_calendar_sticker(p_household,result,p_sticker);end if;return result;
end $$;
drop function public.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb);
create function public.claim_chore_rewards(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb,p_sticker text default null) returns uuid
language plpgsql security invoker set search_path='' as $$declare result uuid;begin
 result:=app_private.claim_chore_rewards(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team,p_adjustments);
 if p_sticker is not null then perform app_private.set_calendar_sticker(p_household,result,p_sticker);end if;return result;
end $$;
revoke all on function public.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb,text),public.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb,text) from public,anon;
grant execute on function public.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb,text),public.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb,text) to authenticated;
create or replace function app_private.reward_calendar(p_household uuid,p_month date) returns jsonb
language plpgsql stable set search_path='' as $$declare start_day date;result jsonb;begin
 if not app_private.is_member(p_household) then raise exception 'Join this household first.';end if;
 if p_month is null then raise exception 'Choose a calendar month.';end if;
 start_day:=date_trunc('month',p_month::timestamp)::date;
 select coalesce(jsonb_agg(to_jsonb(s) order by s.day,s.chore,s.user_id,s.calendar_sticker),'[]'::jsonb) into result from(
 select chore_date as day,tag_id,user_id,chore,calendar_sticker,count(*) as stars from public.chore_completions
 where household_id=p_household and chore_date>=start_day and chore_date<(start_day+interval '1 month')::date
 group by chore_date,tag_id,user_id,chore,calendar_sticker)s;return result;
end $$;
notify pgrst,'reload schema';
commit;
