import {FeedbackInbox} from '../Feedback'
import { useEffect,useRef,useState } from 'react'
import { rpc } from '../api'
import { isNative } from '../native'
import { scanSticker } from '../platform'
import { setNativeScanHandler } from '../native-lifecycle'
import { writeIssuedSticker } from './provisioning'
import { runContinuousWriter } from './continuous-writer'

export default function TagWorkshop(){
  const [message,setMessage]=useState(''),[error,setError]=useState(''),[lock,setLock]=useState(false),[confirmed,setConfirmed]=useState(false),[running,setRunning]=useState(false),[count,setCount]=useState(0),[lastResult,setLastResult]=useState(''),[recovering,setRecovering]=useState(false)
  const controller=useRef(null),pending=useRef(null),mounted=useRef(true),working=useRef(false)
  useEffect(()=>{mounted.current=true;const stop=()=>{if(document.hidden)controller.current?.abort()};document.addEventListener('visibilitychange',stop);return()=>{mounted.current=false;controller.current?.abort();setNativeScanHandler(null);document.removeEventListener('visibilitychange',stop)}},[])
  async function start(){
    if(working.current)return;working.current=true;setRunning(true);setError('');controller.current=new AbortController();setNativeScanHandler(()=>{})
    try{await runContinuousWriter({pending,signal:controller.current.signal,nextToken:()=>crypto.randomUUID(),
      reserve:token=>rpc('reserve_workshop_sticker',{p_token:token}),
      inspect:token=>rpc('workshop_sticker',{p_token:token}),
      write:(token,options)=>writeIssuedSticker(token,{...options,lock,confirmed,batchMode:true}),
      mark:(token,locked)=>rpc('mark_sticker_written',{p_token:token,p_locked:locked}),
      onPhase:phase=>{if(mounted.current)setMessage(phase==='retap'?'Remove and retap the SAME sticker to verify its URL. Keep it still until verification finishes.':phase==='saving'?'Verified. Saving this sticker…':phase==='waiting'?'Ready — tap the next blank sticker, then remove it.':'Preparing a unique sticker URL…')},
      onReady:async(token,receipt)=>{if(!mounted.current)return;setCount(n=>n+1);setLastResult(receipt.lockUnsupported?'Last sticker: verified and ready, but permanent locking is unsupported.':receipt.locked?'Last sticker: verified and permanently locked.':'Last sticker: verified and ready, still rewritable.')}
    })}catch(e){if(mounted.current){if(e.name==='AbortError'||controller.current?.signal.aborted)setMessage('Writing mode is off.');else{setError(e.message);setMessage('Writing paused. Turn writing mode on to retry the same sticker URL.')}}}finally{working.current=false;const stopped=controller.current?.signal.aborted;controller.current=null;setNativeScanHandler(null);if(mounted.current){if(stopped)setMessage('Writing mode is off.');setRunning(false)}}
  }
  async function findWritten(){
    if(working.current)return;working.current=true;setRecovering(true);setError('');setMessage('Tap the written sticker to find its pending URL.');const abort=new AbortController();controller.current=abort;let found=false
    try{
      const token=await new Promise((resolve,reject)=>{abort.signal.addEventListener('abort',()=>reject(new DOMException('Cancelled','AbortError')),{once:true});scanSticker(value=>{setNativeScanHandler(()=>{});resolve(value)},abort.signal).catch(reject)})
      const tag=await rpc('workshop_sticker',{p_token:token})
      if(abort.signal.aborted)throw new DOMException('Cancelled','AbortError')
      if(!tag)throw new Error('This sticker was not issued by Chip In. Nothing was changed.')
      if(tag.claimed)throw new Error('This sticker is already claimed. Nothing was changed.')
      if(tag.written_at)throw new Error('This sticker is already verified and ready. Scan it outside the workshop to configure it.')
      pending.current={token,verifyOnly:true,receipt:null};found=true
    }catch(e){if(mounted.current){if(e.name!=='AbortError')setError(e.message);setMessage('Verification search stopped.')}}finally{working.current=false;controller.current=null;setNativeScanHandler(null);if(mounted.current)setRecovering(false)}
    if(found&&mounted.current)await start()
  }
  const disabled=running||recovering
  return <>
    <div className="page-heading"><div><h1>Tag workshop</h1></div></div>
    <section className="panel workshop-panel">
      <h2>Writing mode</h2>
      <p>{isNative?'Turn on writing mode, then tap blank stickers one after another. Each gets a unique URL. Existing content is never overwritten.':'Open the Android app to turn on writing mode and prepare NFC stickers.'}</p>
      <label className="check-label"><input type="checkbox" checked={lock} disabled={disabled} onChange={e=>{setLock(e.target.checked);setConfirmed(false)}}/>Permanently lock each sticker after verification</label>
      {lock&&<label className="check-label irreversible-lock"><input type="checkbox" checked={confirmed} disabled={disabled} onChange={e=>setConfirmed(e.target.checked)}/>I understand locking is irreversible. Household assignments can still change without rewriting the URL.</label>}
      {running||recovering
        ?<button className="button secondary full" onClick={()=>controller.current?.abort()}>{recovering?'Cancel sticker search':'Stop writing'}</button>
        :<button className="button full" disabled={!isNative||(lock&&!confirmed)} onClick={start}>Start writing</button>}
      {message&&<p role="status" className="form-notice">{message}</p>}
      {lastResult&&<p className="form-notice">{lastResult}</p>}
      {error&&<p role="alert" className="form-error">{error}</p>}
      <p>{count} sticker{count===1?'':'s'} prepared this visit. Scan an unclaimed sticker later to choose a household chore and claim it.</p>
      <button className="text-button" disabled={!isNative||disabled||(lock&&!confirmed)} onClick={findWritten}>Find a written sticker to verify</button>
    </section>
    <FeedbackInbox/>
  </>
}
