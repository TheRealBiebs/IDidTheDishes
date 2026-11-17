import {useEffect,useRef,useState} from 'react'
import {POKER_CHIPS,pokerChips,pokerChipLabel} from './poker-chips'
import './poker.css'

export function PokerChip({chip,style={},className=''}){
  return <span className={`poker-chip ${className}`} style={{'--chip-color':chip.color,'--chip-ink':chip.ink,...style}} aria-hidden="true"><b>{chip.value}</b></span>
}
export function PokerChipStacks({points=0,animate=false,maxVisible=20}){
  const chips=pokerChips(points);let order=0
  return <div className={`poker-chip-stacks ${animate?'poker-chips-dropping':''}`} role="img" aria-label={pokerChipLabel(points)} data-points={points} style={{'--pile-height':`${Math.max(128,Math.min(maxVisible,Math.max(...chips.map(chip=>chip.count)))*5+44)}px`}}>{chips.map(chip=>{
    const visible=Math.min(chip.count,maxVisible)
    return <div className="poker-stack" key={chip.value} data-denomination={chip.value} data-count={chip.count} aria-hidden="true"><div className="poker-pile"><span className="poker-chip-outline"/>{Array.from({length:visible},(_,i)=><PokerChip key={i} chip={chip} className="poker-stacked-chip" style={{'--chip-index':i,'--drop-delay':`${Math.min(order++*.055,1.25)}s`}}/>)}{chip.count>visible&&<span className="poker-overflow" style={{bottom:`${visible*5+18}px`}}>+{chip.count-visible}</span>}</div><span className="poker-stack-value">{chip.value}</span><span className="poker-stack-count">×{chip.count.toLocaleString()}</span></div>
  })}</div>
}
export function PokerChipPile({points=0}){
 const chips=pokerChips(points).filter(c=>c.count)
 return <div className="poker-natural-pile" role="img" aria-label={pokerChipLabel(points)} data-points={points}>{chips.map((chip,j)=><div className="poker-natural-stack" key={chip.value} style={{left:`${15+(j%3)*29}%`,bottom:`${j<3?4:23}px`,zIndex:j<3?3:1}}>{Array.from({length:Math.min(chip.count,14)},(_,i)=><PokerChip key={i} chip={chip} className="poker-stacked-chip" style={{'--chip-index':i}}/>)}{chip.count>14&&<small className="poker-overflow" style={{bottom:90}}>+{chip.count-14}</small>}</div>)}</div>
}
export function PokerChipLegend(){
  return <ul className="poker-legend" aria-label="Poker chip values">{POKER_CHIPS.map(chip=><li key={chip.value}><PokerChip chip={chip}/><span>{chip.name} · {chip.value}</span></li>)}</ul>
}
export function PokerRewardDrop({points=0}){
  const initialPoints=useRef(points),[finished,setFinished]=useState(false)
  useEffect(()=>{const timer=setTimeout(()=>setFinished(true),2200);return()=>clearTimeout(timer)},[])
  return <div className="reward-celebration celebration-poker poker-reward-drop" data-earned-points={points}><PokerChipStacks points={points} animate={!finished&&points===initialPoints.current} maxVisible={40}/><p className="poker-drop-amount">{points>0?`${points} points in chips`:'No chips awarded'}</p></div>
}
