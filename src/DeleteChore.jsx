export default function DeleteChore({chore,busy,onDelete,onCancel}){
  return <><p>Delete <strong>{chore.chore}</strong> from this household? Completed chores and earned points stay in the record. Its sticker becomes unassigned and can be claimed again.</p><div className="form-actions"><button className="button secondary" disabled={busy} onClick={onCancel}>Cancel</button><button className="button" disabled={busy} onClick={onDelete}>{busy?'Deleting…':'Delete chore'}</button></div></>
}
