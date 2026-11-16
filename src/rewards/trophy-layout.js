export const TROPHY_SHELVES=[228,155,82]
export const TROPHY_CAPACITY=15
export const MAX_VISIBLE_TROPHIES=75
export const trophyKind=mode=>['stars','parents'].includes(mode)?'stars':mode==='cats'?'cats':mode==='poker'?'poker':'wizard'
export const trophyWord=mode=>({wizard:'cup',poker:'chip trophy',cats:'sleeping cat',stars:'gold star'})[trophyKind(mode)]
const noise=seed=>{const x=Math.sin(seed*127.1+311.7)*43758.5453;return x-Math.floor(x)}
const clamp=(n,a,b)=>Math.min(b,Math.max(a,n))

// Settle a small, bounded soft-body pile on each shelf. Recomputing as a new
// win arrives moves the existing objects too; CSS animates those pushes.
function pile(indices,shelf){
 const floor=TROPHY_SHELVES[shelf],n=indices.length
 if(n<=5)return indices.map((id,i)=>({id,shelf,x:150+(i-(n-1)/2)*52,y:floor,angle:(noise(id+1)-.5)*4}))
 const nodes=indices.map((id,i)=>({id,shelf,x:i<5?46+i*52:38+noise(id+9)*224,y:floor-26-(i<5?0:36*noise(id+7)),vx:0,vy:0}))
 const separation=44-Math.min(9,Math.max(0,n-10)*.7)
 for(let step=0;step<60;step++){
  for(const a of nodes){a.vy=(a.vy+.36)*.85;a.vx*=.75;a.x+=a.vx;a.y+=a.vy}
  for(let iteration=0;iteration<2;iteration++){
   for(let i=0;i<n;i++)for(let j=i+1;j<n;j++){
    const a=nodes[i],b=nodes[j];let dx=b.x-a.x,dy=b.y-a.y
    if(Math.abs(dx)+Math.abs(dy)<.001){dx=.1;dy=-.1}
    const distance=Math.hypot(dx,dy)
    if(distance<separation){const push=(separation-distance)*.3;dx=dx/distance*push;dy=dy/distance*push;a.x-=dx;a.y-=dy;b.x+=dx;b.y+=dy}
   }
   for(const a of nodes){a.x=clamp(a.x,26,274);a.y=clamp(a.y,floor-70,floor-26)}
  }
 }
 const pressure=Math.min(1,(n-5)/9)
 return nodes.map((node,i)=>({id:node.id,shelf,x:node.x,y:node.y+26,angle:(noise(node.id+19)-.5)*(i<5?35:150)*pressure}))
}
export function trophyLayout(wins,{maxVisible=MAX_VISIBLE_TROPHIES}={}){
 const total=Number(wins)
 if(!Number.isSafeInteger(total)||total<0)throw new RangeError('Weekly wins must be a nonnegative safe integer.')
 if(!Number.isInteger(maxVisible)||maxVisible<15||maxVisible>MAX_VISIBLE_TROPHIES)throw new RangeError('Choose a bounded trophy display size.')
 const count=Math.min(total,maxVisible),rows=[[],[],[]]
 for(let i=0;i<count;i++){const shelf=i<15?Math.floor(i/5):(i-15)%3;rows[shelf].push(i)}
 const stage=total===0?'empty':total<=5?'starting':total<=15?'filling':total<=30?'crowded':'overstuffed'
 return {total,hidden:total-count,stage,items:rows.flatMap((indices,shelf)=>pile(indices,shelf)).sort((a,b)=>a.id-b.id)}
}
