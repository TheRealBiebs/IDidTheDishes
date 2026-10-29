import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import webpush from 'npm:web-push@3.6.7'
import { createFcmSender } from './fcm.js'

// Only the database webhook can dispatch. No browser may invoke a push batch.
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } })
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
const allowedHosts = /^(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|[a-zA-Z0-9-]+\.notify\.windows\.com)$/
let fcmConfiguration = '', fcmSender: ReturnType<typeof createFcmSender> | undefined

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const supplied = request.headers.get('x-webhook-secret')
  if (!supplied) return json({ error: 'Unauthorized' }, 401)
  const { data: secrets, error: configError } = await db.rpc('push_runtime')
  if (configError || !secrets?.dishes_push_webhook) return json({ error: 'Push is not configured' }, 503)
  const equal = (a: string, b: string) => {
    if (a.length !== b.length) return false
    let result = 0; for (let i=0;i<a.length;i++) result |= a.charCodeAt(i)^b.charCodeAt(i)
    return result === 0
  }
  if (!equal(supplied, secrets.dishes_push_webhook)) return json({ error: 'Unauthorized' }, 401)
  const { data: jobs, error } = await db.rpc('claim_push_jobs')
  if (error) return json({ error: 'Unable to claim notification jobs' }, 500)
  if (secrets.dishes_vapid_public && secrets.dishes_vapid_private) webpush.setVapidDetails('https://therealbiebs.github.io/IDidTheDishes/', secrets.dishes_vapid_public, secrets.dishes_vapid_private)
  const results = await Promise.all(jobs.map(async (job: any) => {
    let success = false, expired = false, message = ''
    try {
      if (job.subscription.platform === 'android') {
        if (!secrets.dishes_fcm_service_account) throw new Error('Firebase credentials are not configured')
        if (!fcmSender || fcmConfiguration !== secrets.dishes_fcm_service_account) {
          fcmSender = createFcmSender(JSON.parse(secrets.dishes_fcm_service_account))
          fcmConfiguration = secrets.dishes_fcm_service_account
        }
        const result = await fcmSender(job)
        success = result.success; expired = result.expired; message = result.message
      } else {
      const endpoint = new URL(job.subscription.endpoint)
      if (endpoint.protocol !== 'https:' || !allowedHosts.test(endpoint.hostname) || endpoint.port || endpoint.username || endpoint.password) throw new Error('Unsupported push endpoint')
      const payload = JSON.stringify({ title: 'A little win at home', body: job.message, id: job.notification_id, url: `https://therealbiebs.github.io/IDidTheDishes/?household=${job.household_id}&view=notifications` })
      const details = webpush.generateRequestDetails(job.subscription, payload, { TTL: 3600, urgency: 'normal' })
      const response = await fetch(details.endpoint, { method: details.method, headers: details.headers, body: details.body, redirect: 'error', signal: AbortSignal.timeout(10000) })
      success = response.ok; expired = [404,410].includes(response.status)
      message = success ? '' : `Push service returned ${response.status}`
      await response.body?.cancel()
      }
    } catch { message = 'Push delivery failed; check transport configuration or connectivity' }
    const { error: finishError } = await db.rpc('finish_push_job', { p_job: job.id, p_success: success, p_expired: expired, p_error: message })
    return { success, recorded: !finishError }
  }))
  return json({ processed: results.length, delivered: results.filter(r=>r.success).length })
})
