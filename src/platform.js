import { rpc } from './api'
import config from './push-config.json'
import { isNative, DishesNative, publicRoot } from './native'
import { setNativeScanHandler } from './native-lifecycle'

export const siteRoot = () => isNative ? publicRoot : new URL(import.meta.env.BASE_URL, location.href).href
export const tagLink = token => `${siteRoot()}?tag=${encodeURIComponent(token)}`
export const inviteLink = code => `${siteRoot()}?invite=${encodeURIComponent(code)}`

// Browser adapter. Future native NFC/push adapters can use the same API contracts.
export async function writeSticker(token, signal) {
  if (isNative) {
    const cancel = () => DishesNative.cancelWrite().catch(() => {})
    if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
    signal?.addEventListener('abort', cancel, { once: true })
    try { await DishesNative.writeTag({ url: tagLink(token) }); return }
    finally { signal?.removeEventListener('abort', cancel) }
  }
  if (!('NDEFReader' in window)) throw new Error('Use an NFC-writing app to write the sticker link shown below. Browser writing requires a supported Android browser.')
  const writer = new window.NDEFReader()
  await writer.write({ records: [{ recordType: 'url', data: tagLink(token) }] }, { signal })
}

export async function scanSticker(onToken, signal) {
  if (isNative) {
    if (signal?.aborted) return
    setNativeScanHandler(onToken)
    signal?.addEventListener('abort', () => setNativeScanHandler(null), { once: true })
    try { await DishesNative.checkNfc() } catch (error) { setNativeScanHandler(null); throw error }
    return
  }
  if (!('NDEFReader' in window)) throw new Error('Tap a programmed sticker with your phone. To set up a blank sticker on iPhone, copy its link into an NFC-writing app.')
  const reader = new window.NDEFReader()
  reader.onreading = event => {
    for (const record of event.message.records) {
      if (record.recordType !== 'url') continue
      try {
        const url = new URL(new TextDecoder(record.encoding || 'utf-8').decode(record.data))
        if (url.origin !== location.origin || url.pathname !== new URL(siteRoot()).pathname) continue
        const token = url.searchParams.get('tag')
        if (token) { onToken(token); return }
      } catch { /* Ignore unrelated stickers. */ }
    }
  }
  reader.onreadingerror = () => onToken(null)
  await reader.scan({ signal })
}

export async function enablePush() {
  if (isNative) throw new Error('Android background notifications need Firebase setup. For now, enable phone notifications in the Chrome version of this app. Your in-app inbox still works.')
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) throw new Error('On iPhone, add this site to your Home Screen, open it there, then enable notifications. Otherwise use a browser with Web Push support.')
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') throw new Error('Notifications were not enabled. You can allow them in your browser’s site settings.')
  await navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`, { scope: import.meta.env.BASE_URL })
  const registration = await navigator.serviceWorker.ready
  const bytes = Uint8Array.from(atob(config.publicKey.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4-config.publicKey.length%4)%4)), c => c.charCodeAt(0))
  let subscription = await registration.pushManager.getSubscription() || await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: bytes })
  try { await rpc('save_subscription', { p_subscription: subscription.toJSON() }) }
  catch (error) {
    if (!error.message.includes('belongs to another account')) throw error
    await subscription.unsubscribe()
    subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: bytes })
    await rpc('save_subscription', { p_subscription: subscription.toJSON() })
  }
  return true
}

export async function disablePush() {
  if (isNative) return
  const registration = await navigator.serviceWorker?.getRegistration(import.meta.env.BASE_URL)
  const subscription = await registration?.pushManager.getSubscription()
  if (subscription) {
    await rpc('remove_subscription', { p_endpoint: subscription.endpoint })
    await subscription.unsubscribe()
  }
}

export async function hasPush(userId, supabase) {
  if (isNative) return false
  const registration = await navigator.serviceWorker?.getRegistration(import.meta.env.BASE_URL)
  const subscription = await registration?.pushManager.getSubscription()
  if (!subscription) return false
  const { data } = await supabase.from('push_subscriptions').select('id').eq('user_id', userId).eq('endpoint', subscription.endpoint).maybeSingle()
  return Boolean(data)
}
