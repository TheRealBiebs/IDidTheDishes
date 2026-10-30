import { useEffect,useRef,useState } from 'react'
import { QUALITY_CHOICES,CONDITION_CHOICES } from './chore-details'
import { saveCompletionDetails,proofUrl } from './proof-api'

export default function CompletionDetails({completion,onSaved,onLog,onPendingChange,busy=false}){
  const [quality,setQuality]=useState(completion?.quality||''),[condition,setCondition]=useState(completion?.starting_condition||''),[comment,setComment]=useState(completion?.comment||''),[photo,setPhoto]=useState(null),[preview,setPreview]=useState(''),[saving,setSaving]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState('')
  const photoCache=useRef(null),savedVersion=useRef(0)
  const [version,setVersion]=useState(0)
  function dirty(){setVersion(n=>n+1);setError('');setNotice('')}
  useEffect(()=>{onPendingChange?.(saving||(version!==savedVersion.current&&!error))},[saving,version,error,notice,onPendingChange])
  useEffect(()=>()=>onPendingChange?.(false),[onPendingChange])
  useEffect(()=>{
    if(!completion||version===savedVersion.current||saving||error)return
    const timer=setTimeout(()=>submit(),650)
    return()=>clearTimeout(timer)
  },[completion?.id,version,saving,error])
  useEffect(()=>{if(!photo){setPreview('');return}const url=URL.createObjectURL(photo);setPreview(url);return()=>URL.revokeObjectURL(url)},[photo])
  async function submit(e){e?.preventDefault();if(saving)return;const snapshotVersion=version;setSaving(true);setError('');setNotice('');const details={quality,starting_condition:condition,comment,photo};try{
    if(completion){const updated=await saveCompletionDetails(completion,details,photoCache);savedVersion.current=snapshotVersion;onSaved(updated);setNotice('Details saved. Your household can view them.')}else await onLog(details)
  }catch(e){setError(e.message)}finally{setSaving(false)}}
  const disabled=busy
  return <form className="completion-details" onSubmit={submit} onChange={dirty}><div className="details-heading"><h2>{completion?'Add the little details':'How did it go?'}</h2><p>Everything here is optional. Changes save automatically to this completion. Photos and comments are shared only with household members.</p></div><fieldset disabled={disabled}><legend>This chore was performed…</legend>{QUALITY_CHOICES.map(([value,label])=><label className="detail-radio" key={value}><input type="radio" name="quality" value={value} checked={quality===value} onChange={()=>setQuality(value)}/>{label}</label>)}{quality&&<button className="text-button" type="button" onClick={()=>{setQuality('');dirty()}}>Clear quality</button>}</fieldset><fieldset disabled={disabled}><legend>The starting state was…</legend>{CONDITION_CHOICES.map(([value,label])=><label className="detail-radio" key={value}><input type="radio" name="starting_condition" value={value} checked={condition===value} onChange={()=>setCondition(value)}/>{label}</label>)}{condition&&<button className="text-button" type="button" onClick={()=>{setCondition('');dirty()}}>Clear starting state</button>}</fieldset><label>Comment<textarea name="comment" rows={3} maxLength={2000} value={comment} disabled={disabled} onChange={e=>setComment(e.target.value)} placeholder="Anything your household should know?"/></label><label className="photo-proof-input">Photo proof (optional)<input type="file" accept="image/*" disabled={disabled} onChange={e=>{setPhoto(e.target.files?.[0]||null);photoCache.current=null;setError('');setNotice('')}}/><small>Take a photo or choose one from your library. Images are resized before upload.</small></label>{preview&&<><img className="proof-preview" src={preview} alt="Selected photo proof preview"/><button className="text-button" type="button" disabled={disabled} onClick={()=>{setPhoto(null);photoCache.current=null;dirty()}}>Remove selected photo</button></>}{completion?.proof_path&&!photo&&<ProofPhoto path={completion.proof_path}/>}<p className="details-footnote">These details describe the chore; they don’t change its reward.</p>{error&&<p role="alert" className="form-error">{error}</p>}{saving&&<p role="status">Saving optional details…</p>}{notice&&version===savedVersion.current&&<p role="status" className="form-notice">{notice}</p>}{(!completion||error)&&<button className="button full" disabled={disabled||saving}>{saving?'Saving…':completion?'Retry saving details':'Log this chore'}</button>}</form>
}
export function ProofPhoto({path}){
  const [url,setUrl]=useState(''),[error,setError]=useState('')
  useEffect(()=>{let active=true;setUrl('');setError('');proofUrl(path).then(value=>{if(active)setUrl(value)}).catch(()=>{if(active)setError('Photo proof could not be loaded. Reopen this view to try again.')});return()=>{active=false}},[path])
  return error?<p className="form-error">{error}</p>:url?<a href={url} target="_blank" rel="noreferrer"><img className="proof-preview" src={url} alt="Photo proof of the completed chore"/></a>:<p>Loading private photo…</p>
}
export function CompletionDetailView({completion}){
  return <div className="completion-details"><p>Performed: <strong>{QUALITY_CHOICES.find(([id])=>id===completion.quality)?.[1]||'Not specified'}</strong></p><p>Starting state: <strong>{CONDITION_CHOICES.find(([id])=>id===completion.starting_condition)?.[1]||'Not specified'}</strong></p>{completion.comment&&<p className="completion-comment">{completion.comment}</p>}{completion.proof_path&&<ProofPhoto path={completion.proof_path}/>}</div>
}
