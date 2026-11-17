import {catType} from './catalog'
export default function CatArt({type=0,sleeping=false,pose='',label,small=false}){
 const [breed,fur,mark,pattern]=catType(type),asleep=sleeping||pose==='sleep',ears=pattern==='fold'
 return <svg viewBox={small?"0 0 200 145":"0 0 200 160"} preserveAspectRatio={small?"none":undefined} className={`companion-cat cat-pose-${pose||'idle'} ${small?'cat-small trophy-art':''}`} role={label?'img':undefined} aria-label={label||undefined} aria-hidden={!label}>
  <ellipse cx="101" cy="144" rx="74" ry="10" fill="#75586c" opacity=".16"/>
  <g className="cat-body"><path d="M151 110q42-43 31-61-7-10-13 1-6 13 5 20 4 14-22 24" fill="none" stroke={fur} strokeWidth="17" strokeLinecap="round"/>
  <ellipse cx="112" cy="107" rx="55" ry="35" fill={fur}/>
  {pattern==='longhair'&&<path d="m57 97-12 5 12 6-8 9 13-1-4 13 15-5 4 15 10-10 12 11 7-12 13 10 9-12 12 9 4-14 15 3-6-13" fill={fur}/>}
  {['stripes','longhair'].includes(pattern)&&<g stroke={mark} strokeWidth="6" strokeLinecap="round" opacity=".6"><path d="m99 78-3 15m20-17-2 14m19-9-5 13m18 0-9 9"/></g>}
  {['calico','patches'].includes(pattern)&&<><ellipse cx="130" cy="98" rx="24" ry="21" fill={mark}/><ellipse cx="98" cy="112" rx="20" ry="25" fill={pattern==='calico'?'#66606a':mark}/></>}
  {pattern==='spots'&&<g fill={mark} opacity=".75">{[[100,88],[123,90],[142,105],[110,112],[130,123],[86,119]].map(([x,y])=><ellipse key={x} cx={x} cy={y} rx="5" ry="4"/>)}</g>}
  {pattern==='tuxedo'&&<ellipse cx="87" cy="116" rx="18" ry="24" fill={mark}/>}
  <ellipse cx="82" cy="134" rx="17" ry="8" fill={pattern==='points'?mark:fur}/><ellipse cx="118" cy="137" rx="18" ry="8" fill={fur}/>
  <g className="cat-head"><path d={ears?'m39 67-5-20 24 4 30-1 15 16':'m37 66-4-39 29 23 21-1 27-21-3 40'} fill={fur} stroke={pattern==='hairless'?mark:fur} strokeWidth="4" strokeLinejoin="round"/>
  <path d={ears?'m38 48 15 4-11 9m47-9 12 10-15-3':'m39 37 4 23 14-7m31 1 16-17-3 23'} fill="#d39ca4"/>
  <ellipse cx="71" cy="81" rx="41" ry="34" fill={pattern==='points'?mark:fur}/>
  {pattern==='calico'&&<path d="M70 48q-35-1-40 29l24 5 19-18Z" fill={mark}/>}
  {pattern==='patches'&&<path d="M70 49q37-2 41 29L83 74Z" fill={mark}/>}
  {pattern==='tuxedo'&&<path d="m70 59-15 35 17 15 15-15Z" fill={mark}/>}
  {pattern==='stripes'&&<path d="m54 54 7 12 7-12 8 12 8-12" stroke={mark} fill="none" strokeWidth="4" strokeLinecap="round"/>}
  {pattern==='hairless'&&<path d="m50 57 11 4m16-4 12 4M45 99l9 4m32-2 7-5" stroke={mark} fill="none" strokeWidth="2"/>}
  {asleep?<path d="m45 80 8 4 8-4m20 0 8 4 8-4" fill="none" stroke="#493d45" strokeWidth="3" strokeLinecap="round"/>:<g><ellipse cx="54" cy="80" rx="7" ry="8" fill="#b6ce9b"/><ellipse cx="88" cy="80" rx="7" ry="8" fill="#b6ce9b"/><ellipse cx="54" cy="80" rx="2" ry="6" fill="#323847"/><ellipse cx="88" cy="80" rx="2" ry="6" fill="#323847"/><circle cx="52" cy="77" r="2" fill="white"/><circle cx="86" cy="77" r="2" fill="white"/></g>}
  <path d="m65 92 12 0-6 6Z" fill="#b57886"/><path d="m71 98-4 4m4-4 4 4M43 94l-21-3m22 10-22 4m77-11 20-4m-20 11 22 4" stroke="#725a62" strokeWidth="1.8" fill="none" strokeLinecap="round"/>
  </g></g>
  {asleep&&<text className="cat-zzz" x="143" y="45" fill="#937b9b" fontSize="24">z<tspan dy="-15" fontSize="16">z</tspan></text>}
  {pose==='feed'&&<g><path d="M25 132h46l-7 17H32Z" fill="#b77c91"/><ellipse cx="48" cy="131" rx="22" ry="5" fill="#ead4b0"/></g>}
  {pose==='play'&&<g className="cat-toy"><circle cx="159" cy="138" r="12" fill="#bc9cd6"/><path d="m151 133 16 11m-15 0 14-13" stroke="#eee1f6" fill="none"/></g>}
  {pose==='cuddle'&&<text className="cat-hearts" x="125" y="55" fill="#cb7b98" fontSize="26">♥</text>}
 </svg>
}
