import { useEffect,useRef,useState } from 'react'
import { rpc } from '../api'
import { cleanUnexpectedDescription,rouletteRotation,unexpectedRequestKey,readUnexpectedRequest } from './unexpected-chore'
import './unexpected-chore.css'

export default function UnexpectedChore({household,userId,onLogged,onDone}){
  const key=unexpectedRequestKey(household.id,userId)
  const request=useRef(readUnexpectedRequest(sessionStorage,key)),mounted=useRef(true),inFlight=useRef(false)
  const [description,setDescription]=useState(request.current?.description||''),[phase,setPhase]=useState('ready'),[error,setError]=useState(''),[result,setResult]=useState(null),[rotation,setRotation]=useState(0)
  const reducedMotion=useRef(window.matchMedia('(prefers-reduced-motion: reduce)').matches)
  useEffect(()=>{mounted.current=true;if(request.current)submit();return()=>{mounted.current=false}},[])
  useEffect(()=>{if(phase!=='spinning')return;const timer=setTimeout(()=>setPhase('done'),reducedMotion.current?0:3300);return()=>clearTimeout(timer)},[phase])
  async function submit(e){
    e?.preventDefault();if(inFlight.current)return;setError('')
    try{
      if(!request.current){request.current={requestId:crypto.randomUUID(),description:cleanUnexpectedDescription(description)};try{sessionStorage.setItem(key,JSON.stringify(request.current))}catch{}}
      inFlight.current=true;setPhase('saving')
      const completion=await rpc('log_unexpected_chore',{p_household:household.id,p_description:request.current.description,p_request:request.current.requestId})
      const stop=rouletteRotation(completion.points)
      if(mounted.current){setResult(completion);setRotation(stop);setPhase('spinning')}
      Promise.resolve(onLogged(completion)).catch(()=>{})
    }catch(e){if(mounted.current){setError(e.message||'Could not log this chore. Retry to retrieve the same roll.');setPhase('ready')}}finally{inFlight.current=false}
  }
  function done(){try{sessionStorage.removeItem(key)}catch{}onDone()}
  const locked=phase!=='ready'||Boolean(request.current)
  return <div className="unexpected-chore"><div className="roulette-stage"><span className="roulette-pointer" aria-hidden="true"/><div className={`roulette-wheel ${phase==='saving'?'roulette-waiting':''}`} style={{transform:`rotate(${rotation}deg)`,transitionDuration:reducedMotion.current?'0ms':'3200ms'}} role="img" aria-label="Reward wheel with 0, 1, 2, and 3 points">{[0,1,2,3].map(points=><span key={points} style={{'--angle':`${points*90}deg`}} aria-hidden="true"><b>{points}</b></span>)}<i aria-hidden="true">✦</i></div></div>
    {phase==='ready'?<form onSubmit={submit}><label>Description (required)<textarea name="description" value={description} onChange={e=>setDescription(e.target.value)} readOnly={locked} rows={4} required maxLength={500} placeholder="Describe the unexpected chore."/></label><p className="roulette-rule">Random reward: 0–3 points.</p>{error&&<p className="form-error" role="alert">{error}</p>}<button className="button full" disabled={!description.trim()}>{request.current?'Retry submission':'Submit and spin'}</button></form>:phase==='done'?<div className="roulette-result"><strong role="status">{result.points} {result.points===1?'point':'points'}</strong><p className="unexpected-description">{result.chore}</p><button className="button full" onClick={done}>Done</button></div>:<p className="roulette-status" role="status">{phase==='saving'?'Logging chore…':'Spinning…'}</p>}
  </div>
}
