const CACHE_PREFIX='chip-in-'+new URL(self.registration.scope).pathname+'-'
const CACHE_NAME=CACHE_PREFIX+'__BUILD_VERSION__'
const PRECACHE=__PRECACHE_ASSETS__
const root=new URL(self.registration.scope)
const assetUrls=new Set(PRECACHE.map(path=>new URL(path,root).href))
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(CACHE_NAME)
  await cache.addAll([...assetUrls].map(url=>new Request(url,{cache:'reload'})))
})()))
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  // Keep one previous release for tabs that still use its JavaScript chunks.
  const old=(await caches.keys()).filter(name=>name.startsWith(CACHE_PREFIX)&&name!==CACHE_NAME)
  await Promise.all(old.slice(0,-1).map(name=>caches.delete(name)))
  await self.clients.claim()
})()))
self.addEventListener('message',event=>{if(event.data?.type==='SKIP_WAITING')event.waitUntil(self.skipWaiting())})
self.addEventListener('fetch',event=>{
  const request=event.request,url=new URL(request.url)
  if(request.method!=='GET'||url.origin!==root.origin||!url.pathname.startsWith(root.pathname))return
  if(request.mode==='navigate'){
    event.respondWith(fetch(request).catch(async()=>await caches.match(new URL('offline.html',root).href)))
    return
  }
  // Cache only the public build assets. Auth, APIs, photos, and user data stay online.
  const buildAsset=url.pathname.startsWith(new URL('assets/',root).pathname)&&/\.(js|css)$/.test(url.pathname)
  if(url.search||(!assetUrls.has(url.href)&&!buildAsset))return
  event.respondWith((async()=>{
    const cached=await caches.match(request)
    if(cached)return cached
    return fetch(request)
  })())
})
self.addEventListener('push', event => {
  let data = { title: 'Chip In', body: 'Your household has a new update.', url: './' }
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
