import test from 'node:test'
import assert from 'node:assert/strict'
import { generateKeyPairSync, verify } from 'node:crypto'
import { createFcmSender } from '../supabase/functions/chore-push/fcm.js'

const pair = generateKeyPairSync('rsa', { modulusLength: 2048 })
const credentials = { project_id: 'dishes-test-project', client_email: 'fixture@dishes-test-project.iam.gserviceaccount.com', private_key: pair.privateKey.export({ type: 'pkcs8', format: 'pem' }) }
const job = { subscription: { platform: 'android', token: 'fixture-token-12345678901234567890' }, message: 'Alex did the dishes · 10 points', household_id: '00000000-0000-4000-8000-000000000001', notification_id: '00000000-0000-4000-8000-000000000002' }
const response = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

test('signs OAuth assertion, coalesces authorization and sends background notification with inbox destination', async () => {
  let oauthCalls = 0, deliveries = 0
  const send = createFcmSender(credentials, async (url, options) => {
    if (url === 'https://oauth2.googleapis.com/token') {
      oauthCalls++
      const assertion = options.body.get('assertion'), parts = assertion.split('.')
      assert.ok(verify('RSA-SHA256', Buffer.from(parts.slice(0, 2).join('.')), pair.publicKey, Buffer.from(parts[2], 'base64url')))
      const claims = JSON.parse(Buffer.from(parts[1], 'base64url'))
      assert.equal(claims.scope, 'https://www.googleapis.com/auth/firebase.messaging')
      assert.equal(claims.aud, url); assert.equal(claims.exp - claims.iat, 3600)
      return response({ access_token: 'fixture-oauth-token', expires_in: 3600 })
    }
    deliveries++
    assert.equal(url, 'https://fcm.googleapis.com/v1/projects/dishes-test-project/messages:send')
    assert.equal(options.headers.Authorization, 'Bearer fixture-oauth-token')
    assert.equal(options.redirect, 'error')
    const { message } = JSON.parse(options.body)
    assert.equal(message.token, job.subscription.token)
    assert.equal(message.notification.body, job.message)
    assert.equal(message.android.notification.channel_id, 'chores')
    assert.equal(message.android.notification.tag, job.notification_id)
    const destination = new URL(message.data.url)
    assert.equal(destination.origin, 'https://therealbiebs.github.io')
    assert.equal(destination.searchParams.get('household'), job.household_id)
    assert.equal(destination.searchParams.get('view'), 'notifications')
    return response({ name: 'projects/fixture/messages/123' })
  })
  const results = await Promise.all(Array.from({ length: 20 }, () => send(job)))
  assert.equal(oauthCalls, 1); assert.equal(deliveries, 20)
  assert.ok(results.every(r => r.success && !r.expired))
})

for (const [status, code, expired] of [[404, 'UNREGISTERED', true], [400, 'INVALID_ARGUMENT', false], [429, 'QUOTA_EXCEEDED', false], [503, 'UNAVAILABLE', false]]) {
  test(`classifies FCM ${code} without deleting retryable device subscriptions`, async () => {
    const send = createFcmSender(credentials, async url => url.includes('oauth2') ? response({ access_token: 'fixture', expires_in: 3600 }) : response({ error: { details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: code }], message: 'Sensitive service details must not be logged' } }, status))
    const result = await send(job)
    assert.equal(result.success, false); assert.equal(result.expired, expired)
    assert.ok(!result.message.includes('Sensitive'))
  })
}

test('unauthorized FCM response invalidates the cached access token for the next retry', async () => {
  let auth = 0, attempts = 0
  const send = createFcmSender(credentials, async url => {
    if (url.includes('oauth2')) { auth++; return response({ access_token: `fixture-${auth}`, expires_in: 3600 }) }
    return ++attempts === 1 ? response({}, 401) : response({ name: 'sent' })
  })
  assert.equal((await send(job)).success, false)
  assert.equal((await send(job)).success, true)
  assert.equal(auth, 2)
})

test('rejects malformed or foreign subscriptions before making a network request', async () => {
  const send = createFcmSender(credentials, () => { throw new Error('Unexpected request') })
  await assert.rejects(send({ ...job, subscription: { platform: 'web', token: job.subscription.token } }), /Invalid Android/)
  await assert.rejects(send({ ...job, subscription: { platform: 'android', token: 'https://evil.example' } }), /Invalid Android/)
})
