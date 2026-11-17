import { chorePeriodView } from './stickers/schedule'
import { completionReward } from './rewards/registry'
import './assignments.css'

export const ASSIGNMENT_TITLES={daily:'Assigned today',weekly:'Assigned this week',monthly:'Assigned this month'}
export default function AssignedChores({rows,loading,onOpen}) {
  return <div className="assigned-grid">{Object.entries(ASSIGNMENT_TITLES).map(([frequency])=>{
    const {chores,title}=chorePeriodView(rows,frequency)
    return <button type="button" className="panel assigned-tile" aria-haspopup="dialog" key={frequency} onClick={()=>onOpen(frequency,title)}>
      <span className="assigned-heading">{title}</span><strong className="assigned-count">{loading?'—':chores.length}</strong>
      <span>{loading?'Loading assignments…':chores.length?chores.slice(0,3).map(c=>c.chore).join(' · '):'No chores available.'}</span>
    </button>
  })}</div>
}

export function AssignedChoreList({rows,reward}) {
  return <div className="assigned-list">{rows.length?<><p className="muted">Complete these chores by scanning their stickers. Assignments and completion limits follow each chore’s settings.</p><ul>{rows.map(row=><li key={row.id}>
    <strong>{row.chore}</strong><span>{row.location||'Around the house'}</span>
    <span>{row.remaining} of {row.daily_limit} still needed · {completionReward(reward,row.points)}</span>
  </li>)}</ul></>:<p>No chores available for this period.</p>}</div>
}
