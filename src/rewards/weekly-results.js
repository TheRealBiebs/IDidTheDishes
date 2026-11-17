export const weeklyWinners=result=>(result?.team_scores||[]).filter(team=>team.winner===true&&Number(team.score)>0)
export const weeklyUnit=(scheme,scores)=>scheme==='cats'?(scores&&scores.every(s=>s.cat_type==null)?'points':'satisfied days'):scheme==='stars'?(scores?.some(s=>s.sticker_days!=null)?'days with stickers':'stickers'):scheme==='adventure'?'chores':'points'
export function weekLabel(start,end){
  const first=new Date(`${start}T12:00:00Z`),last=new Date(`${end}T12:00:00Z`);last.setUTCDate(last.getUTCDate()-1)
  const fmt=new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric',year:'numeric',timeZone:'UTC'})
  return `${fmt.format(first)} – ${fmt.format(last)}`
}
export function weeklyWinnerLabel(result){if(result.reward_scheme==='poker')return 'Your casino week';const winners=weeklyWinners(result);return winners.length?winners.map(t=>t.name).join(' & '):result.reward_scheme==='stars'?'No seven-day sticker streak':'No winner'}
