export const EXPERIENCE_REWARDS={wizard:'points',parents:'stars',cats:'cats',poker:'poker'}
export const experienceTheme=id=>id==='clean'?'poker':Object.hasOwn(EXPERIENCE_REWARDS,id)?id:'wizard'
export const teamsEnabled=household=>household?.teams_enabled===true
export const rewardForTheme=id=>EXPERIENCE_REWARDS[experienceTheme(id)]
export function competitionEntries({household,teams=[],members=[],scores=[],colors=['#ed5255','#43d3a1','#6b9df5','#f1c34f']}){
  if(teamsEnabled(household))return teams.filter(t=>t.active).map(t=>({...t,count:members.filter(m=>m.team_id===t.id).length,points:scores.filter(s=>members.find(m=>m.user_id===s.user_id)?.team_id===t.id).reduce((n,s)=>n+Number(s.points||0),0)}))
  return members.map((m,i)=>({id:m.user_id,name:m.display_name,color:colors[i%colors.length],symbol:'star',points:Number(scores.find(s=>s.user_id===m.user_id)?.points||0),count:1}))
}
