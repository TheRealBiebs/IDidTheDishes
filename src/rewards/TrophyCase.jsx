import TrophyCaseControls from './TrophyCaseControls'
import {catType} from './cats/catalog'
import CatArt from './cats/CatArt'
import {TeamBadge} from '../HouseholdThemes'
import {useId,useMemo,useState} from 'react'
import {trophyKind,cabinetLayout} from './trophy-layout'
import StickerArt from './glass-stickers/StickerArt'
import PlaceSticker from './glass-stickers/PlaceSticker'
import {glassSticker} from './glass-stickers/catalog'
import './trophies.css'

export default function TrophyCase({name,wins=0,mode='points',color,trophies,appearance={},compact=false,hideName=false}){
 const [selected,setSelected]=useState(null),[placing,setPlacing]=useState(null),[positions,setPositions]=useState({})
 const display=useMemo(()=>{
  const rows=Array.isArray(trophies)?trophies:Array.from({length:Math.min(wins,75)},(_,i)=>({id:'legacy-'+i,mode}))
  return rows.filter(t=>trophyKind(t.mode)==='poker'?t.kind==='poker_bank'&&Number(t.bank_total)>0:trophyKind(t.mode)==='stars'?t.kind==='glass_sticker':true).map((t,i)=>{const id=t.id||'display-'+i;return {...t,id,placement:positions[id]||t.placement}})
 },[trophies,wins,mode,positions])
 const layout=useMemo(()=>cabinetLayout(display,{maxVisible:compact?45:75}),[display,compact]),kinds=[...new Set(display.map(t=>trophyKind(t.mode)))],kind=kinds.length===1&&kinds[0]!=='stars'?kinds[0]:'mixed'
 const palette='trophy-'+useId().replace(/[^a-zA-Z0-9_-]/g,''),current=display.find(t=>t.id===selected),placement=display.find(t=>t.id===placing)
 const banked=display.filter(t=>t.kind==='poker_bank').reduce((n,t)=>n+Number(t.bank_total),0),unplaced=display.filter(t=>t.kind==='glass_sticker'&&t.can_place&&!t.placement)
 const scene=<div className="trophy-case-interior" style={{aspectRatio:`300 / ${layout.height}`}}>
  {layout.shelves.map((top,i)=><span className="trophy-shelf" key={i} style={{top:top/layout.height*100+'%'}} aria-hidden="true"/>)}
  {layout.items.map(item=>{const t=display[item.index];return <button type="button" key={item.key} className={'trophy-item trophy-supported trophy-group-'+item.group} aria-label={'View '+trophyTitle(t)} title={trophySummary(t)} onFocus={()=>setSelected(t.id)} onClick={()=>setSelected(t.id)} data-earned-mode={trophyKind(t.mode)} data-reward-id={t.id} data-shelf={item.shelf} style={{left:item.x/3+'%',top:item.y/layout.height*100+'%',width:item.w/3+'%',height:item.h/layout.height*100+'%',transform:'translate(-50%,-100%)',zIndex:100+Math.round(item.y)}}>{t.kind==='poker_bank'?<ChipStackArt layers={item.layers} part={item.part}/>:<TrophyArt kind={trophyKind(t.mode)} palette={palette} appearance={t}/>}</button>})}
  {!display.length&&<span className="trophy-case-empty">No trophies to display yet</span>}
  <div className="trophy-glass" aria-hidden="true"/>
  <div className="case-glass-stickers">{display.filter(t=>t.kind==='glass_sticker'&&t.placement).map(t=><button type="button" key={t.id} className="placed-glass-sticker" style={{left:t.placement.x+'%',top:t.placement.y+'%',transform:`translate(-50%,-50%) rotate(${t.placement.angle}deg)`}} onFocus={()=>setSelected(t.id)} onClick={()=>setSelected(t.id)} title={trophySummary(t)} aria-label={'View '+trophyTitle(t)}><StickerArt design={t.design}/></button>)}</div>
 </div>
 return <article className={`trophy-case trophies-${kind} trophy-stage-${layout.stage} case-finish-${appearance.finish||'wood'} ${compact?'trophy-case-compact':''}`} data-wins={display.length} data-mode={kind} style={{'--cabinet-frame':/^#[0-9a-f]{6}$/i.test(appearance.frame||'')?appearance.frame:undefined,'--cabinet-backdrop':/^#[0-9a-f]{6}$/i.test(appearance.backdrop||'')?appearance.backdrop:undefined,'--case-accent':/^#[0-9a-f]{6}$/i.test(color||'')?color:'#c8a55b'}}>
  {!hideName&&<div className="trophy-case-heading"><h3>{name}</h3><span className="trophy-win-count"><strong>{display.length.toLocaleString()}</strong><small>rewards</small></span></div>}
  <svg className="trophy-palette" aria-hidden="true"><defs><linearGradient id={`${palette}-gold`} x1="0" y1="0" x2="1" y2=".8"><stop stopColor="#fff0a5"/><stop offset=".4" stopColor="#e7b841"/><stop offset=".72" stopColor="#a56b19"/><stop offset="1" stopColor="#fbe395"/></linearGradient></defs></svg>
  <div className="trophy-cabinet" role="group" aria-label={`${name}: ${display.length} rewards, grouped on supported shelves`}>{scene}<div className="trophy-case-plaque">✦ {display.length} rewards{banked>0?` · ${banked.toLocaleString()} banked chips`:''}</div></div>
  {unplaced.length>0&&<section className="unplaced-stickers"><h4>{unplaced.length} sticker{unplaced.length===1?'':'s'} ready for the glass!</h4><div>{unplaced.map(t=><button key={t.id} className="earned-sticker-pick" onClick={()=>setPlacing(t.id)} aria-label={'Place '+glassSticker(t.design)[1]}><StickerArt design={t.design}/><span>Place sticker</span><small>Week of {t.week_start}</small></button>)}</div></section>}
  {placement&&<PlaceSticker sticker={placement} preview={scene} aspect={300/layout.height} onCancel={()=>setPlacing(null)} onSaved={position=>{setPositions(p=>({...p,[placement.id]:position}));setPlacing(null)}}/>}
  {current&&<section className="trophy-detail" aria-label="Trophy details"><button className="icon-button" aria-label="Close trophy details" onClick={()=>setSelected(null)}>×</button><h4>{trophyTitle(current)}</h4><p>{trophySummary(current)}</p>{current.kind==='glass_sticker'&&current.can_place&&<button className="button secondary" onClick={()=>setPlacing(current.id)}>Move sticker</button>}{current.kind==='poker_bank'&&<ul className="weekly-roulette-bank-history">{current.deposits?.map(d=><li key={d.id}>{Number(d.amount).toLocaleString()} chips banked · {new Date(d.date).toLocaleDateString()}</li>)}</ul>}</section>}
  {layout.hidden>0&&<p className="trophy-overflow-note">The display shows a representative pile; {layout.hidden} more pieces are kept in this collection. Exact chip totals are shown above.</p>}
 </article>
}
export function TrophyCaseGrid({entries=[],mode='points',compact=false,householdId,preferredId}){
 const [selected,setSelected]=useState(''),[styles,setStyles]=useState({})
 const entry=entries.find(e=>(e.id||e.team_id)===selected)||entries.find(e=>(e.id||e.team_id)===preferredId)||entries[0]
 if(!entry)return <TrophyCase name="Trophy case" trophies={[]} mode={mode}/>
 const id=entry.id||entry.team_id
 return <div className="single-trophy-case">{entries.length>1&&<label>Trophy case<select aria-label="Trophy case" value={id} onChange={e=>setSelected(e.target.value)}>{entries.map(e=><option key={e.id||e.team_id} value={e.id||e.team_id}>{e.name}</option>)}</select></label>}<TrophyCase key={id} name={entry.name} wins={entry.weekly_points??entry.points??0} mode={mode} trophies={entry.trophies} appearance={styles[id]||entry.appearance} color={entry.color} compact={compact}/>{householdId&&entry.can_customize&&<TrophyCaseControls key={'controls:'+id} householdId={householdId} entry={{...entry,appearance:styles[id]||entry.appearance}} onSaved={value=>setStyles(s=>({...s,[id]:value}))}/>}</div>
}
function trophyTitle(item){if(item.kind==='poker_bank')return (item.name?item.name+'’s ':'')+'banked chips';if(item.kind==='glass_sticker')return glassSticker(item.design)[1]+' sticker';return item.cat_name||(trophyKind(item.mode)==='cats'?catType(item.cat_type)[0]+' cat':'House Cup')}
function trophySummary(item){if(item.kind==='poker_bank')return Number(item.bank_total).toLocaleString()+' chips permanently banked · Last deposit '+item.won_on;if(item.kind==='glass_sticker')return [item.won_on?'Won '+item.won_on:'',item.week_start?'Week of '+item.week_start:'','Stickers on all 7 days',item.chores!=null?item.chores+' chores':''].filter(Boolean).join(' · ');return [item.won_on?'Won '+item.won_on:'Award date unavailable',item.week_start?'Week of '+item.week_start:'',item.points!=null?item.points+' points':'',item.chores!=null?item.chores+' chores':'',item.personal_points!=null?'Your points: '+item.personal_points:'',item.satisfied_days!=null?item.satisfied_days+' satisfied days':''].filter(Boolean).join(' · ')}
function ChipStackArt({layers=1,part=0}){
 const colors=['#f3eee0','#c64d5c','#418cd1','#309d73','#272c3c'],height=8+layers*.8,color=colors[part%5]
 return <svg viewBox={`0 0 25 ${height}`} className="trophy-art trophy-art-chip-stack" aria-hidden="true">{Array.from({length:layers},(_,i)=>{const y=height-4-i*.8;return <g key={i}><path d={`M1.5 ${y}v1.4c0 4 22 4 22 0v-1.4Z`} fill={color} stroke="#10141b" strokeWidth=".3"/><ellipse cx="12.5" cy={y} rx="11" ry="3" fill={color} stroke="#fff1da" strokeWidth="1" strokeDasharray="2.7 2"/></g>})}</svg>
}
function TrophyArt({kind,palette,appearance={}}){
 if(kind==='cats')return <CatArt type={appearance.cat_type??0} sleeping small/>
 const gold=`url(#${palette}-gold)`,fur=`url(#${palette}-cat)`
 return <svg viewBox="0 2 64 67" preserveAspectRatio="none" className={`trophy-art trophy-art-${kind}`} aria-hidden="true">
  {kind==='wizard'?<><path d="M17 13H7v9q0 15 15 16m25-25h10v9q0 15-15 16" fill="none" stroke="#cd9b35" strokeWidth="5"/><path d="M19 12h26v15q0 15-13 18-13-3-13-18Z" fill={gold} stroke="#9c6e24" strokeWidth="1.3"/><path d="m17 11 5-6 5 5 5-8 5 8 5-5 5 6Z" fill={gold} stroke="#a97926"/><path d="M28 44h8l2 13H26Z" fill={gold}/><path d="M21 57h22l4 8H17Z" fill={gold} stroke="#986922"/><rect x="15" y="64" width="34" height="5" rx="2" fill="#553e2e"/><foreignObject x="21" y="17" width="23" height="24"><div xmlns="http://www.w3.org/1999/xhtml"><TeamBadge team={{id:appearance.symbol||'star',symbol:appearance.symbol||'star',color:appearance.color||'#489a84'}} size={22}/></div></foreignObject><path d="m27 20 5 4 5-4m-16-5 1 13" fill="none" stroke="#fff2ac" strokeWidth="1.5"/><path d="m10 4 1.5 3L15 8l-3.5 1-1.5 3L9 9 6 8l3-1Z" fill="#ffe9a1"/></>:null}
  {kind==='cats'?<><ellipse cx="32" cy="61" rx="28" ry="8" fill="#ca9ea4"/><ellipse cx="33" cy="43" rx="25" ry="20" fill={fur} stroke="#ab744d" strokeWidth="1.2"/><path d="M49 35q18 17-3 22-16 3-15-9 1-7 8-6" fill="none" stroke="#bd7b4c" strokeWidth="8" strokeLinecap="round"/><path d="m9 35-1-19 14 10 11-5 4 17" fill={fur} stroke="#ab744d" strokeWidth="1.3"/><path d="m11 21 1 9 6-3m13-1 2 7 2-8" fill="#dc9f9c"/><ellipse cx="21" cy="39" rx="17" ry="14" fill={fur}/><path d="m10 38 4 2 4-2m8 0 4 2 4-2m-15 7 3 2 3-2M8 45l-7 1m8 3-7 3m31-7 8 1" stroke="#765246" strokeWidth="1.6" fill="none" strokeLinecap="round"/><path d="m21 41 3 0-1.5 2Z" fill="#b16f7b"/><path d="M28 25v5m8-3-1 5m9 0-3 3" stroke="#b5784c" strokeWidth="3" strokeLinecap="round"/><path d="m44 10 8 0-8 8h8m2 6h6l-6 6h6" stroke="#ac8a9c" strokeWidth="2" fill="none" strokeLinecap="round"/></>:null}
 </svg>
}
