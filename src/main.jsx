import { StrictMode, Suspense, lazy } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { PwaStatus } from './PwaSetup'
import { isNative } from './native'
import './native.css'
import { initializeNative } from './native-lifecycle'
const welcome=!isNative&&new URLSearchParams(location.search).get('view')==='welcome'
const Welcome=lazy(()=>import('./marketing/Welcome'))
if (isNative) document.documentElement.classList.add('native-app')
if(!welcome)initializeNative().catch(error => console.error('Native initialization:', error.message))

createRoot(document.getElementById('root')).render(<StrictMode><Suspense fallback={<p role="status" style={{padding:30}}>Opening Chip In…</p>}>{welcome?<Welcome/>:<App/>}</Suspense><PwaStatus /></StrictMode>)
