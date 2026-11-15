import { useEffect,useState } from 'react'
import { isNative } from './native'
import { isStandalone,registerPwa } from './pwa'
import './pwa.css'

export default function PwaSetup() {
  const [open,setOpen]=useState(false),[prompt,setPrompt]=useState(null),[installed,setInstalled]=useState(isStandalone),[error,setError]=useState('')
  useEffect(()=>{
    const offer=e=>{e.preventDefault();setPrompt(e)}
    const done=()=>{setInstalled(true);setPrompt(null)}
    window.addEventListener('beforeinstallprompt',offer);window.addEventListener('appinstalled',done)
    return()=>{window.removeEventListener('beforeinstallprompt',offer);window.removeEventListener('appinstalled',done)}
  },[])
  if(isNative||installed)return null
  async function install(){setError('');try{await prompt.prompt();const result=await prompt.userChoice;if(result.outcome==='accepted')setInstalled(true);setPrompt(null)}catch{setError('Use your browser’s Install app or Add to Home Screen menu.')}}
  return <div className="pwa-setup"><button type="button" className="text-button" aria-expanded={open} onClick={()=>setOpen(v=>!v)}>Install Chip In on your phone</button>{open&&<div className="pwa-instructions">
    <h3>Install Chip In</h3><p><strong>iPhone:</strong> Open this site in Safari, tap Share, then Add to Home Screen. Keep “Open as Web App” enabled if shown, and tap Add.</p>
    <p><strong>Android:</strong> Choose Install app or Add to Home screen in your browser menu.</p>
    {prompt&&<button type="button" className="button secondary" onClick={install}>Install app</button>}
    <p>Open Chip In from its new icon, sign in, then go to Notifications and enable phone notifications. iPhone notifications require iOS 16.4 or later.</p>
    <p>A sticker may open Safari instead of the installed app. Sign in there if asked, then tap “Log this chore”. Your household and points are shared between both.</p>
    {error&&<p role="alert">{error}</p>}
  </div>}</div>
}

export function PwaStatus() {
  const [offline,setOffline]=useState(!navigator.onLine),[waiting,setWaiting]=useState(null)
  useEffect(()=>{
    if(isNative)return
    let active=true,reg,installing;let reload=false
    const online=()=>setOffline(!navigator.onLine)
    const changed=()=>{if(installing?.state==='installed'&&reg.waiting&&active)setWaiting(reg.waiting)}
    const found=()=>{installing?.removeEventListener('statechange',changed);installing=reg.installing;installing?.addEventListener('statechange',changed)}
    const controller=()=>{if(reload)location.reload()}
    const refresh=()=>{if(document.visibilityState==='visible')reg?.update().catch(()=>{})}
    const update=e=>{reload=true;e.detail.postMessage({type:'SKIP_WAITING'})}
    window.addEventListener('online',online);window.addEventListener('offline',online);window.addEventListener('chip-in-update',update)
    navigator.serviceWorker?.addEventListener('controllerchange',controller);document.addEventListener('visibilitychange',refresh)
    registerPwa().then(r=>{if(!active||!r)return;reg=r;if(reg.waiting)setWaiting(reg.waiting);reg.addEventListener('updatefound',found);found()}).catch(()=>{})
    return()=>{active=false;window.removeEventListener('online',online);window.removeEventListener('offline',online);window.removeEventListener('chip-in-update',update);navigator.serviceWorker?.removeEventListener('controllerchange',controller);document.removeEventListener('visibilitychange',refresh);reg?.removeEventListener('updatefound',found);installing?.removeEventListener('statechange',changed)}
  },[])
  if(isNative||(!offline&&!waiting))return null
  return <aside className="pwa-status" role="status">{offline?<span>You’re offline. Reconnect before logging chores or saving changes.</span>:<><span>A Chip In update is ready.</span><button type="button" onClick={()=>window.dispatchEvent(new CustomEvent('chip-in-update',{detail:waiting}))}>Update Chip In</button></>}</aside>
}
