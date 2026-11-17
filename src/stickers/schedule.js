export const FREQUENCIES = {daily:'day',weekly:'week',monthly:'month'}
export const frequencyLabel = chore => FREQUENCIES[chore.frequency] || 'day'
export const assignedPending = (rows,frequency) => rows.filter(row=>row.active&&row.assigned_to_me&&row.frequency===frequency&&row.remaining>0)
export const unassignedAvailable = rows => rows.filter(row=>row.active&&!row.assigned_team_id&&!row.eligible_users?.length&&row.eligible&&row.remaining>0)

export function chorePeriodView(rows,frequency){
 const assigned=assignedPending(rows,frequency)
 const chores=assigned.length?assigned:unassignedAvailable(rows).filter(row=>row.frequency===frequency)
 const period={daily:'today',weekly:'this week',monthly:'this month'}[frequency]
 return {chores,assigned:assigned.length>0,title:(assigned.length?'Assigned ':'Available ')+period}
}
