import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { isNative } from './native'
import './native.css'
import { initializeNative } from './native-lifecycle'
if (isNative) document.documentElement.classList.add('native-app')
initializeNative().catch(error => console.error('Native initialization:', error.message))

createRoot(document.getElementById('root')).render(<StrictMode><App /></StrictMode>)
