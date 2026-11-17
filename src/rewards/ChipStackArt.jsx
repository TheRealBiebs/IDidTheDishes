import {useId} from 'react'

// Every edge is one real chip. Large counts share a repeated SVG pattern rather
// than creating an unbounded number of DOM nodes; the denomination never changes.
export default function ChipStackArt({layers=1,value=100,color='#252a32',ink='#fff7ed'}){
 const id=useId().replace(/:/g,''),step=2.4,body=layers*step,H=body+8
 return <svg viewBox={`0 0 30 ${H}`} preserveAspectRatio="none" className="trophy-art trophy-art-chip-stack realistic-chip-stack" aria-hidden="true" data-chip-count={layers} data-chip-value={value} style={{height:'100%'}}>
  <defs>
   <linearGradient id={id+'-side'}><stop stopColor="#000" stopOpacity=".45"/><stop offset=".3" stopColor="#fff" stopOpacity=".2"/><stop offset=".65" stopColor="#000" stopOpacity=".1"/><stop offset="1" stopColor="#000" stopOpacity=".55"/></linearGradient>
   <linearGradient id={id+'-top'} x2="0" y2="1"><stop stopColor="#fff" stopOpacity=".5"/><stop offset=".5" stopColor="#fff" stopOpacity="0"/><stop offset="1" stopColor="#000" stopOpacity=".2"/></linearGradient>
   <pattern id={id+'-edges'} width="30" height={step} y="4" patternUnits="userSpaceOnUse"><rect width="30" height={step} fill={color}/><path d="M4 0h4v2.1H4Zm12 0h4v2.1h-4Zm10 0h3v2.1h-3Z" fill="#f8f3df"/><path d="M0 2.15h30" stroke="#000" strokeOpacity=".6" strokeWidth=".35"/><path d="M0 .25h30" stroke="#fff" strokeOpacity=".28" strokeWidth=".25"/></pattern>
   <clipPath id={id+'-clip'}><path d={`M1 4h28v${body}c0 4-28 4-28 0Z`}/></clipPath>
  </defs>
  <ellipse cx="15" cy={H-2} rx="14" ry="2" fill="#000" opacity=".4"/>
  <ellipse cx="15" cy={4+body} rx="14" ry="3" fill={color}/><g clipPath={`url(#${id}-clip)`}><rect x="1" y="4" width="28" height={body} fill={`url(#${id}-edges)`}/><rect x="1" y="4" width="28" height={body+4} fill={`url(#${id}-side)`}/></g>
  <ellipse cx="15" cy="4" rx="14" ry="4" fill={color} stroke="#f8f3df" strokeWidth="1.2" strokeDasharray="6 6"/>
  <ellipse cx="15" cy="4" rx="10.5" ry="2.8" fill={color} stroke={ink} strokeOpacity=".55" strokeWidth=".4"/>
  <ellipse cx="15" cy="4" rx="14" ry="4" fill={`url(#${id}-top)`}/>
  <text x="15" y="8.8" textAnchor="middle" transform="scale(1 .55)" fill={ink} fontFamily="system-ui,sans-serif" fontWeight="800" fontSize="6">{value}</text>
 </svg>
}
