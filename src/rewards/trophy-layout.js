import {pokerChips} from './poker-chips.js'
export const TROPHY_SHELVES=[330,220,110]
export const TROPHY_CAPACITY=15
export const MAX_VISIBLE_TROPHIES=75
export const trophyKind=mode=>['stars','parents'].includes(mode)?'stars':mode==='cats'?'cats':mode==='poker'?'poker':'wizard'
export const trophyWord=mode=>({wizard:'cup',poker:'chip stack',cats:'sleeping cat',stars:'glass sticker'})[trophyKind(mode)]
export const cabinetStage=total=>total===0?'empty':total<=5?'starting':total<=15?'filling':total<=30?'crowded':'overstuffed'
export function chipPileParts(total,limit=75){
 if(!Number.isSafeInteger(total)||total<0)throw new RangeError('Choose an exact nonnegative chip total.')
 const denominations=pokerChips(total).filter(c=>c.count),count=denominations.reduce((n,c)=>n+c.count,0)
 // Reserve space for denomination remainders, then bound stacks without rounding
 // or dropping a single chip. Very large banks have denser, taller stacks.
 const perStack=Math.max(20,Math.ceil(count/Math.max(1,limit-denominations.length))),parts=[]
 for(const chip of denominations)for(let remaining=chip.count;remaining>0;remaining-=perStack){const layers=Math.min(perStack,remaining);parts.push({part:parts.length,layers,value:chip.value,color:chip.color,ink:chip.ink,w:30,h:Math.min(90,8+layers*2.4)})}
 return {stacks:parts.length,hidden:0,parts}

}
function validateLimit(n){if(!Number.isInteger(n)||n<15||n>75)throw new RangeError('Choose a bounded trophy display size.')}
function supportedPosition(item,placed){
 let best=null
 for(let x=Math.ceil(9+item.w/2);x<=291-item.w/2;x++){
  let y=102
  for(const p of placed)if(Math.abs(x-p.x)<(item.w+p.w)/2+1)y=Math.min(y,p.localY-p.h)
  if(y-item.h<8)continue
  // A stack's center of mass must lie over a supporting object's top.
  if(y<102&&!placed.some(p=>Math.abs(y-(p.localY-p.h))<.001&&Math.abs(x-p.x)<=p.w/2-1))continue
  if(!best||y>best.localY+.001||Math.abs(y-best.localY)<.001&&Math.abs(x-150)<Math.abs(best.x-150))best={x,localY:y}
 }
 return best
}
export function cabinetLayout(trophies,{maxVisible=75}={}){
 validateLimit(maxVisible)
 const groups={wizard:[],cats:[],poker:[]};let intended=0
 trophies.forEach((t,index)=>{const group=trophyKind(t.mode);if(group==='stars')return
  if(group==='poker'){if(t.kind!=='poker_bank')return;const bank=chipPileParts(Number(t.bank_total||0),maxVisible);intended+=bank.stacks;groups.poker.push(...bank.parts.map(p=>({...p,index,group,key:t.id+':'+p.part})));return}
  intended++;if(groups[group].length<maxVisible)groups[group].push({index,id:index,key:t.id||String(index),group,w:group==='cats'?38:34,h:group==='cats'?30:38})
 })
 const items=[];let shelf=-1
 for(const [group,parts] of Object.entries(groups)){
  if(!parts.length)continue;shelf++;let placed=[]
  for(const item of parts){if(items.filter(i=>i.group!=='poker').length>=maxVisible&&group!=='poker')break;let position=supportedPosition(item,placed);if(!position){shelf++;placed=[];position=supportedPosition(item,placed)}const p={...item,...position,shelf,angle:0};placed.push(p);items.push(p)}
 }
 const shelves=Math.max(3,shelf+1),height=shelves*110+10
 return {total:trophies.length,stage:cabinetStage(trophies.length),hidden:Math.max(0,intended-items.length),shelves: Array.from({length:shelves},(_,i)=>(shelves-i)*110),height,width:300,items:items.map(p=>({...p,id:p.index,y:(shelves-1-p.shelf)*110+p.localY+8}))}
}
export function trophyLayout(wins,{maxVisible=75}={}){
 if(!Number.isSafeInteger(wins)||wins<0)throw new RangeError('Weekly wins must be a nonnegative safe integer.')
 const result=cabinetLayout(Array.from({length:Math.min(wins,maxVisible)},(_,id)=>({id:String(id),mode:'points'})),{maxVisible})
 return {...result,total:wins,stage:cabinetStage(wins),hidden:Math.max(0,wins-result.items.length)}
}
