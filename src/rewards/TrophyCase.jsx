import TrophyCaseControls from './TrophyCaseControls'
import {catType} from './cats/catalog'
import CatArt from './cats/CatArt'
import {TeamBadge} from '../HouseholdThemes'
import {useId,useMemo,useState} from 'react'
import {trophyKind,trophyWord,trophyLayout,TROPHY_SHELVES} from './trophy-layout'
import './trophies.css'

export default function TrophyCase({name,wins=0,mode='points',color,trophies,appearance={},compact=false,hideName=false}){
 const [selected,setSelected]=useState(null)
 const total=Array.isArray(trophies)?trophies.length:wins
 const kinds=Array.isArray(trophies)?[...new Set(trophies.map(t=>trophyKind(t.mode)))]:[]
 const kind=kinds.length>1?'mixed':kinds[0]||trophyKind(mode),layout=useMemo(()=>trophyLayout(total,{maxVisible:compact?45:75}),[total,compact])
 const palette='trophy-'+useId().replace(/[^a-zA-Z0-9_-]/g,'')
 const word=kind==='mixed'?'trophy':trophyWord(kind),objectName=layout.total===1?word:word==='chip trophy'?'chip trophies':word==='sleeping cat'?'sleeping cats':word==='trophy'?'trophies':word+'s'
 return <article className={`trophy-case trophies-${kind} trophy-stage-${layout.stage} case-finish-${appearance.finish||'wood'} ${compact?'trophy-case-compact':''}`} data-wins={layout.total} data-mode={kind} style={{'--cabinet-frame':/^#[0-9a-f]{6}$/i.test(appearance.frame||'')?appearance.frame:undefined,'--cabinet-backdrop':/^#[0-9a-f]{6}$/i.test(appearance.backdrop||'')?appearance.backdrop:undefined,'--case-accent':/^#[0-9a-f]{6}$/i.test(color||'')?color:'#c8a55b'}}>
   {!hideName&&<div className="trophy-case-heading"><h3>{name}</h3><span className="trophy-win-count"><strong>{layout.total.toLocaleString()}</strong><small>{layout.total===1?'trophy':'trophies'}</small></span></div>}
   <div className="trophy-cabinet" role="group" aria-label={`${name}: ${layout.total} ${objectName}${layout.stage==='overstuffed'?', overstuffed display':layout.stage==='crowded'?', crowded shelves':''}`}>
    <svg className="trophy-palette" aria-hidden="true"><defs><linearGradient id={`${palette}-gold`} x1="0" y1="0" x2="1" y2=".8"><stop stopColor="#fff0a5"/><stop offset=".4" stopColor="#e7b841"/><stop offset=".72" stopColor="#a56b19"/><stop offset="1" stopColor="#fbe395"/></linearGradient><linearGradient id={`${palette}-cat`} x1="0" y1="0" x2="1" y2="1"><stop stopColor="#ffe0b8"/><stop offset="1" stopColor="#d89a63"/></linearGradient></defs></svg>
    <div className="trophy-case-interior">
     {kind==='stars'&&<div className="trophy-calendar-print" aria-hidden="true"><div className="trophy-calendar-title">WINNING WEEKS</div><div className="trophy-calendar-cells">{Array.from({length:15},(_,i)=><i key={i}/>)}</div></div>}
     {kind!=='stars'&&TROPHY_SHELF_MARKS.map((top,i)=><span className="trophy-shelf" key={i} style={{top}} aria-hidden="true"/>)}
     {layout.items.map(item=><button type="button" key={trophies?.[item.id]?.id||item.id} className="trophy-item" aria-label={'View '+trophyTitle(trophies?.[item.id]||{mode})} title={trophySummary(trophies?.[item.id]||{mode})} onMouseEnter={()=>setSelected(item.id)} onFocus={()=>setSelected(item.id)} onClick={()=>setSelected(item.id)} data-earned-mode={trophyKind(trophies?.[item.id]?.mode||mode)} data-win-number={item.id+1} style={{left:`${item.x/3}%`,top:`${(kind==='stars'?TROPHY_SHELVES[2-item.shelf]+item.y-TROPHY_SHELVES[item.shelf]:item.y)/2.5}%`,transform:`translate(-50%,-100%) rotate(${item.angle}deg)`,zIndex:Math.round(item.y*3)+item.id}}><TrophyArt kind={trophyKind(trophies?.[item.id]?.mode||mode)} palette={palette} appearance={trophies?.[item.id]}/></button>)}
     {!layout.total&&<span className="trophy-case-empty" aria-hidden="true">No trophies to display yet</span>}
     {kind!=='stars'&&<div className="trophy-glass" aria-hidden="true"/>}
    </div>
    <div className="trophy-case-plaque" aria-hidden="true">{kind==='stars'?'★':kind==='cats'?'☾':kind==='poker'?'♠':'✦'} {layout.total.toLocaleString()} {layout.total===1?word:objectName}</div>
   </div>
   {selected!==null&&<section className="trophy-detail" aria-label="Trophy details"><button className="icon-button" aria-label="Close trophy details" onClick={()=>setSelected(null)}>×</button><h4>{trophyTitle(trophies?.[selected]||{mode})}</h4><p>{trophySummary(trophies?.[selected]||{mode})}</p>{trophies?.[selected]?.kind==='poker_bank'&&<ul className="weekly-roulette-bank-history">{trophies[selected].deposits?.map(d=><li key={d.id}>{Number(d.amount).toLocaleString()} chips banked · {new Date(d.date).toLocaleDateString()}{d.source==='legacy'?' · Previous weekly bank':''}</li>)}{trophies[selected].rounds?.map(r=><li key={r.week_start}>Week of {r.week_start}: {r.earnings} earned − {r.wager} bet + {r.payout} returned = <strong>{r.credit} banked</strong>{r.outcome!=null?` · Landed on ${r.outcome===37?'00':r.outcome}`:' · No spin'}</li>)}</ul>}</section>}
   {layout.hidden>0&&<p className="trophy-overflow-note">{layout.items.length} displayed · {layout.hidden.toLocaleString()} more in the pile</p>}
 </article>
}
const TROPHY_SHELF_MARKS=['91.2%','62%','32.8%']

export function TrophyCaseGrid({entries=[],mode='points',compact=false,householdId,preferredId}){
 const [selected,setSelected]=useState(''),[styles,setStyles]=useState({})
 const entry=entries.find(e=>(e.id||e.team_id)===selected)||entries.find(e=>(e.id||e.team_id)===preferredId)||entries[0]
 if(!entry)return <TrophyCase name="Trophy case" trophies={[]} mode={mode}/>
 const id=entry.id||entry.team_id
 return <div className="single-trophy-case">{entries.length>1&&<label>Trophy case<select aria-label="Trophy case" value={id} onChange={e=>setSelected(e.target.value)}>{entries.map(e=><option key={e.id||e.team_id} value={e.id||e.team_id}>{e.name}</option>)}</select></label>}<TrophyCase key={id} name={entry.name} wins={entry.weekly_points??entry.points??0} mode={mode} trophies={entry.trophies} appearance={styles[id]||entry.appearance} color={entry.color} compact={compact}/>{householdId&&entry.can_customize&&<TrophyCaseControls key={'controls:'+id} householdId={householdId} entry={{...entry,appearance:styles[id]||entry.appearance}} onSaved={appearance=>setStyles(previous=>({...previous,[id]:appearance}))}/>}</div>
}
function trophyTitle(item){if(item.kind==='poker_bank')return (item.name?item.name+'’s ':'')+'banked poker chips';return item.cat_name||({wizard:'Wizard cup',poker:'Poker chip trophy',stars:'Calendar trophy',cats:catType(item.cat_type)[0]+' cat'})[trophyKind(item.mode)]}
function trophySummary(item){if(item.kind==='poker_bank')return Number(item.bank_total).toLocaleString()+' chips permanently banked · Last deposit '+item.won_on;return [item.cat_type!=null?catType(item.cat_type)[0]:'',item.won_on?'Won '+item.won_on:'Award date unavailable',item.week_start?'Week of '+item.week_start:'',item.points!=null?item.points+' points':'',item.chores!=null?item.chores+' chores':'',item.personal_points!=null?'Your points: '+item.personal_points:'',item.satisfied_days!=null?item.satisfied_days+' satisfied days (required '+(item.required_days||7)+')':''].filter(Boolean).join(' · ')}
function TrophyArt({kind,palette,appearance={}}){
 if(appearance.kind==='poker_bank')return <PokerBankArt total={Number(appearance.bank_total)}/>
 if(kind==='cats')return <CatArt type={appearance.cat_type??0} sleeping small/>
 const gold=`url(#${palette}-gold)`,fur=`url(#${palette}-cat)`
 return <svg viewBox="0 0 64 72" className={`trophy-art trophy-art-${kind}`} aria-hidden="true">
  {kind==='wizard'?<><path d="M17 13H7v9q0 15 15 16m25-25h10v9q0 15-15 16" fill="none" stroke="#cd9b35" strokeWidth="5"/><path d="M19 12h26v15q0 15-13 18-13-3-13-18Z" fill={gold} stroke="#9c6e24" strokeWidth="1.3"/><path d="m17 11 5-6 5 5 5-8 5 8 5-5 5 6Z" fill={gold} stroke="#a97926"/><path d="M28 44h8l2 13H26Z" fill={gold}/><path d="M21 57h22l4 8H17Z" fill={gold} stroke="#986922"/><rect x="15" y="64" width="34" height="5" rx="2" fill="#553e2e"/><foreignObject x="21" y="17" width="23" height="24"><div xmlns="http://www.w3.org/1999/xhtml"><TeamBadge team={{id:appearance.symbol||'star',symbol:appearance.symbol||'star',color:appearance.color||'#489a84'}} size={22}/></div></foreignObject><path d="m27 20 5 4 5-4m-16-5 1 13" fill="none" stroke="#fff2ac" strokeWidth="1.5"/><path d="m10 4 1.5 3L15 8l-3.5 1-1.5 3L9 9 6 8l3-1Z" fill="#ffe9a1"/></>:null}
  {kind==='poker'?<><ellipse cx="32" cy="65" rx="23" ry="5" fill="#172b28" opacity=".3"/><path d="M27 42h10l2 14H25Z" fill={gold}/><path d="M17 56h30v11H17Z" fill="#243933" stroke="#c59b4c" strokeWidth="2"/><path d="M14 66h36v4H14Z" fill={gold}/><circle cx="22" cy="28" r="17" fill="#316eae" stroke="#f3e6c7" strokeWidth="3" strokeDasharray="5 4"/><circle cx="41" cy="29" r="17" fill="#2e8562" stroke="#f3e6c7" strokeWidth="3" strokeDasharray="5 4"/><circle cx="32" cy="24" r="21" fill="#bf4c50" stroke="#edcf7b" strokeWidth="3"/><circle cx="32" cy="24" r="18" fill="none" stroke="#fff4de" strokeWidth="4" strokeDasharray="6 5"/><circle cx="32" cy="24" r="12" fill="#24332e" stroke="#e3ba5f"/><path d="M32 15c-3 5-9 7-8 12 1 4 6 3 8 0 2 3 7 4 8 0 1-5-5-7-8-12Zm-1 12-3 7h8l-3-7Z" fill="#ffe5a2"/><path d="M24 60h16" stroke="#d7b76a" strokeWidth="2"/></>:null}
  {kind==='cats'?<><ellipse cx="32" cy="61" rx="28" ry="8" fill="#ca9ea4"/><ellipse cx="33" cy="43" rx="25" ry="20" fill={fur} stroke="#ab744d" strokeWidth="1.2"/><path d="M49 35q18 17-3 22-16 3-15-9 1-7 8-6" fill="none" stroke="#bd7b4c" strokeWidth="8" strokeLinecap="round"/><path d="m9 35-1-19 14 10 11-5 4 17" fill={fur} stroke="#ab744d" strokeWidth="1.3"/><path d="m11 21 1 9 6-3m13-1 2 7 2-8" fill="#dc9f9c"/><ellipse cx="21" cy="39" rx="17" ry="14" fill={fur}/><path d="m10 38 4 2 4-2m8 0 4 2 4-2m-15 7 3 2 3-2M8 45l-7 1m8 3-7 3m31-7 8 1" stroke="#765246" strokeWidth="1.6" fill="none" strokeLinecap="round"/><path d="m21 41 3 0-1.5 2Z" fill="#b16f7b"/><path d="M28 25v5m8-3-1 5m9 0-3 3" stroke="#b5784c" strokeWidth="3" strokeLinecap="round"/><path d="m44 10 8 0-8 8h8m2 6h6l-6 6h6" stroke="#ac8a9c" strokeWidth="2" fill="none" strokeLinecap="round"/></>:null}
  {kind==='stars'?<><path d="m32 5 8.5 18 20 3-14.5 14 3.5 21L32 51 14.5 61 18 40 3.5 26l20-3Z" fill="#b57b1e" opacity=".2" transform="translate(0 4)"/><path d="m32 5 8.5 18 20 3-14.5 14 3.5 21L32 51 14.5 61 18 40 3.5 26l20-3Z" fill={gold} stroke="#c08a25" strokeWidth="1.5" strokeLinejoin="round"/><path d="m32 13 5 12-5 3-5-3Zm-4 18L12 28l12-2m10 7 10 18-2-13" fill="#fff2a1" opacity=".8"/><path d="m9 6 1 3 3 1-3 1-1 3-1-3-3-1 3-1m46 45 1 3 3 1-3 1-1 3-1-3-3-1 3-1" fill="#f6cb58"/></>:null}
 </svg>
}

function PokerBankArt({total}){
 const layers=Math.min(32,Math.max(3,Math.ceil(Math.log2(total+1)*2))),colors=['#f3e9d4','#b33c43','#3269a5','#2a855f','#252932']
 return <svg viewBox="0 0 64 80" className="trophy-art trophy-art-poker-bank" aria-hidden="true"><ellipse cx="32" cy="74" rx="26" ry="5" fill="#0005"/>{Array.from({length:layers},(_,i)=>{const y=70-i*1.75;return <g key={i}><path d={`M10 ${y-3}v5c0 8 44 8 44 0v-5`} fill={colors[Math.min(4,Math.floor(i/7))]} stroke="#111" strokeWidth=".6"/><ellipse cx="32" cy={y-3} rx="22" ry="7" fill={colors[Math.min(4,Math.floor(i/7))]} stroke="#fff2d5" strokeWidth="2" strokeDasharray="5 4"/></g>})}<text x="32" y={67-(layers-1)*1.75} fontSize="7" textAnchor="middle" fill={layers>21?'#fff0c5':'#302d21'} fontWeight="700">♠</text></svg>
}
