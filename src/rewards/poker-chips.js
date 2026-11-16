export const POKER_CHIPS=[
  {value:1,name:'white',color:'#efeee4',ink:'#26382f'},
  {value:5,name:'red',color:'#c9474d',ink:'#fff7ed'},
  {value:10,name:'blue',color:'#376fc1',ink:'#ffffff'},
  {value:25,name:'green',color:'#27865b',ink:'#ffffff'},
  {value:100,name:'black',color:'#252a32',ink:'#fff7ed'},
]

// Use the fewest chips for these denominations, without rounding away points.
export function pokerChips(points=0){
  let remaining=Number(points)
  if(!Number.isSafeInteger(remaining)||remaining<0)throw new RangeError('Poker points must be a nonnegative safe integer.')
  const counts=new Map()
  for(const chip of [...POKER_CHIPS].reverse()){
    const count=Math.floor(remaining/chip.value)
    counts.set(chip.value,count);remaining-=count*chip.value
  }
  return POKER_CHIPS.map(chip=>({...chip,count:counts.get(chip.value)}))
}
export function pokerChipLabel(points){
  const chips=pokerChips(points).filter(chip=>chip.count>0)
  return chips.length?`${points} points: ${chips.map(chip=>`${chip.count} ${chip.name} chip${chip.count===1?'':'s'} worth ${chip.value} each`).join(', ')}`:'0 points: no chips yet'
}
