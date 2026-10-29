import { supabase, supabasePublicConfig } from './supabase'
import { authRedirectUrl, isNative } from './native'
import { Browser } from '@capacitor/browser'

const pendingKey = 'dishes-oauth-return'
const allowed = ['tag', 'invite', 'household']
const isUuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value || '')

export async function signInWithGoogle() {
  const response = await fetch(`${supabasePublicConfig.url}/auth/v1/settings`, {
    headers: { apikey: supabasePublicConfig.key },
    signal: AbortSignal.timeout(10000),
  })
  if (!response.ok) throw new Error('Unable to reach sign-in. Please try again.')
  const settings = await response.json()
  if (!settings.external?.google) throw new Error('Google sign-in is not available yet. The app owner needs to finish enabling Google in Supabase.')

  // Keep NFC/invitation intent on this device. Redirect only to the allowlisted root.
  const current = new URL(location.href)
  const query = new URLSearchParams()
  for (const key of allowed) if (isUuid(current.searchParams.get(key))) query.set(key, current.searchParams.get(key))
  if (current.searchParams.get('view') === 'notifications') query.set('view', 'notifications')
  sessionStorage.setItem(pendingKey, JSON.stringify({ time: Date.now(), query: query.toString() }))
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: authRedirectUrl(), skipBrowserRedirect: isNative, queryParams: { prompt: 'select_account' } },
  })
  if (error) { sessionStorage.removeItem(pendingKey); throw error }
  if (isNative) await Browser.open({ url: data.url })
}

export function restoreGoogleDestination() {
  let pending
  try {
    pending = JSON.parse(sessionStorage.getItem(pendingKey) || 'null')
    sessionStorage.removeItem(pendingKey)
  } catch { return false }
  if (!pending || !Number.isFinite(pending.time) || Date.now() - pending.time > 15 * 60 * 1000) return false
  const query = new URLSearchParams(pending.query)
  const url = new URL(location.href)
  let changed = false
  for (const key of allowed) if (!url.searchParams.has(key) && isUuid(query.get(key))) { url.searchParams.set(key, query.get(key)); changed = true }
  if (!url.searchParams.has('view') && query.get('view') === 'notifications') { url.searchParams.set('view', 'notifications'); changed = true }
  if (changed) history.replaceState(null, '', url)
  return changed
}
