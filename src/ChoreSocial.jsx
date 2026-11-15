import { useEffect,useRef,useState } from 'react'
import { rpc } from './api'
import { supabase } from './supabase'
import './chore-social.css'

export default function ChoreSocial({completionId}) {
  const [data,setData]=useState(null),[body,setBody]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[offset,setOffset]=useState(0),[revision,setRevision]=useState(0)
  const pending=useRef(null)
  const [refuting,setRefuting]=useState(false),[reason,setReason]=useState(''),[confirmRemove,setConfirmRemove]=useState(null),[removed,setRemoved]=useState(false)
  const refuteRequest=useRef(null)
  useEffect(()=>{
    if(removed)return
    let active=true;setLoading(true)
    rpc('chore_social',{p_completion:completionId,p_offset:offset}).then(result=>{if(active){setData(result);setError('')}}).catch(e=>{if(active)setError(e.message)}).finally(()=>{if(active)setLoading(false)})
    return()=>{active=false}
  },[completionId,offset,revision,removed])
  useEffect(()=>{
    if(removed)return
    const refresh=()=>{if(document.visibilityState==='visible')setRevision(n=>n+1)}
    const channel=supabase.channel('chore-social:'+completionId+':'+crypto.randomUUID())
      .on('postgres_changes',{event:'*',schema:'public',table:'chore_likes',filter:`completion_id=eq.${completionId}`},refresh)
      .on('postgres_changes',{event:'*',schema:'public',table:'chore_comments',filter:`completion_id=eq.${completionId}`},refresh).subscribe()
    const timer=setInterval(refresh,30000);document.addEventListener('visibilitychange',refresh)
    return()=>{clearInterval(timer);document.removeEventListener('visibilitychange',refresh);supabase.removeChannel(channel)}
  },[completionId,removed])
  useEffect(()=>{
    if(removed)return
    const channel=supabase.channel('chore-refutations:'+completionId+':'+crypto.randomUUID()).on('postgres_changes',{event:'*',schema:'public',table:'chore_refutations',filter:`completion_id=eq.${completionId}`},()=>setRevision(n=>n+1)).subscribe()
    return()=>{supabase.removeChannel(channel)}
  },[completionId,removed])
  async function refute(e){e.preventDefault();if(busy)return;const text=reason.trim();if(refuteRequest.current?.reason!==text)refuteRequest.current={reason:text,id:crypto.randomUUID()};setBusy(true);setError('');try{await rpc('refute_chore',{p_completion:completionId,p_reason:text||null,p_request:refuteRequest.current.id});setRefuting(false);setReason('');refuteRequest.current=null;setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  async function resolve(id,action){if(busy)return;setBusy(true);setError('');try{const result=await rpc('resolve_chore_refutation',{p_refutation:id,p_action:action});setConfirmRemove(null);if(result.removed){setRemoved(true);window.dispatchEvent(new CustomEvent('chore-completion-removed',{detail:completionId}))}else setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  async function like(){setBusy(true);setError('');try{await rpc('set_chore_like',{p_completion:completionId,p_liked:!data.liked_by_me});setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  async function comment(e){e.preventDefault();const clean=body.trim();if(!clean||busy)return;if(pending.current?.body!==clean)pending.current={body:clean,id:crypto.randomUUID()};setBusy(true);setError('');try{await rpc('add_chore_comment',{p_completion:completionId,p_body:clean,p_request:pending.current.id});setBody('');pending.current=null;setOffset(0);setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  if(removed)return <p role="status">This completion and its points were removed.</p>
  return <section className="chore-social" aria-label="Comments and likes">
    <h3>Comments & likes</h3>
    {data&&<><div className="chore-social-actions"><button type="button" className="button secondary" aria-pressed={data.liked_by_me} disabled={busy||loading} onClick={like}>{data.liked_by_me?'♥ Liked':'♡ Like'}</button><span>{data.likes_count} {data.likes_count===1?'like':'likes'}</span></div>{data.liked_by.length>0&&<p className="social-liked-by">Liked by {data.liked_by.join(', ')}{data.likes_count>data.liked_by.length?` and ${data.likes_count-data.liked_by.length} others`:''}.</p>}
      <div className="chore-refutations">{(data.refutations||[]).map(refutation=><section className="chore-refutation" key={refutation.id}>
        <h4>{refutation.status==='pending'?'Chore refuted':refutation.status==='redone'?'Chore redone':'Completion removed'}</h4><p>{refutation.refuter_name} refuted this completion.</p>{refutation.reason&&<p className="refutation-reason">{refutation.reason}</p>}
        {refutation.status==='pending'?(data.is_doer?<><p>Choose to redo the chore and keep your original points, or remove this completion and its points.</p><div className="refutation-actions"><button type="button" className="button secondary" disabled={busy||loading} onClick={()=>resolve(refutation.id,'redone')}>Mark redone and keep points</button><button type="button" className="text-button" disabled={busy||loading} onClick={()=>setConfirmRemove(refutation.id)}>Remove completion</button></div>{confirmRemove===refutation.id&&<div className="refutation-confirm"><p>Remove this completion and its {data.completion.points} points from the record? Any archived weekly scores will also be corrected.</p><button type="button" className="button secondary" disabled={busy} onClick={()=>resolve(refutation.id,'removed')}>Confirm removal</button><button type="button" className="text-button" disabled={busy} onClick={()=>setConfirmRemove(null)}>Cancel removal</button></div>}</>:<p>Waiting for the original doer to respond. Points stay in place until they choose.</p>):refutation.status==='redone'&&<p>The doer marked the chore redone and kept the original points.</p>}
      </section>)}</div>
      {data.can_refute&&!refuting&&<button type="button" className="text-button refute-entry" disabled={busy||loading} onClick={()=>setRefuting(true)}>Refute this chore</button>}
      {data.can_refute&&refuting&&<form onSubmit={refute}><label>Why are you refuting this chore? (optional)<textarea rows={3} maxLength={1000} value={reason} onChange={e=>setReason(e.target.value)} disabled={busy}/></label><p>The doer will be notified and can redo the chore or remove the completion.</p><div className="refutation-actions"><button className="button secondary" disabled={busy}>Send refutation</button><button type="button" className="text-button" disabled={busy} onClick={()=>setRefuting(false)}>Cancel</button></div></form>}
      <ol className="chore-comments">{[...data.comments].reverse().map(comment=><li key={comment.id}><div><strong>{comment.display_name}</strong><time dateTime={comment.created_at}>{new Date(comment.created_at).toLocaleString(undefined,{month:'short',day:'numeric',hour:'numeric',minute:'2-digit'})}</time></div><p>{comment.body}</p></li>)}</ol>
      {!data.comments.length&&<p>No comments yet.</p>}
      {data.total_comments>50&&<nav className="social-pagination" aria-label="Comment pages"><button type="button" className="button secondary" disabled={!offset||loading} onClick={()=>setOffset(n=>Math.max(0,n-50))}>Newer comments</button><span>{offset+1}–{Math.min(offset+50,data.total_comments)} of {data.total_comments}</span><button type="button" className="button secondary" disabled={offset+50>=data.total_comments||loading} onClick={()=>setOffset(n=>n+50)}>Older comments</button></nav>}
      <form onSubmit={comment}><label>Leave a comment<textarea value={body} onChange={e=>setBody(e.target.value)} maxLength={1000} rows={3} required disabled={busy} placeholder="Aww, I wanted to do them!"/></label><button className="button" disabled={busy||!body.trim()}>{busy?'Saving…':'Post comment'}</button></form>
    </>}
    {loading&&!data&&<p role="status">Loading comments and likes…</p>}
    {error&&<div role="alert"><p className="form-error">{error}</p><button type="button" className="text-button" onClick={()=>setRevision(n=>n+1)}>Refresh comments and likes</button></div>}
  </section>
}
