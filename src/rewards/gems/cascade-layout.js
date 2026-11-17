const noise=seed=>{const n=Math.sin(seed*127.1+311.7)*43758.5453;return n-Math.floor(n)}
export const visibleWinners=entries=>entries.slice(0,3)
export function cascadeStones(points,{recap=false,seed=1}={}){
 if(!Number.isFinite(Number(points))||!(Number(points)>0))return []
 const count=recap?32:Math.min(30,Math.max(10,Math.ceil(Math.sqrt(Number(points))*5)))
 const proportion=Math.min(Number(points)/Math.max(40,Math.ceil(Number(points)/20)*40),1)
 return Array.from({length:count},(_,i)=>{
  const n=noise(i+seed*53),direction=i%2?1:-1
  return {id:i,delay:recap ? .13+i*.022 : i*.045,size:(recap?13:11)+n*7,start:(noise(i+12)-.5)*(recap?35:55),end:(noise(i+27)-.5)*35,
   landing:174-(i+1)/count*174*proportion,arc:direction*(22+n*65),spread:direction*(45+noise(i+31)*75),lift:-(45+noise(i+17)*35),spin:direction*(180+n*320),turn:(i*67)%180,duration:recap?2.35+n*.35:.86+n*.18}
 })
}
