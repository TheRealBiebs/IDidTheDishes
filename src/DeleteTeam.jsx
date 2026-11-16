export default function DeleteTeam({team,members=[],chores=[],busy,onDelete,onCancel}){
  const memberCount=members.filter(member=>member.team_id===team.id).length
  const choreCount=chores.filter(chore=>chore.assigned_team_id===team.id).length
  return <><p>Delete <strong>{team.name}</strong>? This cannot be undone.</p><ul className="team-delete-warning"><li>{memberCount} member{memberCount===1?'':'s'} will be unassigned and can choose another team.</li><li>{choreCount} assigned chore{choreCount===1?'':'s'} will become unassigned and available to eligible household members.</li><li>Personal points, completed chores, and past weekly results are preserved. Current-week team totals change when members join another team.</li></ul><div className="form-actions"><button className="button secondary" disabled={busy} onClick={onCancel}>Cancel</button><button className="button danger-action" disabled={busy} onClick={onDelete}>{busy?'Deleting…':'Delete team'}</button></div></>
}
