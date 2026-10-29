import { App } from '@capacitor/app'
import { Browser } from '@capacitor/browser'
import { DishesNative, isNative, publicRoot, stickerToken } from './native'
import { supabase } from './supabase'

let lastUrl = '', lastTime = 0
let scanHandler = null
export function setNativeScanHandler(handler) { scanHandler = handler }
function report(message) { window.dispatchEvent(new CustomEvent('native-error', { detail: message })) }
async function handleUrl(value) {
  if (!value || (value === lastUrl && Date.now() - lastTime < 2000)) return
  lastUrl = value; lastTime = Date.now()
  try {
    const url = new URL(value)
    if (url.protocol === 'io.github.therealbiebs.ididthedishes:' && url.host === 'auth' && url.pathname === '/callback') {
      if (url.searchParams.has('error')) throw new Error(url.searchParams.get('error_description') || 'Sign-in was cancelled.')
      const code = url.searchParams.get('code')
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code)
        if (error) throw error
      }
      await Browser.close().catch(() => {})
      return
    }
    const root = new URL(publicRoot)
    if (url.origin !== root.origin || url.pathname !== root.pathname) return
    const token = stickerToken(value)
    if (scanHandler && token) { scanHandler(token); return }
    const target = new URL(location.href); target.search = ''; target.hash = ''
    for (const key of ['tag', 'invite', 'household']) {
      const v = url.searchParams.get(key)
      if (/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(v || '')) target.searchParams.set(key, v)
    }
    if (url.searchParams.get('view') === 'notifications') target.searchParams.set('view', 'notifications')
    history.pushState(null, '', target); window.dispatchEvent(new PopStateEvent('popstate'))
  } catch (error) { report(error.message) }
}
export async function initializeNative() {
  if (!isNative) return
  await App.addListener('appUrlOpen', ({ url }) => handleUrl(url))
  await DishesNative.addListener('tagScanned', ({ url }) => handleUrl(url))
  await DishesNative.addListener('scanError', ({ message }) => report(message))
  await App.addListener('appStateChange', ({ isActive }) => {
    if (isActive) supabase.auth.startAutoRefresh(); else supabase.auth.stopAutoRefresh()
  })
  const launch = await App.getLaunchUrl()
  if (launch?.url) await handleUrl(launch.url)
}
