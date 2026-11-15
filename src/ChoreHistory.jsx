import { useEffect, useState } from 'react'
import { api } from './api'
import { completionReward } from './rewards/registry'
import { CompletionDetailView } from './stickers/CompletionDetails'
import './chore-history.css'

const dayLabel = day => new Date(day+'T12:00:00Z').toLocaleDateString(undefined, {timeZone:'UTC',month:'short',day:'numeric',year:'numeric'})

export default function ChoreHistory({selection,members,reward}) {
  const [offset,setOffset]=useState(0),[data,setData]=useState(null),[busy,setBusy]=useState(true),[error,setError]=useState(''),[retry,setRetry]=useState(0)
  useEffect(()=>{
    let active=true;setBusy(true);setError('')
    api.choreHistory({...selection,offset}).then(rows=>{if(active)setData(rows)})
      .catch(e=>{if(active)setError(e.message||'Unable to load chores.')})
      .finally(()=>{if(active)setBusy(false)})
    return()=>{active=false}
  },[selection,offset,retry])
  return <div className="chore-history">
    <p className="muted">{dayLabel(selection.from)}{selection.from!==selection.through?` – ${dayLabel(selection.through)}`:''} · {selection.timezone}</p>
    {busy?<p role="status">Loading chores…</p>:error?<div role="alert"><p className="form-error">{error}</p><button className="button secondary" onClick={()=>setRetry(n=>n+1)}>Retry loading chores</button></div>:<>
      <ol className="chore-history-list">{data.chores.map(chore=><HistoryEntry key={chore.id} chore={chore} member={members.find(m=>m.user_id===chore.user_id)?.display_name||'Former household member'} timezone={selection.timezone} reward={reward}/>)}</ol>
      {!data.chores.length&&<p className="empty-inline">No chores logged for this selection.</p>}
      {data.total>50&&<nav className="chore-history-pagination" aria-label="Chore history pages">
        <button className="button secondary" disabled={offset===0} onClick={()=>setOffset(n=>Math.max(0,n-50))}>Previous</button>
        <span>{data.chores.length?`${offset+1}–${offset+data.chores.length} of ${data.total}`:'0 chores'}</span>
        <button className="button secondary" disabled={offset+50>=data.total} onClick={()=>setOffset(n=>n+50)}>Next</button>
      </nav>}
    </>}
  </div>
}

function HistoryEntry({chore,member,timezone,reward}) {
  const [expanded,setExpanded]=useState(false)
  return <li>
    <div className="chore-history-entry"><strong>{chore.chore}</strong><span>{completionReward(reward,chore.points)}</span></div>
    <small>{member} · {new Date(chore.completed_at).toLocaleString(undefined,{timeZone:timezone,month:'short',day:'numeric',hour:'numeric',minute:'2-digit'})}</small>
    <details onToggle={e=>setExpanded(e.currentTarget.open)}><summary>Details</summary>{expanded&&<CompletionDetailView completion={chore}/>}</details>
  </li>
}
