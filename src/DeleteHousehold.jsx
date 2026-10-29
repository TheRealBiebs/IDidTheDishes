import { useState } from 'react'

export default function DeleteHousehold({ household, busy, onCancel, onDelete }) {
  const [confirmation,setConfirmation]=useState('')
  return <form onSubmit={e=>{e.preventDefault();if(confirmation===household.name)onDelete(confirmation)}}>
    <p>This permanently deletes <strong>{household.name}</strong> for every member, including its chores, teams, points, completion history, invitations, and notifications. This cannot be undone.</p>
    <p>Claimed stickers become unassigned and can be claimed again. Member accounts and other households are kept.</p>
    <label>Type the household name to confirm<input autoComplete="off" value={confirmation} onChange={e=>setConfirmation(e.target.value)} required/></label>
    <div className="form-actions"><button type="button" className="button secondary" disabled={busy} onClick={onCancel}>Cancel</button><button className="button danger" disabled={busy||confirmation!==household.name}>{busy?'Deleting…':'Permanently delete household'}</button></div>
  </form>
}
