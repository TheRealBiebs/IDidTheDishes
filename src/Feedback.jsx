import {useEffect,useRef,useState} from 'react'
import {Capacitor} from '@capacitor/core'
import {rpc} from './api'
import {isStandalone} from './pwa'
import './feedback.css'

export const FEEDBACK_TYPES={general:'Feedback',idea:'Idea',bug:'Bug report'}
export function FeedbackForm({household,screen,onDone}){
  const [category,setCategory]=useState('general'),[message,setMessage]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState(''),[sent,setSent]=useState(false)
  const request=useRef(null),submitting=useRef(false)
  async function submit(e){
    e.preventDefault();if(submitting.current)return
    const text=message.trim();if(!text){setError('Please describe your feedback, idea, or bug.');return}
    const platform=Capacitor.isNativePlatform()?Capacitor.getPlatform():isStandalone()?'pwa':'web'
    const payload={p_category:category,p_message:text,p_household:household?.id||null,p_platform:platform,p_screen:screen||''},signature=JSON.stringify(payload)
    if(request.current?.signature!==signature)request.current={signature,id:crypto.randomUUID()}
    submitting.current=true;setBusy(true);setError('')
    try{await rpc('submit_app_feedback',{...payload,p_request:request.current.id});setSent(true)}catch(e){setError(e.message||'Could not send feedback. Please try again.')}finally{submitting.current=false;setBusy(false)}
  }
  if(sent)return <div className="feedback-success"><p role="status">Thanks! Your feedback has been sent to the app owner.</p><button className="button full" onClick={onDone}>Done</button></div>
  return <form className="feedback-form" onSubmit={submit}><label>Type<select aria-label="Feedback type" value={category} disabled={busy} onChange={e=>setCategory(e.target.value)}>{Object.entries(FEEDBACK_TYPES).map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label><label>Message<textarea aria-label="Message" name="message" value={message} disabled={busy} onChange={e=>setMessage(e.target.value)} rows={6} maxLength={4000} required placeholder={category==='bug'?'What happened? What did you expect, and how can we reproduce it?':category==='idea'?'What would you like Chip In to do?':'What’s working well, and what could be better?'}/></label><small className="feedback-privacy">Only the app’s platform admins can read this. Your account name and email, current screen, app platform, and {household?'household name':'household context (if any)'} are included for follow-up.</small>{error&&<p className="form-error" role="alert">{error}</p>}<button className="button full" disabled={busy||!message.trim()}>{busy?'Sending…':'Submit feedback'}</button></form>
}

export function FeedbackInbox(){
  const [status,setStatus]=useState(''),[offset,setOffset]=useState(0),[revision,setRevision]=useState(0),[data,setData]=useState(null),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState('')
  useEffect(()=>{let active=true;setLoading(true);setError('');rpc('platform_feedback',{p_status:status||null,p_offset:offset}).then(rows=>{if(active)setData(rows)}).catch(e=>{if(active)setError(e.message)}).finally(()=>{if(active)setLoading(false)});return()=>{active=false}},[status,offset,revision])
  async function review(row){setBusy(true);setError('');try{await rpc('review_app_feedback',{p_feedback:row.id,p_reviewed:row.status!=='reviewed'});setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  return <section className="panel feedback-inbox" aria-labelledby="feedback-inbox-title"><div className="feedback-inbox-heading"><h2 id="feedback-inbox-title">Feedback inbox</h2>{data&&<span className="pill">{data.new_count} new</span>}</div><div className="feedback-toolbar"><label>Show<select aria-label="Feedback status" value={status} disabled={busy} onChange={e=>{setStatus(e.target.value);setOffset(0)}}><option value="">All feedback</option><option value="new">New</option><option value="reviewed">Reviewed</option></select></label><button className="text-button" disabled={loading||busy} onClick={()=>setRevision(n=>n+1)}>Refresh feedback</button></div>{error&&<div role="alert" className="form-error"><p>{error}</p><button className="text-button" onClick={()=>setRevision(n=>n+1)}>Retry feedback inbox</button></div>}{loading?<p role="status">Loading feedback…</p>:!error&&data&&<><ol className="feedback-list">{data.feedback.map(row=><li key={row.id}><article><div className="feedback-item-heading"><h3>{FEEDBACK_TYPES[row.category]||'Feedback'}</h3><span className="pill">{row.status==='new'?'New':'Reviewed'}</span></div><p className="feedback-message">{row.message}</p><p className="feedback-author"><strong>{row.author_name||'Former account'}</strong>{row.author_email&&<span>{row.author_email}</span>}<time dateTime={row.created_at}>{new Date(row.created_at).toLocaleString()}</time></p><p className="feedback-context">{[row.household_name||'No household',row.platform,row.screen].filter(Boolean).join(' · ')}</p><button className="button secondary" disabled={busy} onClick={()=>review(row)}>{row.status==='new'?'Mark reviewed':'Mark new'}</button></article></li>)}</ol>{!data.feedback.length&&<p>No {status==='reviewed'?'reviewed ':status==='new'?'new ':''}feedback yet.</p>}{(data.total>25||offset>0)&&<nav className="feedback-pagination" aria-label="Feedback pages"><button className="button secondary" disabled={!offset||busy} onClick={()=>setOffset(n=>Math.max(0,n-25))}>Previous</button><span>{data.feedback.length?`${offset+1}–${offset+data.feedback.length} of ${data.total}`:`${data.total} results`}</span><button className="button secondary" disabled={offset+25>=data.total||busy} onClick={()=>setOffset(n=>n+25)}>Next</button></nav>}</>}</section>
}
