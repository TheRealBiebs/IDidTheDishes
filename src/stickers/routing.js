export function scanAction(info, { signedIn, canClaim, configuring = false }) {
  if (!info || info.status === 'invalid') return 'invalid'
  if (!signedIn) return 'public'
  if (info.status === 'available') return configuring && canClaim ? 'claim' : 'unassigned'
  if (info.status === 'preparing') return 'preparing'
  if (!info.member) return 'foreign'
  if (configuring && info.admin) return 'configure'
  return 'complete'
}
