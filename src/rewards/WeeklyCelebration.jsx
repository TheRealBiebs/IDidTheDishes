import { useEffect,useRef,useState } from 'react'
import { rpc } from '../api'
import { weekLabel,weeklyWinners,weeklyWinnerLabel,weeklyUnit } from './weekly-results'
import './weekly-results.css'

export default function WeeklyCelebration({household,enabled,renderDialog,onInspect}){
  const [result,setResult]=useState(null),[error,setError]=useState(''),[saving,setSaving]=useState(false)
  const [foreground,setForeground]=useState(!document.hidden)
  const showing=useRef(null),seen=useRef(new Set()),acknowledging=useRef(null),client=useRef(crypto.randomUUID())
  useEffect(()=>{const update=()=>setForeground(!document.hidden);document.addEventListener('visibilitychange',update);return()=>document.removeEventListener('visibilitychange',update)},[])
  useEffect(()=>{if(!enabled||!foreground){showing.current=null;setResult(null);return}let active=true,checking=false;
    async function check(){if(!active||checking||showing.current||document.hidden)return;checking=true;try{const value=await rpc('pending_weekly_result',{p_household:household.id});if(active&&value&&!seen.current.has(value.id)&&await rpc('claim_weekly_result',{p_result:value.id,p_client:client.current})){if(!active||document.hidden)return;showing.current=value.id;setResult(value);setError('')}}catch{/* Retry on foreground/next check; Hall of Fame also exposes retry. */}finally{checking=false}}
    check();const visible=()=>{if(!document.hidden)check()};document.addEventListener('visibilitychange',visible);const timer=setInterval(check,60000);return()=>{active=false;clearInterval(timer);document.removeEventListener('visibilitychange',visible)}
  },[household.id,enabled,foreground])
  async function acknowledge(){
    if(!result||seen.current.has(result.id))return true
    if(acknowledging.current)return acknowledging.current
    setSaving(true);setError('');acknowledging.current=rpc('ack_weekly_result',{p_result:result.id}).then(()=>{seen.current.add(result.id);return true}).catch(e=>{setError(e.message);return false}).finally(()=>{acknowledging.current=null;setSaving(false)})
    return acknowledging.current
  }
  useEffect(()=>{if(!enabled||!foreground||!result)return;const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;const timer=setTimeout(()=>acknowledge(),reduced?0:2600);return()=>clearTimeout(timer)},[enabled,foreground,result?.id])
  async function dismiss(inspect=false){if(!await acknowledge())return;const value=result;showing.current=null;setResult(null);if(inspect)onInspect(value)}
  if(!enabled||!foreground||!result)return null
  const winners=weeklyWinners(result)
  return renderDialog({title:'Weekly result',onClose:()=>dismiss(),children:<div className="weekly-celebration"><WeekAnimation result={result}/><h3>{weeklyWinnerLabel(result)}</h3><p>{weekLabel(result.week_start,result.week_end)}</p><p>{winners.length?winners.length===1?'+1 weekly win point':'+1 weekly win point for each tied team':'No weekly win point awarded.'}</p><div className="weekly-score-list">{result.team_scores.filter(t=>t.winner).map(t=><div key={t.team_id}><span>{t.name}</span><strong>{t.score} {weeklyUnit(result.reward_scheme)}</strong></div>)}</div>{error&&<p role="alert" className="form-error">{error}</p>}<div className="form-actions"><button className="button secondary" disabled={saving} onClick={()=>dismiss(true)}>View this week</button><button className="button" disabled={saving} onClick={()=>dismiss()}>Continue</button></div></div>})
}
function WeekAnimation({result}){
  const winners=weeklyWinners(result)
  if(result.reward_scheme==='stars')return <div className="weekly-star-animation" role="img" aria-label="Stars fly off last week’s calendar"><div className="weekly-mini-calendar">{Array.from({length:14},(_,i)=><span key={i}>{i+1}<b style={{'--x':`${(i%5-2)*40}px`,'--delay':`${i*.05}s`}}>★</b></span>)}</div></div>
  if(result.reward_scheme==='adventure')return <div className="weekly-adventure-animation" role="img" aria-label="A weekly trophy shines">🏆<i>✦</i><i>✧</i></div>
  return <div className="weekly-jar-animation" role="img" aria-label="Gems shoot out of the winning team jars">{(winners.length?winners:[{team_id:'none',color:'#a99776',name:'New week'}]).map(team=><div className="weekly-winner-jar" key={team.team_id} style={{'--winning-color':/^#[0-9a-f]{6}$/i.test(team.color)?team.color:'#b9975c'}}><div className="weekly-jar-glass"/>{winners.length>0&&Array.from({length:14},(_,i)=><i className="weekly-flying-gem" key={i} style={{'--x':`${(i%7-3)*17}px`,'--delay':`${i*.045}s`}}/>)}<span>{team.name}</span></div>)}</div>
}
