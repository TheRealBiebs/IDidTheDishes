import {PokerRewardDrop} from './PokerChips'
import {useEffect,useRef,useState} from 'react'
import {rpc} from '../api'
import {cleanUnexpectedDescription,unexpectedRequestKey,readUnexpectedRequest} from './unexpected-chore'
import {WHEEL_TYPES,wheelSettings,wheelRotation} from './wheel-settings'
import {CALENDAR_STICKERS,calendarSticker} from './stickers'
import './unexpected-chore.css'

export default function UnexpectedChore({household,userId,onLogged,onDone}){
 const key=unexpectedRequestKey(household.id,userId),request=useRef(readUnexpectedRequest(sessionStorage,key)),mounted=useRef(true),inFlight=useRef(false)
 const [description,setDescription]=useState(request.current?.description||''),[wheel,setWheel]=useState(request.current?.wheel||'standard'),[phase,setPhase]=useState('ready'),[error,setError]=useState(''),[result,setResult]=useState(null),[rotation,setRotation]=useState(0)
 const reducedMotion=useRef(window.matchMedia('(prefers-reduced-motion: reduce)').matches),settings=wheelSettings(household)
 const outcome=result?.unexpected_reward,sticker=outcome?outcome.type==='sticker':household.reward_scheme==='stars'
 const options=outcome?.options||(sticker?CALENDAR_STICKERS.map(([id])=>id):settings[wheel].values),count=options.length
 useEffect(()=>{mounted.current=true;if(request.current)submit();return()=>{mounted.current=false}},[])
 useEffect(()=>{if(phase!=='spinning')return;const timer=setTimeout(()=>setPhase('done'),reducedMotion.current?0:3300);return()=>clearTimeout(timer)},[phase])
 async function submit(e){
  e?.preventDefault();if(inFlight.current)return;setError('')
  try{
   if(!request.current){request.current={requestId:crypto.randomUUID(),description:cleanUnexpectedDescription(description),wheel};try{sessionStorage.setItem(key,JSON.stringify(request.current))}catch{}}
   inFlight.current=true;setPhase('saving')
   const completion=await rpc('log_unexpected_chore_wheel',{p_household:household.id,p_description:request.current.description,p_request:request.current.requestId,p_wheel:request.current.wheel||'standard'})
   const snapshot=completion.unexpected_reward,stop=wheelRotation(snapshot?.index??completion.points,snapshot?.options?.length||4)
   if(mounted.current){setResult(completion);setRotation(stop);setPhase('spinning')}
   Promise.resolve(onLogged(completion)).catch(()=>{})
  }catch(e){if(mounted.current){setError(e.message||'Could not log this chore. Retry to retrieve the same roll.');setPhase('ready')}}finally{inFlight.current=false}
 }
 function done(){try{sessionStorage.removeItem(key)}catch{}onDone()}
 const locked=phase!=='ready'||Boolean(request.current),types=WHEEL_TYPES.filter(([id])=>settings[id].enabled||id===request.current?.wheel)
 const colors=['#8e536e','#3b877b','#547fa8','#b08a3c','#9b4b8e','#367e9b']
 const gradient='conic-gradient(from '+(-180/count)+'deg,'+options.map((_,i)=>colors[i%colors.length]+' '+i*360/count+'deg '+(i+1)*360/count+'deg').join(',')+')'
 return <div className="unexpected-chore">{types.length>1&&<fieldset className="wheel-effort-choices" disabled={locked}><legend>Chore effort</legend>{types.map(([id,name])=><label key={id}><input type="radio" name="unexpected-wheel" value={id} checked={wheel===id} onChange={()=>setWheel(id)}/>{name}</label>)}</fieldset>}<div className="roulette-stage"><span className="roulette-pointer" aria-hidden="true"/><div className={'roulette-wheel '+(phase==='saving'?'roulette-waiting':'')+(sticker?' sticker-reward-wheel':'')} style={{transform:'rotate('+rotation+'deg)',transitionDuration:reducedMotion.current?'0ms':'3200ms',background:gradient}} role="img" aria-label={sticker?'Random calendar sticker wheel':'Reward wheel: '+options.join(', ')+' points'}>{options.map((value,i)=><span key={i} style={{'--angle':i*360/count+'deg'}} aria-hidden="true"><b>{sticker?calendarSticker(value)[1]:value}</b></span>)}<i aria-hidden="true">✦</i></div></div>
 {phase==='ready'?<form onSubmit={submit}><label>Description (required)<textarea name="description" value={description} onChange={e=>setDescription(e.target.value)} readOnly={locked} rows={4} required maxLength={500} placeholder="Describe the unexpected chore."/></label><p className="roulette-rule">{sticker?'Earn one random sticker for your calendar.':'Random reward: '+settings[wheel].values.join(', ')+(household.reward_scheme==='poker'?' chips.':' points.')}</p>{error&&<p className="form-error" role="alert">{error}</p>}<button className="button full" disabled={!description.trim()}>{request.current?'Retry submission':'Submit and spin'}</button></form>:phase==='done'?<div className="roulette-result">{!sticker&&household.reward_scheme==='poker'&&<PokerRewardDrop points={result.points}/>}<strong role="status">{sticker?calendarSticker(result.calendar_sticker)[1]+' '+calendarSticker(result.calendar_sticker)[2]+' sticker':result.points+(household.reward_scheme==='poker'?' chips':result.points===1?' point':' points')}</strong><p className="unexpected-description">{result.chore}</p><button className="button full" onClick={done}>Done</button></div>:<p className="roulette-status" role="status">{phase==='saving'?'Logging chore…':'Spinning…'}</p>}</div>
}
