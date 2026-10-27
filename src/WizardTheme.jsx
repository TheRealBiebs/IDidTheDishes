import { useState } from 'react'

export const WIZARD_HOUSES = [
  { id:'gryffindor', name:'Gryffindor', gem:'Rubies', virtue:'Courage & daring', color:'#ed5255', light:'#ffc08d', symbol:'lion' },
  { id:'slytherin', name:'Slytherin', gem:'Emeralds', virtue:'Ambition & cunning', color:'#43d3a1', light:'#b9f0cd', symbol:'snake' },
  { id:'ravenclaw', name:'Ravenclaw', gem:'Sapphires', virtue:'Wisdom & wit', color:'#6b9df5', light:'#c6e6ff', symbol:'raven' },
  { id:'hufflepuff', name:'Hufflepuff', gem:'Topaz', virtue:'Patience & loyalty', color:'#f1c34f', light:'#fff0a5', symbol:'badger' },
]
export const wizardHouse = id => WIZARD_HOUSES.find(h=>h.id===id)

export function HouseCrest({ house, size=44 }) {
  const h=typeof house==='string'?wizardHouse(house):house
  if(!h)return <span className="unsorted-crest" aria-hidden="true">✦</span>
  return <svg className={`house-crest ${h.id}`} width={size} height={size*1.16} viewBox="0 0 72 84" aria-hidden="true"><path d="M36 2 43 8 65 10 65 43Q65 64 36 81 7 64 7 43V10L29 8Z" fill="#201a17" stroke="#bfa16a" strokeWidth="2"/><path d="M36 10 42 14 59 16V42Q59 60 36 73 13 60 13 42V16L30 14Z" fill={h.color} fillOpacity=".22" stroke={h.color} strokeOpacity=".75"/><path d="M19 23h34M20 59q16 13 32 0" fill="none" stroke="#c7ac77" strokeOpacity=".6" strokeWidth="1"/>{h.symbol==='snake'?<path d="M42 26c-19-3-22 14-5 16 19 2 17 19-1 18-8 0-14-6-9-11m14-23 9 3-6 5m-15 23-3 5" fill="none" stroke={h.light} strokeWidth="4" strokeLinecap="round"/>:h.symbol==='raven'?<path d="m37 33 8-7 11 9-11-1-6 11 10 15-15-9-10 9 3-18-10-14 15 8 5-3Z" fill={h.light}/>:h.symbol==='lion'?<><path d="m36 25 8 5 6 10-6 13-8 7-12-9-3-13 6-10Z" fill="none" stroke={h.light} strokeWidth="3"/><path d="m28 34 8-4 8 4-2 12-6 7-6-7Zm3 4h2m7 0h-2m-5 6 3 2 3-2" fill="none" stroke={h.light} strokeWidth="2" strokeLinecap="round"/></>:<><path d="M22 44q0-16 13-17 9 0 15 10l6 8-11 5-9 10-14-9Z" fill={h.light}/><path d="m28 30 8 18-2 9m6-26 4 15" fill="none" stroke="#342b1c" strokeWidth="5"/><circle cx="47" cy="40" r="2" fill="#241e18"/></>}<path d="m6 23-4 8 5 8M66 23l4 8-5 8M24 78l12 4 12-4" fill="none" stroke="#9e8356" strokeWidth="1.5"/></svg>
}

export function Torch({side=''}) {
  return <div className={`wall-torch ${side}`} aria-hidden="true"><div className="torch-halo"/><div className="flame flame-outer"/><div className="flame flame-middle"/><div className="flame flame-core"/><span className="ember e1"/><span className="ember e2"/><span className="ember e3"/><div className="torch-bowl"/><div className="torch-stem"/><div className="torch-mount"/></div>
}
export function CastleAtmosphere() { return <div className="castle-atmosphere" aria-hidden="true"><div className="castle-arch"/><Torch side="left"/><Torch side="right"/><span className="castle-dust d1">✧</span><span className="castle-dust d2">·</span><span className="castle-dust d3">✦</span></div> }

export function GemTube({ house, points=0, capacity=250, compact=false }) {
  const h=house||WIZARD_HOUSES[0]
  const proportion=Math.max(0,Math.min(Number(points)/capacity,1))
  const count=points>0?Math.max(3,Math.min(145,Math.ceil(proportion*140))):0
  const gems=Array.from({length:count},(_,i)=>{
    const cols=compact?5:6, row=Math.floor(i/cols),col=i%cols
    const x=3+col*(91/cols)+(row%2?3:0)+((i*7)%5), y=190-row*7.7
    const turn=(i*67)%90
    return <g key={i} transform={`translate(${x} ${y}) rotate(${turn} 7 5)`}><path d="M0 4 4 0 11 0 16 4 10 11 5 11Z" fill={h.color}/><path d="m0 4 7-1 9 1-6 7Z" fill={h.light} opacity={.25+(i%4)*.13}/><path d="M4 0 7 3 0 4m7-1 3 8 6-7M7 3l4-3" fill="none" stroke={h.light} strokeOpacity=".7" strokeWidth=".55"/></g>
  })
  return <div className={`gem-apparatus ${compact?'compact':''}`} style={{'--gem':h.color,'--gem-light':h.light}} role="img" aria-label={`${points} ${h.name} points in a gemstone tube; scale ${capacity} points`}>
    <div className="tube-finial">✦</div><div className="tube-cap cap-top"><span/></div><div className="tube-columns"><i/><i/></div><div className="glass-tube"><div className="gem-aura" style={{height:`${proportion*100}%`}}/><svg className="tube-gems" viewBox="0 0 110 205" preserveAspectRatio="none" aria-hidden="true">{gems}</svg><div className="glass-shine"/><div className="glass-shine thin"/><div className="tube-graduations"><i/><i/><i/><i/></div></div><div className="tube-cap cap-bottom"><span/></div><div className="tube-plinth"><i/></div>
  </div>
}

export function HouseCup({ scores=[], members=[], currentUser, onChoose, loading }) {
  const totals=WIZARD_HOUSES.map(h=>({...h,points:scores.filter(s=>members.find(m=>m.user_id===s.user_id)?.wizard_house===h.id).reduce((sum,s)=>sum+Number(s.points),0),count:members.filter(m=>m.wizard_house===h.id).length}))
  const high=Math.max(0,...totals.map(h=>h.points)),capacity=Math.max(250,Math.ceil(high/250)*250)
  const me=members.find(m=>m.user_id===currentUser), mine=wizardHouse(me?.wizard_house), personal=Number(scores.find(s=>s.user_id===currentUser)?.points||0)
  return <div className="house-cup-layout"><section className="house-cup" aria-labelledby="cup-title"><div className="cup-heading"><div><span className="eyebrow">THE GREAT HALL</span><h2 id="cup-title">The House Cup</h2><p>Four houses. One household. Every deed counts.</p></div><span className="cup-week"><span>✦</span>This week</span></div><div className="house-tubes">{totals.map(h=><article key={h.id} className={`house-column ${h.id} ${high>0&&h.points===high?'leading':''}`} style={{'--house-color':h.color,'--house-light':h.light}}><div className="house-banner"><HouseCrest house={h} size={45}/><span>{h.name}</span></div><GemTube house={h} points={h.points} capacity={capacity}/><div className="house-total"><strong>{loading?'—':h.points.toLocaleString()}</strong><span>HOUSE POINTS</span></div><p className="house-scholars">{h.count} member{h.count!==1?'s':''}</p>{high>0&&h.points===high&&<span className="house-leader">✧ In the lead</span>}</article>)}</div><div className="cup-footnote"><span>✧</span>{capacity} points fills a tube · resets every Monday<span>✧</span></div></section><section className="personal-vault" style={{'--house-color':mine?.color||'#b9975c'}}><span className="eyebrow">YOUR CONTRIBUTION</span><h2>Your little vault<br/>of great deeds.</h2>{mine?<><div className="personal-tube"><GemTube house={mine} points={personal} capacity={Math.max(100,Math.ceil(personal/100)*100)} compact/><div><HouseCrest house={mine} size={37}/><span className="personal-number">{loading?'—':personal.toLocaleString()}</span><small>points for {mine.name}</small><p>{mine.gem}, well earned.</p><small className="personal-scale">Full tube · {Math.max(100,Math.ceil(personal/100)*100)} points</small></div></div><button className="vault-choice" onClick={onChoose}>Your house: {mine.name}<span>Change →</span></button></>:<><div className="unsorted-art"><span>✦</span><HouseCrest house={WIZARD_HOUSES[0]} size={43}/><HouseCrest house={WIZARD_HOUSES[1]} size={43}/></div><p className="unsorted-copy">Courage, ambition, wisdom, or loyalty.<br/>Where do you belong?</p><button className="button" onClick={onChoose}>Choose your house <span>✦</span></button><small className="pending-points">{personal} personal points await your house.</small></>}</section></div>
}

export function ChooseHouse({current,busy,onChoose}) {
  const [selected,setSelected]=useState(current||'')
  return <><p className="sorting-intro">It is our choices that show who we are. Choose the house you’ll earn points for in this household.</p><div className="sorting-choices" role="radiogroup" aria-label="Wizarding house">{WIZARD_HOUSES.map(h=><label className={`sorting-choice ${selected===h.id?'selected':''}`} key={h.id} style={{'--house-color':h.color}}><input type="radio" name="wizard-house" value={h.id} checked={selected===h.id} onChange={()=>setSelected(h.id)}/><HouseCrest house={h} size={42}/><span><strong>{h.name}</strong><small>{h.virtue}</small></span><span className="sorting-dot"/></label>)}</div><p className="sorting-rule">Your current-week points follow your chosen house. Your personal points stay the same.</p><button className="button full" disabled={!selected||busy} onClick={()=>onChoose(selected)}>{busy?'The sorting is underway…':'Let the house points begin'}<span>✦</span></button></>
}

export function HallBanners() {return <div className="hall-banners" aria-hidden="true">{WIZARD_HOUSES.map(h=><div key={h.id} className={`hall-banner ${h.id}`} style={{'--house-color':h.color}}><HouseCrest house={h} size={45}/></div>)}</div>}
