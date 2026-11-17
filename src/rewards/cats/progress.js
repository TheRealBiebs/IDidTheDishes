export const CAT_ACTIVITIES=[['feed','Feed',.25],['play','Play',.5],['cuddle','Cuddle',.75]]
export function catProgress(cat){
 const mode=cat?.care_mode||'points',actions=cat?.actions||[],points=Number(cat?.points||0),target=Number(cat?.target||20)
 const activities=CAT_ACTIVITIES.map(([action,label,fraction])=>{
  const saved=cat?.activities?.find(a=>a.action===action)
  return {action,label,fraction,chore:saved?.chore||'Choose a chore',unlocked:saved?saved.unlocked===true:mode==='points'&&points>=target*fraction,done:actions.includes(action)}
 })
 const satisfied=cat?.satisfied??(mode==='chores'?activities.every(a=>a.unlocked):points>=target)
 const value=mode==='chores'?activities.filter(a=>a.unlocked).length:Math.min(points,target),maximum=mode==='chores'?3:target
 return {mode,activities,satisfied,sleeping:satisfied&&activities.every(a=>a.done),value,maximum}
}
export function catDaylight(now=new Date(),timeZone){
 let hour
 try{hour=Number(new Intl.DateTimeFormat('en-GB',{timeZone,hour:'numeric',hourCycle:'h23'}).format(now))}catch{hour=now.getUTCHours()}
 return {hour,night:hour<6||hour>=18}
}
