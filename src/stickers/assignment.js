export function assignmentValue(tag,teamsEnabled){
 const people=tag?.eligible_users||[],team=teamsEnabled&&tag?.assigned_team_id
 if(!people.length)return team?`team:${team}`:'anyone'
 if(people.length===1&&!team)return `person:${people[0]}`
 return 'legacy'
}
export function assignmentFields(value,tag,teamsEnabled){
 if(value==='legacy')return {p_team:teamsEnabled?tag?.assigned_team_id||null:null,p_eligible:tag?.eligible_users||[]}
 if(value.startsWith('team:')&&teamsEnabled)return {p_team:value.slice(5),p_eligible:[]}
 if(value.startsWith('person:'))return {p_team:null,p_eligible:[value.slice(7)]}
 return {p_team:null,p_eligible:[]}
}
export function choreAssignmentLabel(tag,members,teams,teamsEnabled){
 const names=(tag.eligible_users||[]).map(id=>members.find(m=>m.user_id===id)?.display_name||'a household member')
 const team=teamsEnabled&&tag.assigned_team_id?teams.find(t=>t.id===tag.assigned_team_id)?.name||'a team':''
 return `Assigned to ${team?team+(names.length?` (${names.join(', ')})`:''):names.join(', ')||'anyone'}`
}
