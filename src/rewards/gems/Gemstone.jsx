export function gemPalette(value){
 const color=/^#[0-9a-f]{6}$/i.test(value||'')?value:'#54cba0'
 const rgb=color.slice(1).match(/../g).map(v=>parseInt(v,16))
 const hex=values=>'#'+values.map(v=>Math.round(v).toString(16).padStart(2,'0')).join('')
 return {color,light:hex(rgb.map(v=>v+(255-v)*.68)),shadow:hex(rgb.map(v=>v*.42))}
}

// Shared by the dashboard pile and animated stones: the same cut and lighting.
export function GemFacet({color,light,shadow,variant=0,detailed=false}){
 const palette=gemPalette(color),bright=light||palette.light,dark=shadow||palette.shadow
 if(!detailed)return <><path d="M0 4 4 0 11 0 16 4 10 11 5 11Z" fill={palette.color}/><path d="m0 4 7-1 9 1-6 7Z" fill={bright} opacity={.25+(variant%4)*.13}/><path d="M4 0 7 3 0 4m7-1 3 8 6-7M7 3l4-3" fill="none" stroke={bright} strokeOpacity=".7" strokeWidth=".55"/></>
 return <>
  <path d={variant%3===1?'M1 3 5 0 12 1 16 5 11 11 4 10 0 6Z':variant%3===2?'M0 4 3 1 10 0 16 4 12 10 6 11Z':'M0 4 4 0 11 0 16 4 10 11 5 11Z'} fill={palette.color}/>
  <path d="M0 4 7 3 5 10Z" fill={bright} opacity=".72"/>
  <path d="m4 0 7 0-4 3-7 1Z" fill={bright} opacity=".9"/>
  <path d="m7 3 9 1-6 7Z" fill={dark} opacity=".76"/>
  <path d="m0 4 5 7 5 0-3-8Z" fill={palette.color}/>
  <path d="m7 3 3 8-5-1Z" fill={bright} opacity=".27"/>
  <path d="M4 0 7 3 0 4m7-1 3 8 6-7M7 3l4-3" fill="none" stroke={bright} strokeOpacity=".8" strokeWidth=".5" strokeLinejoin="round"/>
  <path d="m4.5 1 5-.15M1.8 4.5l2 3.7" stroke="#fff" strokeOpacity=".7" strokeWidth=".55" strokeLinecap="round"/>
 </>
}
export default function Gemstone({color,variant=0}){
 return <svg className="cascade-gemstone" viewBox="-1 -1 18 13" aria-hidden="true"><GemFacet color={color} variant={variant} detailed/></svg>
}
