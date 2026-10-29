import { PushNotifications } from '@capacitor/push-notifications'
import { isNative, nativeStorage, DishesNative } from './native'
import { supabase } from './supabase'
import { rpc } from './api'

const storageKey = 'dishes-native-push-v1'
let initialized, pending, registrationTail = Promise.resolve()
const readState = async () => {
  try { return JSON.parse(await nativeStorage.getItem(storageKey) || 'null') } catch { return null }
}
const writeState = value => nativeStorage.setItem(storageKey, JSON.stringify(value))
const emitError = message => window.dispatchEvent(new CustomEvent('native-error', { detail: message }))

async function saveToken(token) {
  const state = await readState()
  const { data: { session } } = await supabase.auth.getSession()
  if (!state?.enabled || state.userId !== session?.user.id) return false
  if (!/^[A-Za-z0-9:_-]{20,4096}$/.test(token || '')) throw new Error('Firebase returned an invalid device token.')
  await rpc('save_native_subscription', { p_token: token })
  const current = await readState()
  if (!current?.enabled || current.userId !== state.userId) {
    await rpc('remove_subscription', { p_endpoint: `fcm:${token}` }); return false
  }
  await writeState({ ...current, token })
  if (state.token && state.token !== token) await rpc('remove_subscription', { p_endpoint: `fcm:${state.token}` })
  return true
}

export function initializeNativePush(openUrl) {
  if (!isNative) return Promise.resolve()
  if (initialized) return initialized
  initialized = (async () => {
    await PushNotifications.addListener('registration', ({ value }) => {
      registrationTail = registrationTail.catch(() => {}).then(() => saveToken(value))
      registrationTail.then(saved => {
        if (pending) { const p = pending; pending = null; saved ? p.resolve(true) : p.reject(new Error('Please sign in and enable notifications again.')) }
      }).catch(error => {
        if (pending) { const p = pending; pending = null; p.reject(error) }
        else emitError('Could not update phone notifications. Open household settings and enable them again.')
      })
    })
    await PushNotifications.addListener('registrationError', () => {
      if (pending) { const p = pending; pending = null; p.reject(new Error('Could not register with Firebase. Check your internet connection and Google Play services.')) }
    })
    await PushNotifications.addListener('pushNotificationActionPerformed', event => {
      const url = event.notification?.data?.url
      if (typeof url === 'string') openUrl(url)
    })
    await PushNotifications.addListener('pushNotificationReceived', notification => {
      window.dispatchEvent(new CustomEvent('native-notification', { detail: notification.body || 'Someone completed a chore. Open your notification inbox for details.' }))
    })
    await PushNotifications.createChannel({ id: 'chores', name: 'Household chores', description: 'When someone in your household completes a chore', importance: 4, vibration: true })
  })().catch(error => { initialized = null; throw error })
  return initialized
}

async function registerDevice() {
  if (pending) throw new Error('Notification registration is already in progress.')
  let timer
  const result = new Promise((resolve, reject) => {
    pending = { resolve, reject }
    timer = setTimeout(() => { pending = null; reject(new Error('Firebase registration timed out. Check your connection and try again.')) }, 20000)
  })
  try {
    // Attach handlers before register: the native token event may arrive immediately.
    const registration = PushNotifications.register().catch(error => {
      if (pending) { const p = pending; pending = null; p.reject(error) }
    })
    const enabled = await result
    await registration
    return enabled
  } finally { clearTimeout(timer); pending = null }
}

export async function enableNativePush() {
  await initialized
  if (!initialized) throw new Error('Phone notifications are still starting. Try again in a moment.')
  let permission = await PushNotifications.checkPermissions()
  if (permission.receive !== 'granted') permission = await PushNotifications.requestPermissions()
  if (permission.receive !== 'granted') throw new Error('Allow notifications in Android Settings → Apps → I Did The Dishes → Notifications.')
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) throw new Error('Please sign in first.')
  const previous = await readState()
  if (previous?.userId && previous.userId !== session.user.id) await disableNativePush()
  await writeState({ userId: session.user.id, enabled: true, token: previous?.userId === session.user.id ? previous.token : null })
  try { return await registerDevice() }
  catch (error) { await disableNativePush().catch(() => {}); throw error }
}

export async function disableNativePush() {
  const state = await readState()
  await writeState({ enabled: false })
  if (pending) { const p = pending; pending = null; p.reject(new Error('Notification registration cancelled.')) }
  // Capacitor's unregister resolves before Firebase finishes deleting the token.
  // Wait for deletion before another account can register this device.
  await DishesNative.unregisterPush()
  await PushNotifications.removeAllDeliveredNotifications()
  if (state?.token) await rpc('remove_subscription', { p_endpoint: `fcm:${state.token}` })
}

export async function hasNativePush(userId) {
  await initialized
  const state = await readState()
  if (!state?.enabled) return false
  if (state.userId !== userId || (await PushNotifications.checkPermissions()).receive !== 'granted') {
    await disableNativePush(); return false
  }
  try { return await registerDevice() }
  catch { return false }
}
