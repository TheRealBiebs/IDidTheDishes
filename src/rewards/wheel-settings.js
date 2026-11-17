export const WHEEL_TYPES=[['standard','Unexpected chore'],['low','Low-effort chore'],['high','High-effort chore']]
export const DEFAULT_WHEELS={standard:{enabled:true,values:[0,1,2,3]},low:{enabled:false,values:[0,1,1,2]},high:{enabled:false,values:[2,3,4,5]}}
export const randomChoresAvailable=household=>!(household?.reward_scheme==='cats'&&household?.cat_care_mode==='chores')
export function wheelSettings(household){return Object.fromEntries(WHEEL_TYPES.map(([id])=>[id,{...DEFAULT_WHEELS[id],...household?.unexpected_wheels?.[id]}]))}
export function wheelRotation(index,count){if(!Number.isInteger(index)||!Number.isInteger(count)||count<2||count>20||index<0||index>=count)throw Error('The server returned an invalid wheel result. Retry the same submission.');return 8*360-index*360/count}
