export const weeklyWinners=result=>(result?.team_scores||[]).filter(team=>team.winner===true&&Number(team.score)>0)
export const weeklyUnit=scheme=>scheme==='points'?'points':scheme==='stars'?'stars':'chores'
export function weekLabel(start,end){
  const first=new Date(`${start}T12:00:00Z`),last=new Date(`${end}T12:00:00Z`);last.setUTCDate(last.getUTCDate()-1)
  const fmt=new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric',year:'numeric',timeZone:'UTC'})
  return `${fmt.format(first)} – ${fmt.format(last)}`
}
export function weeklyWinnerLabel(result){const winners=weeklyWinners(result);return winners.length?winners.map(t=>t.name).join(' & '):'No team winner'}
