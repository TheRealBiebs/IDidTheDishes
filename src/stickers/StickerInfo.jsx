import {useState} from 'react'

export default function StickerInfo({tag,binding,tags=[],bindings=[],busy,onAssign,onRelease,onReassign}){
 const [target,setTarget]=useState('')
 const choices=tags.filter(chore=>chore.id!==tag.id&&!bindings.some(link=>link.chore_tag_id===chore.id))
 return binding?<>
  <form onSubmit={e=>{e.preventDefault();onReassign(target)}}>
   <label>Assign sticker to another chore<select aria-label="Assign sticker to another chore" value={target} disabled={busy} onChange={e=>setTarget(e.target.value)} required><option value="">Choose a chore</option>{choices.map(chore=><option key={chore.id} value={chore.id}>{chore.chore}</option>)}</select></label>
   {!choices.length&&<p>No other chores need a sticker. Add a chore first, or release another chore’s sticker.</p>}
   <button className="button full" disabled={busy||!target}>Assign to this chore</button>
  </form>
  <button className="text-button" disabled={busy} onClick={onRelease}>Release this sticker</button>
  <p className="muted">Releasing lets another household claim the sticker. Chore history is preserved.</p>
 </>:<><p>No sticker assigned. Scan a prepared sticker to assign it to this chore.</p><button className="button full" disabled={busy} onClick={onAssign}>Scan a sticker to assign</button></>
}
export function StickerReleaseRequests({requests,busy,onReview}){
  if(!requests.length)return null
  return <section className="panel sticker-release-panel"><div className="panel-heading"><div><h2>Sticker release requests</h2></div></div>{requests.map(request=><div className="join-request-row" key={request.id}><div><strong>{request.chore}</strong><small>Requested by another household · {new Date(request.created_at).toLocaleDateString()}</small></div><div><button className="button secondary" disabled={busy} onClick={()=>onReview(request,false)}>Decline<span className="sr-only"> release of {request.chore}</span></button><button className="button" disabled={busy} onClick={()=>onReview(request,true)}>Review release<span className="sr-only"> of {request.chore}</span></button></div></div>)}</section>
}
