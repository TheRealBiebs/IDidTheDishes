import { createClient } from '@supabase/supabase-js'
import { isNative, nativeStorage } from './native'
import publicConfig from './supabase-config.json'

const url = import.meta.env.VITE_SUPABASE_URL?.trim() || publicConfig.url
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() || publicConfig.publishableKey
let client = null
let configurationError = ''

if (url && key && !url.includes('YOUR_PROJECT') && !key.includes('YOUR_PUBLISHABLE_KEY')) {
  try {
    client = createClient(url, key, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: !isNative, ...(isNative ? { flowType: 'pkce', storage: nativeStorage } : {}) },
    })
  } catch {
    configurationError = 'Check the Supabase project URL and publishable key, then restart the app.'
  }
}

export const supabase = client
export { configurationError }
export const supabasePublicConfig = { url, key }
