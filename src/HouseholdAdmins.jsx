import { isHouseholdAdmin, canRemoveAdmin } from './household-access'

export function AdminMemberActions({ member, members, currentUser, busy, onAction }) {
  const admin = isHouseholdAdmin(member), self = member.user_id === currentUser
  return <div className="admin-member-actions"><button className="text-button" disabled={busy || (admin && !canRemoveAdmin(member, members))} onClick={() => onAction({ type: 'adminRole', member, makeAdmin: !admin })}>{admin ? self ? 'Step down as admin' : 'Remove admin role' : 'Make admin'}<span className="sr-only">: {member.display_name}</span></button>{!self && <button className="text-button" disabled={busy} onClick={() => onAction({ type: 'transferAdmin', member })}>Transfer my admin role<span className="sr-only"> to {member.display_name}</span></button>}{admin && !canRemoveAdmin(member, members) && <small>At least one admin is required. You can transfer your role to another member.</small>}</div>
}
export function AdminConfirmation({ action, busy, onConfirm, onCancel }) {
  const transfer = action.type === 'transferAdmin'
  return <><p>{transfer ? <>Transfer your admin role to <strong>{action.member.display_name}</strong>? They will be an admin and you will become a member. Any other admins keep their access.</> : action.makeAdmin ? <>Make <strong>{action.member.display_name}</strong> an admin? They can configure chores, invite members, manage household settings, and add or remove other admins.</> : <>Remove <strong>{action.member.display_name}</strong>’s admin role? They will remain a household member and can still log chores.</>}</p><div className="form-actions"><button className="button secondary" onClick={onCancel}>Cancel</button><button className="button" disabled={busy} onClick={onConfirm}>{busy ? 'Saving…' : transfer ? 'Transfer admin role' : action.makeAdmin ? 'Confirm make admin' : 'Confirm remove admin'}</button></div></>
}
