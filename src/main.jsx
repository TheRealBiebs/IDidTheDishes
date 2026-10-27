import { StrictMode, useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { configurationError, supabase } from './supabase'
import './styles.css'

function App() {
  const [greeting, setGreeting] = useState('Hello, world.')
  const [status, setStatus] = useState(supabase ? 'loading' : configurationError ? 'error' : 'setup')
  const [detail, setDetail] = useState(configurationError)

  async function loadGreeting(signal) {
    if (!supabase) return
    setStatus('loading')
    setDetail('')
    try {
      const { data, error } = await supabase
        .from('greetings')
        .select('message')
        .eq('id', 1)
        .abortSignal(signal ? AbortSignal.any([signal, AbortSignal.timeout(10000)]) : AbortSignal.timeout(10000))
        .single()
      if (signal?.aborted) return
      if (error) throw error
      setGreeting(data.message)
      setStatus('connected')
    } catch {
      if (signal?.aborted) return
      setStatus('error')
      setDetail('Could not read the greeting. Check your connection, Supabase settings, and database setup, then try again.')
    }
  }

  useEffect(() => {
    const controller = new AbortController()
    if (supabase) {
      loadGreeting(controller.signal)
    }
    return () => controller.abort()
  }, [])

  const labels = {
    setup: 'Backend setup needed',
    loading: 'Connecting to Supabase…',
    connected: 'Connected to Supabase',
    error: 'Connection needs attention',
  }

  return (
    <div className="page">
      <header><a className="brand" href="./" aria-label="Hello home"><span className="brand-icon" aria-hidden="true">h.</span>hello</a><span className="header-note">A small beginning.</span></header>
      <main>
        <section className="card" aria-labelledby="greeting">
          <div className="hello-icon" aria-hidden="true">✳</div>
          <p className="eyebrow">YOUR NEXT IDEA STARTS HERE</p>
          <h1 id="greeting">{greeting}</h1>
          <p className="intro">BOOGERS</p>
          <div className="connection" role="status" aria-live="polite">
            <span className={`dot ${status}`} aria-hidden="true" />
            <span>{labels[status]}</span>
          </div>
          {status === 'setup' && <p className="help">Add your Supabase URL and publishable key to <code>.env.local</code>, then run <code>supabase/schema.sql</code> in the Supabase SQL Editor.</p>}
          {detail && <p className="help" role="alert">{detail}</p>}
          <button type="button" onClick={() => loadGreeting()} disabled={!supabase || status === 'loading'}>
            {status === 'loading' ? 'Connecting…' : 'Refresh greeting'}<span aria-hidden="true">↗</span>
          </button>
          <p className="footnote">{status === 'connected' ? 'This greeting comes from your database.' : 'Your React frontend is up and running.'}</p>
        </section>
      </main>
      <footer><span>Made to grow.</span><div><span>React</span><span>Supabase</span><span>GitHub Pages</span></div></footer>
    </div>
  )
}

createRoot(document.getElementById('root')).render(<StrictMode><App /></StrictMode>)
