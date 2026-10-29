export function scanAction(info, { signedIn, installed, canClaim, configuring = false }) {
  if (!info || info.status === 'invalid') return 'invalid'
  if (!signedIn) return 'public'
  if (info.status === 'available') return canClaim ? 'claim' : 'unassigned'
  if (info.status === 'preparing') return 'preparing'
  if (!info.member) return 'foreign'
  if (configuring && info.admin) return 'configure'
  return installed ? 'complete' : 'member-preview'
}
