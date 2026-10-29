// Server-only FCM HTTP v1 transport. Never import this into the React app.
const oauthUrl = 'https://oauth2.googleapis.com/token'
const base64url = bytes => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
const encode = value => base64url(new TextEncoder().encode(JSON.stringify(value)))

export function createFcmSender(credentials, fetcher = fetch) {
  if (!credentials || !/^[a-z][a-z0-9-]{4,62}$/.test(credentials.project_id || '') ||
      !credentials.client_email?.endsWith('.iam.gserviceaccount.com') || !credentials.private_key) throw new Error('Firebase credentials are not configured')
  let cachedToken, tokenExpires = 0, inFlight
  async function accessToken() {
    if (cachedToken && tokenExpires > Date.now() + 60000) return cachedToken
    if (inFlight) return inFlight
    inFlight = (async () => {
      const now = Math.floor(Date.now() / 1000)
      const signingInput = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({ iss: credentials.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: oauthUrl, iat: now, exp: now + 3600 })}`
      const pem = credentials.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '')
      const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
      const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput))
      const response = await fetcher(oauthUrl, {
        method: 'POST', body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${signingInput}.${base64url(new Uint8Array(signature))}` }),
        redirect: 'error', signal: AbortSignal.timeout(10000),
      })
      if (!response.ok) { await response.body?.cancel(); throw new Error(`Firebase authorization returned ${response.status}`) }
      const body = await response.json()
      if (!body.access_token || !Number.isFinite(body.expires_in)) throw new Error('Invalid Firebase authorization response')
      cachedToken = body.access_token; tokenExpires = Date.now() + body.expires_in * 1000
      return cachedToken
    })().finally(() => { inFlight = null })
    return inFlight
  }
  return async function send(job) {
    const token = job.subscription.token
    if (job.subscription.platform !== 'android' || !/^[A-Za-z0-9:_-]{20,4096}$/.test(token || '')) throw new Error('Invalid Android notification subscription')
    const url = `https://therealbiebs.github.io/IDidTheDishes/?household=${encodeURIComponent(job.household_id)}&view=notifications`
    const response = await fetcher(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(credentials.project_id)}/messages:send`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
      headers: { Authorization: `Bearer ${await accessToken()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: {
        token, notification: { title: 'A little win at home', body: job.message.slice(0, 500) },
        data: { url, notification_id: job.notification_id, household_id: job.household_id },
        android: { priority: 'HIGH', ttl: '3600s', notification: { channel_id: 'chores', icon: 'ic_stat_dishes', tag: job.notification_id } },
      } }),
    })
    if (response.ok) { await response.body?.cancel(); return { success: true, expired: false, message: '' } }
    const error = await response.json().catch(() => ({}))
    const fcmError = error.error?.details?.find(detail => detail['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError')?.errorCode
    if (response.status === 401) { cachedToken = null; tokenExpires = 0 }
    return { success: false, expired: fcmError === 'UNREGISTERED', message: `FCM returned ${response.status}${fcmError ? ` (${fcmError})` : ''}` }
  }
}
