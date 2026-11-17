export const RED_NUMBERS=[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]
export const WHEEL_ORDER=[0,28,9,26,30,11,7,20,32,17,5,22,34,15,3,24,36,13,1,37,27,10,25,29,12,8,19,31,18,6,21,33,16,4,23,35,14,2]
export const pocketLabel=n=>Number(n)===37?'00':String(n)
export const pocketColor=n=>n===0||n===37?'green':RED_NUMBERS.includes(n)?'red':'black'
export const betKey=bet=>bet.kind+':'+[...(bet.numbers||[])].sort((a,b)=>a-b).join(',')
export const betLabel=bet=>({red:'Red',black:'Black',even:'Even',odd:'Odd',low:'1–18',high:'19–36',dozen1:'1st 12',dozen2:'2nd 12',dozen3:'3rd 12',column1:'Column 1',column2:'Column 2',column3:'Column 3',basket:'0 / 00 / 1 / 2 / 3'}[bet.kind]||`${bet.kind[0].toUpperCase()+bet.kind.slice(1)} ${bet.numbers.map(pocketLabel).join(' / ')}`)
export function insideBet(kind,first,second){
 if(kind==='straight')return {kind,numbers:[first]}
 if(kind==='split'){
  if(second==null)return null
  const nums=[first,second].sort((a,b)=>a-b),[a,b]=nums
  const zeros=[[0,37],[0,1],[0,2],[2,37],[3,37]]
  return a!==b&&(zeros.some(pair=>pair[0]===a&&pair[1]===b)||(a>=1&&b<=36&&(b-a===3||(b-a===1&&Math.floor((a-1)/3)===Math.floor((b-1)/3)))))?{kind,numbers:nums}:null
 }
 if(first<1||first>36)return null
 const row=Math.floor((first-1)/3),column=(first-1)%3,start=row*3+1
 if(kind==='street')return {kind,numbers:[start,start+1,start+2]}
 if(kind==='corner'&&column<2&&row<11)return {kind,numbers:[first,first+1,first+3,first+4]}
 if(kind==='sixline'&&row<11)return {kind,numbers:Array.from({length:6},(_,i)=>start+i)}
 return null
}
export const betStake=bets=>bets.reduce((sum,b)=>sum+Number(b.amount),0)
export function rouletteReturn(bet,outcome){
 const n=Number(outcome),numbers=bet.numbers||[],inside={straight:36,split:18,street:12,trio:12,corner:9,sixline:6,basket:7}
 if(inside[bet.kind])return numbers.includes(n)?bet.amount*inside[bet.kind]:0
 if(n===0||n===37)return 0
 const wins={red:RED_NUMBERS.includes(n),black:!RED_NUMBERS.includes(n),even:n%2===0,odd:n%2===1,low:n<=18,high:n>=19,dozen1:n<=12,dozen2:n>=13&&n<=24,dozen3:n>=25,column1:n%3===1,column2:n%3===2,column3:n%3===0}
 return wins[bet.kind]?bet.amount*(bet.kind.startsWith('dozen')||bet.kind.startsWith('column')?3:2):0
}

export function wheelAngles(outcome){const offset=(WHEEL_ORDER.indexOf(outcome)*17)%360;return {wheel:1800+offset,ball:-2880+offset+(WHEEL_ORDER.indexOf(outcome)+.5)*360/38}}
