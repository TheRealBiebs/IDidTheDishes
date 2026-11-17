// null follows the daily limit; zero explicitly disables the cooldown.
export function automaticCooldown(dailyLimit) {
  return dailyLimit > 1 ? Math.max(1, Math.round(720 / dailyLimit)) : 0
}

export function cooldownMinutes(tag) {
  if (tag.frequency && tag.frequency !== 'daily') return 0
  return tag.daily_limit > 1 ? (tag.cooldown_minutes ?? automaticCooldown(tag.daily_limit)) : 0
}

export function cooldownDuration(minutes) {
  const hours = Math.floor(minutes / 60), remainder = minutes % 60
  return [hours && `${hours}h`, remainder && `${remainder}m`].filter(Boolean).join(' ') || '0m'
}
