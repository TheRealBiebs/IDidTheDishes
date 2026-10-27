self.addEventListener('push', event => {
  let data = { title: 'IDidTheDishes', body: 'Your household has a new update.', url: './' }
  try { Object.assign(data, event.data?.json()) } catch { /* Show a safe fallback. */ }
  event.waitUntil(self.registration.showNotification(data.title, {
    body: data.body,
    icon: new URL('icon-192.png', self.registration.scope).href,
    badge: new URL('icon-192.png', self.registration.scope).href,
    tag: data.id || 'household-update',
    data: { url: new URL(data.url || './', self.registration.scope).href },
  }))
})
self.addEventListener('notificationclick', event => {
  event.notification.close()
  event.waitUntil((async () => {
    const url = new URL(event.notification.data?.url || self.registration.scope)
    if (url.origin !== self.location.origin || !url.href.startsWith(self.registration.scope)) return
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    const existing = windows.find(client => client.url.startsWith(self.registration.scope))
    if (existing) { await existing.navigate(url.href); await existing.focus() }
    else await self.clients.openWindow(url.href)
  })())
})
self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()))
