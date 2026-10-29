import { supabase } from './supabase'

export async function rpc(name, parameters = {}) {
  const { data, error } = await supabase.rpc(name, parameters)
  if (error) throw error
  return data
}

async function read(table, configure = q => q) {
  const { data, error } = await configure(supabase.from(table).select('*'))
  if (error) throw error
  return data
}

export const api = {
  households: () => read('households', q => q.order('created_at')),
  joinRequests: id => read('household_join_requests', q => q.eq('household_id', id).eq('status', 'pending').order('created_at')),
  releaseRequests: id => read('sticker_release_requests', q => q.eq('owner_household_id', id).eq('status', 'pending').order('created_at')),
  members: id => read('household_members', q => q.eq('household_id', id).order('joined_at')),
  teams: id => read('household_teams', q => q.eq('household_id', id).order('created_at')),
  tags: id => read('chore_tags', q => q.eq('household_id', id).order('created_at')),
  activity: (id, since) => read('chore_completions', q => q.eq('household_id', id).gte('chore_date', since).order('completed_at', { ascending: false }).limit(3000)),
  notifications: () => read('notifications', q => q.order('created_at', { ascending: false }).limit(100)),
}

export function localDate(timezone, date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date)
}

export function weekStart(timezone) {
  const today = localDate(timezone)
  const date = new Date(today + 'T12:00:00Z')
  date.setUTCDate(date.getUTCDate() - (date.getUTCDay() + 6) % 7)
  return date.toISOString().slice(0, 10)
}
