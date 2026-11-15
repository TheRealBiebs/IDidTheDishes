begin;
create function app_private.valid_trait_adjustments(p_rules jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare pair record;
begin
 if p_rules is null or jsonb_typeof(p_rules)<>'object' then return false;end if;
 for pair in select * from jsonb_each(p_rules) loop
  if pair.key not in('shabbily','good_enough','perfection','maintenance','standard','disaster') or jsonb_typeof(pair.value)<>'number' or pair.value::text!~'^-?[0-9]+$' then return false;end if;
  if pair.value::text::numeric not between -1000 and 1000 then return false;end if;
 end loop;
 return true;
end $$;
revoke all on function app_private.valid_trait_adjustments(jsonb) from public,anon,authenticated;
alter table public.chore_tags add column trait_adjustments jsonb not null default '{}' check(app_private.valid_trait_adjustments(trait_adjustments));
alter table public.chore_completions add column base_points integer;
alter table public.chore_completions add column trait_adjustments jsonb not null default '{}' check(app_private.valid_trait_adjustments(trait_adjustments));
update public.chore_completions set base_points=points;
alter table public.chore_completions alter column base_points set not null;
alter table public.chore_completions add constraint completion_base_points_valid check(base_points between 0 and 1000);

create function app_private.trait_reward_points(p_base integer,p_rules jsonb,p_quality text,p_condition text) returns integer
language sql immutable set search_path='' as $$select greatest(0,p_base+coalesce((p_rules->>p_quality)::integer,0)+coalesce((p_rules->>p_condition)::integer,0))$$;
revoke all on function app_private.trait_reward_points(integer,jsonb,text,text) from public,anon,authenticated;

create function app_private.snapshot_chore_rewards() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.completion_kind='tag' then
  select points,trait_adjustments into new.base_points,new.trait_adjustments from public.chore_tags where id=new.tag_id;
  if not found then raise exception 'Chore not found.';end if;
 else
  new.base_points:=new.points;new.trait_adjustments:='{}';
 end if;
 new.points:=app_private.trait_reward_points(new.base_points,new.trait_adjustments,new.quality,new.starting_condition);
 return new;
end $$;
revoke all on function app_private.snapshot_chore_rewards() from public,anon,authenticated;
create trigger snapshot_chore_rewards before insert on public.chore_completions for each row execute function app_private.snapshot_chore_rewards();

create function app_private.save_chore_rewards(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not app_private.valid_trait_adjustments(p_adjustments) then raise exception 'Use whole-number point adjustments from -1000 to 1000 for supported traits.';end if;
 result:=app_private.save_scheduled_chore(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team);
 update public.chore_tags set trait_adjustments=p_adjustments where id=result;
 return result;
end $$;
create function public.save_chore_rewards(p_household uuid,p_tag uuid,p_chore text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb) returns uuid language sql security invoker set search_path='' as $$select app_private.save_chore_rewards(p_household,p_tag,p_chore,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team,p_adjustments)$$;
revoke all on function app_private.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb),public.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb) from public,anon;
grant execute on function app_private.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb),public.save_chore_rewards(uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb) to authenticated;

create function app_private.claim_chore_rewards(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not app_private.valid_trait_adjustments(p_adjustments) then raise exception 'Use whole-number point adjustments from -1000 to 1000 for supported traits.';end if;
 result:=app_private.claim_scheduled_sticker(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team);
 update public.chore_tags set trait_adjustments=p_adjustments where id=result;
 return result;
end $$;
create function public.claim_chore_rewards(p_token uuid,p_household uuid,p_chore uuid,p_name text,p_location text,p_points integer,p_limit integer,p_eligible uuid[],p_active boolean,p_cooldown_minutes integer,p_frequency text,p_team uuid,p_adjustments jsonb) returns uuid language sql security invoker set search_path='' as $$select app_private.claim_chore_rewards(p_token,p_household,p_chore,p_name,p_location,p_points,p_limit,p_eligible,p_active,p_cooldown_minutes,p_frequency,p_team,p_adjustments)$$;
revoke all on function app_private.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb),public.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb) from public,anon;
grant execute on function app_private.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb),public.claim_chore_rewards(uuid,uuid,uuid,text,text,integer,integer,uuid[],boolean,integer,text,uuid,jsonb) to authenticated;

create or replace function app_private.save_chore_details(p_completion uuid,p_quality text,p_condition text,p_comment text,p_photo_path text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.chore_completions;archived public.household_week_results;raw_scores jsonb;
begin
 select * into c from public.chore_completions where id=p_completion;
 if c.id is null or auth.uid() is null or c.user_id<>auth.uid() or not app_private.is_member(c.household_id) then raise exception 'Only the member who logged this chore can add its details.';end if;
 perform 1 from public.households where id=c.household_id for no key update;
 select * into c from public.chore_completions where id=p_completion for update;
 if c.id is null or c.user_id<>auth.uid() or not app_private.is_member(c.household_id) then raise exception 'Only the member who logged this chore can add its details.';end if;
 if p_quality is not null and p_quality not in('shabbily','good_enough','perfection') then raise exception 'Choose a supported quality rating.';end if;
 if p_condition is not null and p_condition not in('maintenance','standard','disaster') then raise exception 'Choose a supported starting condition.';end if;
 if length(p_comment)>2000 then raise exception 'Comments can contain up to 2000 characters.';end if;
 if p_photo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='chore-proof' and o.name=p_photo_path and o.owner_id=auth.uid()::text and split_part(o.name,'/',1)=c.household_id::text and split_part(o.name,'/',2)=auth.uid()::text and split_part(o.name,'/',3)=c.id::text) then raise exception 'Upload photo proof for this completion first.';end if;
 update public.chore_completions set quality=p_quality,starting_condition=p_condition,comment=nullif(trim(p_comment),''),proof_path=p_photo_path,details_updated_at=now(),points=app_private.trait_reward_points(c.base_points,c.trait_adjustments,p_quality,p_condition) where id=c.id returning * into c;
 for archived in select w.* from public.household_week_results w where w.household_id=c.household_id and exists(select 1 from public.weekly_result_chores wc where wc.result_id=w.id and wc.completion_id=c.id) for update loop
  update public.weekly_result_chores set details=details||to_jsonb(c),proof_path=c.proof_path where result_id=archived.id and completion_id=c.id;
  select coalesce(jsonb_agg(team||jsonb_build_object('points',points,'chores',chores)),'[]') into raw_scores from (
   select t.value as team,coalesce(sum((wc.details->>'points')::bigint),0) as points,count(wc.completion_id) as chores from jsonb_array_elements(archived.team_scores) t left join public.weekly_result_chores wc on wc.result_id=archived.id and wc.team_id::text=t.value->>'team_id' group by t.value
  ) totals;
  update public.household_week_results set team_scores=app_private.rank_week_teams(raw_scores,archived.reward_scheme) where id=archived.id;
 end loop;
 return to_jsonb(c);
end $$;
notify pgrst, 'reload schema';
commit;
