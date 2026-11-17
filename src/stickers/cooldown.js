// null follows the selected period’s completion limit; zero disables the wait.
export function automaticCooldown(dailyLimit) {
  return dailyLimit > 1 ? Math.max(1, Math.round(720 / dailyLimit)) : 0
}

export function cooldownMinutes(tag) {
  return tag.cooldown_minutes ?? automaticCooldown(tag.daily_limit)
}

export function cooldownDuration(minutes) {
  const days = Math.floor(minutes / 1440), hours = Math.floor(minutes % 1440 / 60), remainder = minutes % 60
  return [days && `${days}d`, hours && `${hours}h`, remainder && `${remainder}m`].filter(Boolean).join(' ') || '0m'
}
