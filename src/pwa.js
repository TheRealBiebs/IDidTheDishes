export function isStandalone() {
  return Boolean(window.matchMedia?.('(display-mode: standalone)').matches || window.matchMedia?.('(display-mode: fullscreen)').matches || navigator.standalone)
}

let registration
export function registerPwa() {
  if (!import.meta.env.PROD || !('serviceWorker' in navigator) || !['http:','https:'].includes(location.protocol)) return Promise.resolve(null)
  if (!registration) registration=navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`,{scope:import.meta.env.BASE_URL,updateViaCache:'none'}).catch(error=>{registration=null;throw error})
  return registration
}

// Reloading or reopening the same web history entry must not award another chore.
export function webScanRequest(token,userId,historyApi=window.history) {
  const previous=historyApi.state?.chipInScan
  if(previous?.token===token&&previous?.userId===userId&&previous?.id) return previous.id
  const id=crypto.randomUUID()
  historyApi.replaceState({...historyApi.state,chipInScan:{token,userId,id}},'')
  return id
}
