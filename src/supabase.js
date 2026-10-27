import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL?.trim()
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()
let client = null
let configurationError = ''

if (url && key && !url.includes('YOUR_PROJECT') && !key.includes('YOUR_PUBLISHABLE_KEY')) {
  try {
    client = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    })
  } catch {
    configurationError = 'Check the Supabase project URL and publishable key, then restart the app.'
  }
}

export const supabase = client
export { configurationError }
