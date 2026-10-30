import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase, configurationError } from './supabase'
import { api, rpc } from './api'
import { isNative, authRedirectUrl, setNativeBarStyle } from './native'
import { restoreGoogleDestination, signInWithGoogle } from './google-auth'
import { disablePush, enablePush, hasPush, inviteLink, scanSticker, siteRoot, tagLink, writeSticker } from './platform'
import { GemTube, HallBanners, WIZARD_HOUSES } from './WizardTheme'
import { ChooseTeam, TeamBadge, TeamCup, TeamForm, ThemeAtmosphere, ThemeSettings, THEMES, NEUTRAL_THEME, teamAppearance, teamFor, themeFor } from './HouseholdThemes'
import RewardDashboard from './rewards/RewardDashboard'
import { RewardSettings, RewardSummary } from './rewards/RewardSettings'
import DeleteHousehold from './DeleteHousehold'
import { REWARD_SCHEMES, rewardFor, rewardValue, rankedScores, completionReward } from './rewards/registry'
import './rewards/rewards.css'
import './styles.css'
import './wizard.css'
import './themes.css'
import './neutral.css'
import { isHouseholdAdmin, adminCount } from './household-access'
import { AdminMemberActions, AdminConfirmation, JoinRequestReview, MyJoinRequests } from './HouseholdAdmins'
import './admins.css'
import StarterPicker from './stickers/StarterPicker'
import TagWorkshop from './stickers/TagWorkshop'
import TagScanPage from './stickers/TagScanPage'
import { CompletionDetailView } from './stickers/CompletionDetails'
import { scanAction } from './stickers/routing'
import StickerInfo, { StickerReleaseRequests } from './stickers/StickerInfo'
import './stickers/stickers.css'

const paths = {
  home: 'm3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z',
  grid: 'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
  tag: 'M3 3h8l10 10-8 8L3 11ZM7 7h.01',
  users: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
  scan: 'M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4M8 12h8M12 8v8',
  check: 'm5 12 4 4L19 6',
  plus: 'M12 5v14M5 12h14',
  arrow: 'M5 12h14m-6-6 6 6-6 6',
  trophy: 'M8 3h8v7a4 4 0 0 1-8 0ZM8 5H4v3a4 4 0 0 0 4 4M16 5h4v3a4 4 0 0 1-4 4M12 14v5M8 21h8',
  exit: 'M9 21H4V3h5M13 8l5 4-5 4M8 12h10',
  clock: 'M12 8v4l3 2M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0',
}
export function Icon({ name, size = 20 }) { return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name] || paths.check} /></svg> }
const initials = name => name?.split(/\s+/).slice(0,2).map(s=>s[0]).join('').toUpperCase() || '?'
const when = value => new Date(value).toLocaleString(undefined, { month:'short', day:'numeric', hour:'numeric', minute:'2-digit' })
const uuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value || '')
function readRoute() { const q = new URLSearchParams(location.search); return { tag:q.get('tag'), invite:q.get('invite'), household:q.get('household'), view:q.get('view') } }
function scanRequest(token) {
  const key = `dishes-scan:${token}`
  try {
    const saved = JSON.parse(sessionStorage.getItem(key) || 'null')
    if (saved && Date.now()-saved.time<30000) return saved.id
    const id = crypto.randomUUID(); sessionStorage.setItem(key, JSON.stringify({ id, time:Date.now() })); return id
  } catch { return crypto.randomUUID() }
}

function Modal({ title, children, onClose, wide = false }) {
  const ref = useRef(null)
  useEffect(() => {
    const previous = document.activeElement
    const node = ref.current
    node?.querySelector('input,button,select,textarea')?.focus()
    const handler = e => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'Tab') {
        const controls = [...node.querySelectorAll('button,input,select,textarea,a[href]')].filter(el=>!el.disabled && el.offsetParent!==null)
        const first=controls[0], last=controls.at(-1)
        if (e.shiftKey && document.activeElement===first) { e.preventDefault();last?.focus() }
        else if (!e.shiftKey && document.activeElement===last) { e.preventDefault();first?.focus() }
      }
    }
    node?.addEventListener('keydown',handler)
    return () => { node?.removeEventListener('keydown',handler);previous?.focus() }
  }, [onClose])
  return <div className="modal-backdrop" onClick={e=>e.target===e.currentTarget && onClose()}><section className={`modal ${wide?'wide':''}`} role="dialog" aria-modal="true" aria-label={title} ref={ref}><div className="modal-heading"><h2>{title}</h2><button className="icon-button" onClick={onClose} aria-label="Close dialog">×</button></div>{children}</section></div>
}

function Auth({ onMessage, invite, theme, initialMode='login' }) {
  const [mode,setMode]=useState(initialMode), [busy,setBusy]=useState(false), [error,setError]=useState(''), [notice,setNotice]=useState('')
  async function googleSignIn() {
    setBusy(true); setError(''); setNotice('')
    try { await signInWithGoogle() }
    catch (e) { setError(e.message || 'Google sign-in could not start. Please try again.'); setBusy(false) }
  }
  async function submit(e) {
    e.preventDefault();setBusy(true);setError('');setNotice('')
    const values = Object.fromEntries(new FormData(e.currentTarget))
    try {
      if (mode==='signup') {
        const { data,error } = await supabase.auth.signUp({ email:values.email, password:values.password, options:{ data:{ display_name:values.name }, emailRedirectTo:authRedirectUrl() } })
        if (error) throw error
        if (!data.session) setNotice('Check your email to confirm your account, then return here and sign in.')
      } else if (mode==='reset') {
        const { error } = await supabase.auth.resetPasswordForEmail(values.email, { redirectTo:authRedirectUrl() })
        if (error) throw error
        setNotice('If this email has an account, a password reset link is on its way.')
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email:values.email, password:values.password })
        if (error) throw error
        onMessage('Welcome back.')
      }
    } catch (e) { setError(e.message || 'Unable to sign in. Please try again.') } finally { setBusy(false) }
  }
  return <div className={`auth-page theme-${theme.id} ${theme.id!=='wizard'?'theme-light':''}`}><ThemeAtmosphere theme={theme}/><div className="auth-story">{theme.id==='wizard'&&<HallBanners/>}<Brand /><div className="auth-copy"><span className="eyebrow light">{theme.eyebrow}</span><h1>{theme.title}<br /><em>{theme.subtitle}</em></h1><p>{theme.intro}</p>{theme.id==='neutral'?<NeutralWelcomeArt/>:<div className="auth-vault-art" aria-hidden="true"><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[1]:teamAppearance({name:'Team',color:theme.colors[0]})} points={64} capacity={100}/><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[0]:teamAppearance({name:'Team',color:theme.colors[1]})} points={82} capacity={100}/><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[2]:teamAppearance({name:'Team',color:theme.colors[2]})} points={48} capacity={100}/></div>}</div><p className="auth-bottom">{theme.id==='wizard'?'Mischief managed. Chores accomplished.':'Small chores. Shared wins.'}</p></div><main className="auth-form-wrap"><div className="auth-form"><div className="mobile-brand"><Brand /></div><span className="eyebrow">WELCOME TO YOUR HOUSEHOLD</span><h2>{mode==='signup'?'A fresh start for your household.':mode==='reset'?'Let’s get you back in.':theme.login}</h2><p className="muted">{invite?'Your household invitation will be waiting after you sign in.':mode==='signup'?'Create your account, then bring everyone together.':theme.id==='neutral'?'Sign in to keep your household’s chores and contributions in one place.':'A household of everyday magic. Your next great deed starts here.'}</p>{mode!=='reset'&&<><button type="button" className="google-button" disabled={busy} onClick={googleSignIn}><GoogleMark/><span>{busy?'One moment…':'Continue with Google'}</span></button><div className="auth-divider"><span>or continue with email</span></div></>}<form onSubmit={submit}>{mode==='signup'&&<label>Your name<input name="name" autoComplete="name" placeholder="What should we call you?" required maxLength={60}/></label>}<label>Email address<input name="email" type="email" autoComplete="email" placeholder="you@example.com" required/></label>{mode!=='reset'&&<label>Password<input name="password" type="password" autoComplete={mode==='signup'?'new-password':'current-password'} placeholder="Your password" required minLength={mode==='signup'?8:1}/></label>}{error&&<p className="form-error" role="alert">{error}</p>}{notice&&<p className="form-notice" role="status">{notice}</p>}<button className="button full" disabled={busy}>{busy?'One moment…':mode==='signup'?'Create account':mode==='reset'?'Send reset link':'Sign in'}<Icon name="arrow"/></button></form><div className="auth-links">{mode==='login'?<><button onClick={()=>{setMode('signup');setError('');setNotice('')}}>New here? Create an account</button><button onClick={()=>{setMode('reset');setError('');setNotice('')}}>Forgot password?</button></>:<button onClick={()=>{setMode('login');setError('');setNotice('')}}>Back to sign in</button>}</div><p className="privacy-note"><Icon name="home" size={15}/>Your household’s activity stays in your household.</p></div></main></div>
}
function NeutralWelcomeArt(){return <div className="neutral-welcome-art" aria-hidden="true"><span>A little done. A little shared.</span>{['Dishes put away','Plants watered','A hand with the laundry'].map((chore,i)=><div className="neutral-welcome-row" key={chore}><i><Icon name="check" size={15}/></i><span>{chore}</span><small>{['Together','Thank you','One less thing'][i]}</small></div>)}<p>Make the everyday a team effort.</p></div>}
function GoogleMark() { return <svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#4285F4" d="M43.6 24.5c0-1.4-.1-2.7-.4-4H24v7.6h11a9.5 9.5 0 0 1-4.1 6.3v5.2h6.7c3.9-3.6 6-8.8 6-15.1Z"/><path fill="#34A853" d="M24 44c5.5 0 10.1-1.8 13.5-4.9l-6.7-5.2c-1.8 1.2-4.1 1.9-6.8 1.9-5.3 0-9.8-3.6-11.4-8.4H5.7v5.4A20.4 20.4 0 0 0 24 44Z"/><path fill="#FBBC05" d="M12.6 27.4a12 12 0 0 1 0-7.8v-5.4H5.7a20 20 0 0 0 0 18.6l6.9-5.4Z"/><path fill="#EA4335" d="M24 11.2c3 0 5.6 1 7.7 3l5.8-5.8A19.4 19.4 0 0 0 24 3a20.4 20.4 0 0 0-18.3 11.2l6.9 5.4A12 12 0 0 1 24 11.2Z"/></svg> }
function Brand() { return <div className="brand"><span className="brand-symbol"><Icon name="check" size={22}/></span><span>I Did The Dishes<span className="brand-period">.</span></span></div> }

function HouseholdForm({ invite, name, onSubmit, busy }) {
  const [mode,setMode]=useState(invite?'join':'create')
  const [rewardScheme,setRewardScheme]=useState('points')
  return <><div className="segmented"><button className={mode==='create'?'selected':''} onClick={()=>setMode('create')}>Create a household</button><button className={mode==='join'?'selected':''} onClick={()=>setMode('join')}>Join a household</button></div><form onSubmit={e=>{e.preventDefault();const form=new FormData(e.currentTarget);onSubmit(mode,{...Object.fromEntries(form),starter_chores:form.getAll('starter_chores')})}}><label>Your name in this household<input name="display_name" defaultValue={name} required maxLength={60}/></label>{mode==='create'?<><label>Household name<input name="name" placeholder="The Maple Street house" required maxLength={80}/></label><label>Household theme<select aria-label="Household theme" name="theme" defaultValue="wizard">{Object.values(THEMES).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></label><label>Household reward system<select aria-label="Household reward system" name="reward_scheme" value={rewardScheme} onChange={e=>setRewardScheme(e.target.value)}>{Object.values(REWARD_SCHEMES).map(r=><option key={r.id} value={r.id}>{r.name}{r.status==='Preview'?' (preview)':''}</option>)}</select><small>{rewardFor(rewardScheme).rule}</small></label><label>Household time zone<select name="timezone" defaultValue={Intl.DateTimeFormat().resolvedOptions().timeZone}>{[...new Set([Intl.DateTimeFormat().resolvedOptions().timeZone,...(Intl.supportedValuesOf?.('timeZone')||['UTC'])])].map(zone=><option key={zone}>{zone}</option>)}</select><small>Daily chore limits reset at midnight in this time zone.</small></label><StarterPicker/></>:<label>Invitation link or code<small>An admin must approve your request before you can access the household.</small><input name="code" defaultValue={invite||''} placeholder="Paste the invitation from your household admin" required/></label>}<button className="button full" disabled={busy}>{busy?'One moment…':mode==='create'?'Create household':'Request to join'}<Icon name="arrow"/></button></form></>
}

function TagForm({ household, tag, members, busy, onSubmit, onCancel, submitLabel }) {
  const [everyone,setEveryone]=useState(!tag?.eligible_users?.length)
  const [eligible,setEligible]=useState(tag?.eligible_users||[])
  return <form onSubmit={e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.currentTarget));onSubmit({p_household:household.id,p_tag:tag?.id||null,p_chore:v.chore,p_location:v.location,p_points:Number(v.points),p_limit:Number(v.daily_limit),p_eligible:everyone?[]:eligible,p_active:v.active==='on'})}}>
    <p className="muted">Configure the chore and its shared daily limit. Its title appears in the public sticker preview; household details stay private.</p><label>What’s the chore?<input name="chore" defaultValue={tag?.chore||''} placeholder="Do the dishes" required maxLength={100}/></label><label>Where does the sticker live?<input name="location" defaultValue={tag?.location||''} placeholder="Kitchen · next to the sink" maxLength={80}/></label><div className="form-row">{household.reward_scheme==='stars'||household.reward_scheme==='adventure'?<><input name="points" type="hidden" value={tag?.points||10}/><p className="muted">{household.reward_scheme==='stars'?'Each completion earns one gold star.':'Chores are logged. Loot drops are still in preview.'}</p></>:<label>Points per completion<input name="points" type="number" min="1" max="1000" defaultValue={tag?.points||10} required/></label>}<label>Times per day, total<input name="daily_limit" type="number" min="1" max="100" defaultValue={tag?.daily_limit||1} required/></label></div><fieldset><legend>Who can do this chore?</legend><label className="check-label"><input type="checkbox" checked={everyone} onChange={e=>setEveryone(e.target.checked)}/>Everyone in the household</label>{!everyone&&members.map(m=><label className="check-label" key={m.user_id}><input type="checkbox" checked={eligible.includes(m.user_id)} onChange={e=>setEligible(e.target.checked?[...eligible,m.user_id]:eligible.filter(id=>id!==m.user_id))}/>{m.display_name}</label>)}{!everyone&&!eligible.length&&<small>Choose at least one member.</small>}</fieldset><label className="check-label"><input type="checkbox" name="active" defaultChecked={tag?.active??true}/>Sticker is active</label><div className="form-actions"><button className="button secondary" type="button" onClick={onCancel}>Cancel</button><button className="button" disabled={busy||(!everyone&&!eligible.length)}>{busy?'Saving…':submitLabel||(tag?'Save changes':'Create chore')}</button></div>
  </form>
}

export default function App() {
  const [session,setSession]=useState(null),[authReady,setAuthReady]=useState(false),[houses,setHouses]=useState([]),[houseId,setHouseId]=useState(''),[housesReady,setHousesReady]=useState(false)
  const [teams,setTeams]=useState([]),[tags,setTags]=useState([]),[members,setMembers]=useState([]),[dashboard,setDashboard]=useState(null),[notifications,setNotifications]=useState([]),[loading,setLoading]=useState(false)
  const [route,setRoute]=useState(readRoute),[view,setView]=useState(['notifications','workshop'].includes(readRoute().view)?readRoute().view:'dashboard'),[modal,setModal]=useState(null),[busy,setBusy]=useState(false),[toast,setToast]=useState(null),[pushEnabled,setPushEnabled]=useState(false),[scanState,setScanState]=useState(null)
  const [recovery,setRecovery]=useState(false)
  const [joinRequests,setJoinRequests]=useState([]),[myRequests,setMyRequests]=useState([])
  const [platformAdmin,setPlatformAdmin]=useState(null),[bindings,setBindings]=useState([]),[releaseRequests,setReleaseRequests]=useState([]),[tagAuthMode,setTagAuthMode]=useState(null)
  const scanConfigure=useRef(false),scanTarget=useRef(null)
  const accessUser=useRef(null);accessUser.current=session?.user.id
  const activeHouse=houses.find(h=>h.id===houseId), me=members.find(m=>m.user_id===session?.user.id), owner=isHouseholdAdmin(me)
  const theme=THEMES[activeHouse?.theme||localStorage.getItem('dishes-theme')]||NEUTRAL_THEME
  const reward=rewardFor(activeHouse?.reward_scheme)
  const requestVersion=useRef(0), scanned=useRef(''), scanner=useRef(null)
  const notify=useCallback((message,error=false)=>setToast({message,error}),[])
  const closeModal=useCallback(()=>{setModal(null);scanner.current?.abort();scanner.current=null},[])
  useEffect(()=>{
    if(!supabase){setAuthReady(true);return}
    supabase.auth.getSession().then(({data,error})=>{if(error)notify(error.message,true);if(data.session&&restoreGoogleDestination())setRoute(readRoute());setSession(data.session);setAuthReady(true)})
    const {data:{subscription}}=supabase.auth.onAuthStateChange((event,current)=>{if(current&&restoreGoogleDestination())setRoute(readRoute());setSession(current);setAuthReady(true);if(event==='PASSWORD_RECOVERY')setRecovery(true)})
    const routeChanged=()=>{setRoute(readRoute());scanned.current=''}
    window.addEventListener('popstate',routeChanged)
    const nativeError = event => notify(event.detail,true)
    window.addEventListener('native-error',nativeError)
    const nativeNotice = event => notify(event.detail)
    window.addEventListener('native-notification',nativeNotice)
    if(!isNative && 'serviceWorker' in navigator)navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`,{scope:import.meta.env.BASE_URL}).catch(()=>{})
    return()=>{subscription.unsubscribe();window.removeEventListener('popstate',routeChanged);window.removeEventListener('native-error',nativeError);window.removeEventListener('native-notification',nativeNotice);scanner.current?.abort()}
  },[notify])
  useEffect(()=>{if(!toast||toast.error)return;const t=setTimeout(()=>setToast(null),6000);return()=>clearTimeout(t)},[toast])
  useEffect(()=>{if(['notifications','workshop'].includes(route.view))setView(route.view)},[route.view])
  useEffect(()=>setTagAuthMode(null),[route.tag])
  useEffect(()=>{const id=session?.user.id;setPlatformAdmin(null);if(!id)return;rpc('is_platform_admin').then(value=>{if(accessUser.current===id)setPlatformAdmin(Boolean(value))}).catch(()=>{if(accessUser.current===id)setPlatformAdmin(false)})},[session?.user.id])

  useEffect(()=>{setNativeBarStyle(theme.id);if(activeHouse?.theme)localStorage.setItem('dishes-theme',activeHouse.theme);document.title=`${theme.dashboard} · I Did The Dishes`;document.querySelector('meta[name=theme-color]')?.setAttribute('content',theme.id==='wizard'?'#111419':theme.colors[0])},[theme.id,activeHouse?.theme])

  const loadHouses=useCallback(async preferred=>{
    const userId=accessUser.current;if(!userId)return []
    const rows=await api.households();if(accessUser.current!==userId)return [];setHouses(rows);setHousesReady(true)
    const saved=preferred||route.household||localStorage.getItem('dishes-household')
    setHouseId(previous=>rows.some(h=>h.id===saved)?saved:rows.some(h=>h.id===previous)?previous:rows[0]?.id||'')
    return rows
  },[route.household])
  useEffect(()=>{
    setHousesReady(false);setHouses([]);setHouseId('');setDashboard(null);setNotifications([]);scanned.current=''
    if(session) {loadHouses().catch(e=>{setHousesReady(true);notify(e.message,true)});hasPush(session.user.id,supabase).then(setPushEnabled).catch(()=>setPushEnabled(false))}
  },[session?.user.id,loadHouses,notify])

  const loadMyRequests=useCallback(async()=>{
    const userId=session?.user.id;if(!userId)return
    const rows=await rpc('my_join_requests')
    if(accessUser.current===userId)setMyRequests(rows||[])
  },[session?.user.id])
  useEffect(()=>{
    const userId=session?.user.id;setMyRequests([]);if(!userId)return
    let active=true
    const check=()=>{if(!active||accessUser.current!==userId)return;loadMyRequests().catch(()=>{});loadHouses().catch(()=>{})}
    loadMyRequests().catch(e=>{if(active)notify(e.message,true)})
    const channel=supabase.channel('join-requests:'+userId).on('postgres_changes',{event:'*',schema:'public',table:'household_join_requests',filter:'user_id=eq.'+userId},event=>{if(accessUser.current!==userId)return;check();if(event.new?.status==='approved')notify('Your household request has been approved.')}).subscribe()
    const visible=()=>{if(document.visibilityState==='visible')check()}
    const timer=setInterval(visible,30000);document.addEventListener('visibilitychange',visible)
    return()=>{active=false;clearInterval(timer);document.removeEventListener('visibilitychange',visible);supabase.removeChannel(channel)}
  },[session?.user.id,loadMyRequests,loadHouses,notify])
  const refresh=useCallback(async()=>{
    if(!session||!houseId)return
    const version=++requestVersion.current
    const [t,m,d,n,ts,jr,links,releases]=await Promise.all([api.tags(houseId),api.members(houseId),rpc('household_dashboard',{p_household:houseId}),api.notifications(),api.teams(houseId),api.joinRequests(houseId),rpc('household_stickers',{p_household:houseId}),api.releaseRequests(houseId)])
    if(version!==requestVersion.current)return
    setTags(t);setMembers(m);setDashboard(d);setNotifications(n);setTeams(ts);setJoinRequests(jr);setBindings(links);setReleaseRequests(releases);setLoading(false)
  },[houseId,session?.user.id])
  useEffect(()=>{
    setTags([]);setMembers([]);setTeams([]);setJoinRequests([]);setBindings([]);setReleaseRequests([]);setDashboard(null)
    if(!houseId||!session)return
    localStorage.setItem('dishes-household',houseId);setLoading(true)
    refresh().catch(e=>{setLoading(false);notify(e.message,true)})
    const channel=supabase.channel(`household:${houseId}:${session.user.id}`)
    let timer
    const update=()=>{clearTimeout(timer);timer=setTimeout(()=>refresh().catch(()=>{}),150)}
    for(const table of ['chore_completions','chore_tags','household_members','household_teams','household_join_requests'])channel.on('postgres_changes',{event:'*',schema:'public',table,filter:`household_id=eq.${houseId}`},update)
    channel.on('postgres_changes',{event:'*',schema:'public',table:'sticker_release_requests',filter:`owner_household_id=eq.${houseId}`},update)
    channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'households',filter:`id=eq.${houseId}`},()=>loadHouses(houseId).catch(()=>{}))
    channel.on('postgres_changes',{event:'INSERT',schema:'public',table:'notifications',filter:`user_id=eq.${session.user.id}`},event=>{notify(event.new.message);update()}).subscribe()
    const interval=setInterval(update,30000)
    const visible=()=>{if(document.visibilityState==='visible'){update();loadHouses(houseId).catch(()=>{})}}
    document.addEventListener('visibilitychange',visible)
    return()=>{requestVersion.current++;clearTimeout(timer);clearInterval(interval);document.removeEventListener('visibilitychange',visible);supabase.removeChannel(channel)}
  },[houseId,refresh,notify,session?.user.id,loadHouses])

  useEffect(()=>{
    if(!authReady||!route.tag)return
    const identity=(session?.user.id||'public')+':'+route.tag+':'+scanConfigure.current
    if(scanned.current===identity)return
    scanned.current=identity;setScanState({identity,loading:true})
    if(!uuid(route.tag)){setScanState({identity,info:{status:'invalid'}});return}
    let active=true
    rpc('inspect_sticker',{p_token:route.tag}).then(async info=>{
      if(!active)return
      setScanState({identity,info})
      if(scanAction(info,{signedIn:Boolean(session),installed:isNative,configuring:scanConfigure.current})==='complete'){
        setHouseId(info.household_id);setScanState({identity,info,loading:true})
        try{const completion=await rpc('complete_chore',{p_token:route.tag,p_request:scanRequest(route.tag)});if(active)setScanState({identity,info,completion})}
        catch(e){if(active)setScanState({identity,info,error:e.message})}
      }
    }).catch(e=>{if(active)setScanState({identity,info:{status:'invalid'},error:e.message})})
    return()=>{active=false}
  },[authReady,session?.user.id,route.tag])

  async function perform(action,message){setBusy(true);try{const result=await action();if(message)notify(message);return result}catch(e){notify(e.message||'Something went wrong. Please try again.',true);return null}finally{setBusy(false)}}
  async function householdSubmit(mode,v){await perform(async()=>{
    let id
    if(mode==='create')id=await rpc('create_household_setup',{p_name:v.name,p_display_name:v.display_name,p_timezone:v.timezone,p_theme:v.theme||'wizard',p_starters:v.starter_chores||[],p_reward_scheme:v.reward_scheme||'points'})
    else{let code=v.code.trim();try{code=new URL(code).searchParams.get('invite')||code}catch{}if(!uuid(code))throw new Error('Paste a valid household invitation link or code.');id=await rpc('join_household',{p_code:code,p_display_name:v.display_name})}
    const available=await loadHouses(id)
    if(mode==='join'){await loadMyRequests();notify(available.some(h=>h.id===id)?'You are already a member of this household.':'Request sent. A household admin needs to approve your membership.')}
    setModal(null);setView(mode==='create'?'chores':'dashboard')
    const url=new URL(location.href);url.searchParams.delete('invite')
    const pending=sessionStorage.getItem('dishes-tag-setup')
    if(mode==='create'&&uuid(pending)){url.searchParams.set('tag',pending);sessionStorage.removeItem('dishes-tag-setup');scanned.current=''}
    history.replaceState(null,'',url);setRoute(readRoute())
  },mode==='create'?'Your household is ready. Scan preloaded stickers to assign your chores.':undefined)}
  async function saveTag(parameters){await perform(async()=>{const id=await rpc('save_tag',parameters);await refresh();const tag=(await api.tags(houseId)).find(t=>t.id===id);setModal({type:'sticker',tag})},'Chore settings saved.')}
  function finishScan(){setScanState(null);scanConfigure.current=false;scanTarget.current=null;scanned.current='';const url=new URL(location.href);url.searchParams.delete('tag');history.replaceState(null,'',url);setRoute(readRoute());refresh().catch(e=>notify(e.message,true))}
  async function openScan(configure=false,target=null){
    scanConfigure.current=configure;scanTarget.current=target?{householdId:houseId,choreId:target.id}:null;
    scanner.current?.abort();scanner.current=new AbortController();setModal({type:'scan',configure})
    try{await scanSticker(async token=>{
      if(!token){notify('Couldn’t read that sticker. Please try again.',true);return}
      scanner.current?.abort()
      closeModal();const url=new URL(location.href);url.searchParams.set('tag',token);history.pushState(null,'',url);scanned.current='';setRoute(readRoute())
    },scanner.current.signal)}catch(e){if(e.name!=='AbortError')notify(e.message,true)}
  }

  if(!authReady)return <div className="splash"><Brand/><p>Making room for a little teamwork…</p></div>
  if(!supabase)return <div className="splash"><Brand/><p role="alert">{configurationError||'Supabase configuration is missing.'}</p></div>
  async function logCurrentScan(){const userId=session?.user.id;setBusy(true);try{const completion=await rpc('complete_chore',{p_token:route.tag,p_request:scanRequest(route.tag)});if(accessUser.current!==userId)return;setScanState(previous=>({...previous,error:'',completion}));setHouseId(completion.household_id)}catch(e){setScanState(previous=>({...previous,error:e.message}))}finally{setBusy(false)}}
  function tagHouseholds(){if(route.tag)sessionStorage.setItem('dishes-tag-setup',route.tag);finishScan();setView('household')}
  const currentScan=scanState?.identity===((session?.user.id||'public')+':'+route.tag+':'+scanConfigure.current)?scanState:null
  if(route.tag&&(!tagAuthMode||session))return <TagScanPage key={(session?.user.id||'public')+route.tag} token={route.tag} info={currentScan?.info} loading={!currentScan||currentScan.loading} error={currentScan?.error} completion={currentScan?.completion} session={session} houses={houses} configure={scanConfigure.current} initialTarget={scanTarget.current} busy={busy} onDone={finishScan} onSignIn={setTagAuthMode} onHouseholds={tagHouseholds} onLog={logCurrentScan} onSaved={updated=>setScanState(previous=>previous?.completion?.id===updated.id?{...previous,completion:updated}:previous)} renderTagForm={props=><TagForm {...props}/>} onClaimed={async id=>{await loadHouses(id);finishScan();setView('chores');notify('Sticker claimed and configured. No writing is needed.')}} onSaveConfiguration={async params=>{await rpc('save_tag',params);finishScan();notify('Chore configuration saved.')}}/>
  if(!session)return <>{route.tag&&<div className="tag-auth-banner"><span>Your sticker will be here after sign-in.</span><button className="text-button" onClick={()=>setTagAuthMode(null)}>Back to sticker</button></div>}<Auth initialMode={tagAuthMode||'login'} onMessage={notify} invite={route.invite} theme={theme}/>{toast&&<Toast toast={toast} onClose={()=>setToast(null)}/>}</>
  const accessPending=<MyJoinRequests requests={myRequests} busy={busy} onRefresh={()=>perform(async()=>{await loadMyRequests();await loadHouses()})}/>
  const unread=notifications.filter(n=>!n.read_at).length
  const nav=[['dashboard','grid',theme.id==='wizard'?'The Great Hall':'Overview'],['chores','tag','Chores & stickers'],['household','users','Your household'],['notifications','bell','Notifications'],...(platformAdmin?[['workshop','tag','Tag workshop']]:[])]
  const currentName=me?.display_name||session.user.user_metadata?.display_name||session.user.user_metadata?.full_name||session.user.user_metadata?.name||'there'
  const dailyCount=tag=>Number(dashboard?.tag_counts?.[tag.id]||0)
  const todaysTags=tags.filter(t=>t.active)
  return <div className={`app-shell theme-${theme.id} ${theme.id!=='wizard'?'theme-light':''}`}><ThemeAtmosphere theme={theme}/>
    <aside className="sidebar"><Brand/><div className="house-switch"><span className="eyebrow">YOUR SPACE</span><label className="sr-only" htmlFor="house-switch">Current household</label><select id="house-switch" value={houseId} onChange={e=>{setHouseId(e.target.value);setView('dashboard')}}>{houses.map(h=><option key={h.id} value={h.id}>{h.name}</option>)}{!houses.length&&<option value="">Choose your household</option>}</select></div><nav aria-label="Main navigation">{nav.map(([key,icon,label])=><button key={key} className={view===key?'active':''} onClick={()=>setView(key)}><Icon name={icon}/><span>{label}</span>{key==='notifications'&&unread>0&&<b className="count">{unread}</b>}</button>)}</nav><div className="sidebar-note"><span>✦</span><h3>Greatness begins<br />with the little things.</h3><p>A good deed. A little credit. A little closer to your next team win.</p></div><button className="account" onClick={()=>perform(async()=>{await disablePush();setPushEnabled(false);const {error}=await supabase.auth.signOut();if(error)throw error})}><span className="avatar">{initials(currentName)}</span><span><strong>{currentName}</strong><small>Sign out</small></span><Icon name="exit" size={18}/></button></aside>
    <div className="workspace"><header className="topbar"><span className="breadcrumb"><Icon name="home" size={17}/>{activeHouse?.name||'Your household'}<span>/</span>{nav.find(n=>n[0]===view)?.[2]}</span><div className="topbar-actions"><button className="icon-button" onClick={()=>setView('notifications')} aria-label={`Notifications, ${unread} unread`}><Icon name="bell"/>{unread>0&&<i/>}</button><span className="avatar small">{initials(currentName)}</span><button className="mobile-signout icon-button" onClick={()=>perform(async()=>{await disablePush();setPushEnabled(false);const {error}=await supabase.auth.signOut();if(error)throw error})} aria-label="Sign out"><Icon name="exit" size={18}/></button></div></header>{houses.length>0&&<div className="mobile-house-switch"><Icon name="home" size={17}/><select aria-label="Switch household" value={houseId} onChange={e=>{setHouseId(e.target.value);setView('dashboard')}}>{houses.map(h=><option key={h.id} value={h.id}>{h.name}</option>)}</select><button className="icon-button" onClick={()=>setModal({type:'household'})} aria-label="Create or join a household"><Icon name="plus" size={18}/></button></div>}<main className="content">{accessPending}
    {view==='workshop'?(platformAdmin?<TagWorkshop/>:<Empty icon="tag" title={platformAdmin===null?'Checking platform access…':'Platform admin access required'} text="Batch writing is separate from household administration."/>):!housesReady?<div className="empty-state"><Icon name="home" size={40}/><h2>Finding your household…</h2></div>:!houses.length?<section className="welcome"><span className="eyebrow">YOUR NEXT CHAPTER, TOGETHER</span><h1>A home for your<br/>household’s little wins.</h1><p>Create a household, set up your first chore stickers, and invite your people. Or join a household that’s already here.</p><div className="welcome-form"><HouseholdForm invite={route.invite} name={currentName==='there'?'':currentName} onSubmit={householdSubmit} busy={busy}/></div></section>:<>
    {route.invite&&<div className="banner"><span>You have an invitation to request household membership.</span><button className="text-button" onClick={()=>setModal({type:'household'})}>Join this household →</button></div>}
    {view==='dashboard'&&<>
      <div className="page-heading"><div><span className="eyebrow">{reward.id==='points'?theme.cup.toUpperCase():reward.name.toUpperCase()} · {reward.id==='stars'?'YOUR CHORE HISTORY':'THIS WEEK'}</span><h1>{theme.dashboard}<span className="wave" aria-hidden="true">✧</span></h1><p>Welcome back, {currentName.split(' ')[0]}. Every little contribution counts.</p></div><button className="button" onClick={()=>openScan()}><Icon name="scan"/>Scan a sticker</button></div>
      {owner&&bindings.length===0&&!loading&&<div className="setup-banner"><div className="setup-symbol"><Icon name="tag" size={28}/></div><div><strong>Assign your first preloaded sticker.</strong><p>Choose a chore, then scan an unassigned sticker. Friends never need to write it.</p></div><button className="button" onClick={()=>openScan(true)}>Assign first sticker<Icon name="plus" size={16}/></button></div>}
      <RewardSummary household={activeHouse} owner={owner} onConfigure={()=>setModal({type:'rewards'})}/><RewardDashboard key={houseId+reward.id} household={activeHouse} theme={theme} teams={teams} scores={dashboard?.scores||[]} members={members} currentUser={session.user.id} loading={loading} revision={dashboard} onChoose={()=>setModal({type:'sorting'})}/><div className="stats-grid"><Stat label="Deeds accomplished today" value={dashboard?.today_count??'—'} note="Every little deed matters" icon="check" color="lime"/><Stat label={reward.id==='points'?(theme.id==='wizard'?'Points in the Great Hall':'Household points'):reward.id==='stars'?'Household gold stars':'Household chores'} value={reward.id==='points'?(dashboard?.week_points??'—'):(dashboard?.week_count??dashboard?.scores?.reduce((n,m)=>n+Number(m.chores),0)??'—')} note="Earned by your household this week" icon="trophy" color="peach"/><Stat label={reward.id==='points'?'Your personal points':reward.id==='stars'?'Your gold stars':'Your weekly chores'} value={dashboard?rewardValue(reward,dashboard.scores?.find(m=>m.user_id===session.user.id)):'—'} note="Your contribution this week" icon="tag" color="lavender"/></div>
      <div className="dashboard-grid"><section className="panel leaderboard"><div className="panel-heading"><div><h2>{theme.id==='wizard'?'The honour roll':'The team players'}</h2><p>The people making things happen.</p></div><span className="pill">This week</span></div>{loading&&!dashboard?<p className="muted">Loading household scores…</p>:<div className="ranks">{rankedScores(reward,dashboard?.scores).map((m,i)=><div className="rank-row" key={m.user_id}><span className={`rank-position ${i===0?'first':''}`}>{i===0?<Icon name="trophy" size={17}/>:String(i+1).padStart(2,'0')}</span><span className={`avatar color-${i%4}`}>{initials(m.display_name)}</span><div className="rank-name"><strong>{m.display_name}{m.user_id===session.user.id&&<small>you</small>}</strong><span>{m.chores} chore{m.chores===1?'':'s'} completed · {teamFor(members.find(person=>person.user_id===m.user_id),teams)?.name||'No team yet'}</span></div><strong className="rank-points">{rewardValue(reward,m)}<small>{reward.unit}</small></strong></div>)}</div>}<div className="panel-bottom">A new chapter every Monday. May the best house win.<span>✦</span></div></section>
      <section className="scan-card"><div className="scan-art" aria-hidden="true"><div className="scan-ring"><Icon name="scan" size={50}/></div><span className="mini-spark">✧</span></div><span className="eyebrow light">{theme.id==='wizard'?'A SPELL OF EVERYDAY GOOD':'EVERY LITTLE THING COUNTS'}</span><h2>{theme.id==='wizard'?<>A good deed.<br/>A little enchantment.</>:<>One chore down.<br/>One happier home.</>}</h2><p>Tap the NFC sticker by your chore.<br/>We’ll record your contribution and let your household know.</p><button className="button pale" onClick={()=>openScan()}>{theme.id==='wizard'?'Cast your next good deed':'Scan your next chore'}<Icon name="arrow"/></button></section></div>
      <div className="lower-grid"><section className="panel"><div className="panel-heading"><div><h2>{theme.id==='wizard'?'The chronicles':'The latest little wins'}</h2><p>Good deeds, inscribed in time.</p></div><button className="text-button" onClick={()=>setView('notifications')}>View updates →</button></div><Activity onInspect={completion=>setModal({type:'completionDetails',completion})} reward={reward} items={dashboard?.activity?.slice(0,5)||[]} timezone={activeHouse?.timezone}/></section><section className="panel"><div className="panel-heading"><div><h2>Quests around the house</h2><p>Today’s chore stickers.</p></div><button className="text-button" onClick={()=>setView('chores')}>View all →</button></div>{todaysTags.slice(0,4).map(t=><div className="today-row" key={t.id}><span className="chore-symbol"><Icon name="tag" size={18}/></span><div><strong>{t.chore}</strong><small>{t.location||'Around the house'}</small></div><span className={`pill ${dailyCount(t)>=t.daily_limit?'done':''}`}>{dailyCount(t)}/{t.daily_limit} done</span></div>)}{!todaysTags.length&&<p className="empty-inline">Your chore stickers will appear here.</p>}</section></div>
    </>}
    {view==='chores'&&<><div className="page-heading"><div><span className="eyebrow">LITTLE JOBS, BIG DIFFERENCE</span><h1>Chores & stickers</h1><p>One sticker, one chore. A little less to remember.</p></div>{owner&&<div className="heading-buttons"><button className="button secondary" onClick={()=>setModal({type:'starters'})}>Starter chores</button><button className="button secondary" onClick={()=>openScan(true)}><Icon name="scan"/>Tap to configure</button><button className="button" onClick={()=>setModal({type:'editTag'})}><Icon name="plus"/>Add chore</button></div>}</div><div className="info-strip"><Icon name="clock"/><span>Limits are shared by the whole household and reset at midnight ({activeHouse?.timezone}).</span></div><div className="chores-grid">{tags.map(t=><article className={`chore-card ${!t.active?'paused':''}`} key={t.id}><div className="chore-card-top"><span className="chore-symbol"><Icon name="tag" size={23}/></span><span className="points-chip">{completionReward(reward,t.points)}</span></div><h2>{t.chore}</h2><p>{t.location||'Around the house'}</p><p className="physical-tag-status">{bindings.some(b=>b.chore_tag_id===t.id)?'Preloaded sticker assigned':'Awaiting a preloaded sticker'}</p><div className="chore-progress"><span style={{width:`${Math.min(dailyCount(t)/t.daily_limit*100,100)}%`}}/></div><div className="chore-card-meta"><span>{dailyCount(t)} of {t.daily_limit} today</span><span>{t.active?'Active':'Paused'}</span></div><p className="eligible-text">{t.eligible_users.length?members.filter(m=>t.eligible_users.includes(m.user_id)).map(m=>m.display_name).join(', '):'Everyone can pitch in'}</p>{owner?<button className="button secondary full" onClick={()=>setModal({type:'sticker',tag:t})}>Chore & sticker<Icon name="arrow" size={16}/></button>:<p className="muted small-text">Tap its NFC sticker to log this chore.</p>}</article>)}</div>{!tags.length&&!loading&&<Empty icon="tag" title="Every little job starts here." text={owner?'Add your first sticker and choose its chore, eligibility, and daily limit.':'Your household admin can set up chore stickers here.'}/>}</>}
    {view==='household'&&<><div className="page-heading"><div><span className="eyebrow">YOUR PEOPLE, YOUR PLACE</span><h1>{activeHouse?.name}</h1><p>A little teamwork makes it home.</p></div><button className="button secondary" onClick={()=>setModal({type:'household'})}><Icon name="plus"/>Create or join another</button></div>{owner&&<section className="panel household-style-panel"><div><span className="style-panel-icon">{theme.emoji}</span><div><h2>{theme.name}</h2><p>{teams.filter(t=>t.active).length} active teams · Custom names and gem colours</p></div></div><button className="button secondary" onClick={()=>setModal({type:'themeSettings'})}>Theme & teams</button></section>}<RewardSummary household={activeHouse} owner={owner} onConfigure={()=>setModal({type:'rewards'})}/><section className="panel affiliation-panel"><div><TeamBadge team={teamFor(me,teams)} size={45}/><div><h2>{teamFor(me,teams)?.name||'Choose your team'}</h2><p>Your team in this household. Your current-week contributions follow your choice.</p></div></div><button className="button secondary" onClick={()=>setModal({type:'sorting'})}>Choose your team <span>→</span></button></section><section className="panel"><div className="panel-heading"><h2>Everyone at home</h2><span className="pill">{members.length} members · {adminCount(members)} admin{adminCount(members)===1?'':'s'}</span></div><p className="admin-guidance">Admins configure chores, approve new members, and manage household settings. The person who creates a household starts as its first admin.</p>{members.map((m,i)=><div className="member-admin-entry" key={m.user_id}><div className="member-row"><span className={`avatar color-${i%4}`}>{initials(m.display_name)}</span><div><strong>{m.display_name}{m.user_id===session.user.id?' (you)':''}</strong><small>{teamFor(m,teams)?.name||'No team yet'} · {isHouseholdAdmin(m)?'Household admin':'Household member'}</small></div>{owner?<label className="member-team-select"><span className="sr-only">Team for {m.display_name}</span><select aria-label={`Team for ${m.display_name}`} value={m.team_id||''} disabled={busy} onChange={e=>perform(async()=>{await rpc('choose_team',{p_household:houseId,p_team:e.target.value||null,p_user:m.user_id});await refresh()},'Member’s team updated.')}><option value="">No team</option>{teams.filter(t=>t.active).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></label>:<span className="pill">{isHouseholdAdmin(m)?'Admin':'Member'}</span>}</div>{owner&&<AdminMemberActions member={m} members={members} currentUser={session.user.id} busy={busy} onAction={setModal}/>}</div>)}</section>{owner&&<JoinRequestReview requests={joinRequests} busy={busy} onDecide={(id,approve)=>perform(async()=>{await rpc('decide_join_request',{p_request:id,p_approve:approve});await refresh()},approve?'Member approved.':'Join request declined.')}/>}
    {owner&&<StickerReleaseRequests requests={releaseRequests} busy={busy} onReview={(request,release)=>release?setModal({type:'releaseSticker',token:request.token,request}):perform(async()=>{await rpc('review_sticker_release',{p_request:request.id,p_release:false});await refresh()},'Release request declined.')}/>}
    {owner&&<section className="panel invite-panel"><div><h2>Bring your people home.</h2><p>Share a private invitation link. People request access, then an admin approves them.</p></div><button className="button" disabled={busy} onClick={()=>perform(async()=>{const code=await rpc('invite_code',{p_household:houseId,p_rotate:false});setModal({type:'invite',code})})}>Get invitation link<Icon name="arrow"/></button></section>}<section className="panel notification-panel"><div><h2>A little heads-up.</h2><p>Get a phone notification when someone else completes a chore — even when this app is closed.</p><small>{isNative?'Allow notifications when Android asks. You can change them later in your phone’s app settings. Delivery depends on your connection and Android settings.':'On iPhone: Share → Add to Home Screen, open the app there, then enable notifications. Delivery depends on your device and notification permissions.'}</small></div><button className="button secondary" disabled={busy} onClick={()=>perform(async()=>{if(pushEnabled){await disablePush();setPushEnabled(false)}else{await enablePush();setPushEnabled(true)}},pushEnabled?'Notifications disabled on this device.':'Phone notifications are on for this device.')}>{pushEnabled?'Turn off on this device':'Enable phone notifications'}<Icon name="bell" size={17}/></button></section>{owner&&<section className="panel"><h2>Delete household</h2><p>Permanently remove this household and its shared history for all members.</p><button className="button secondary" disabled={busy} onClick={()=>setModal({type:'deleteHousehold',household:activeHouse})}>Delete household</button></section>}</>}
    {view==='notifications'&&<><div className="page-heading"><div><span className="eyebrow">{theme.id==='wizard'?'OWL POST HAS ARRIVED':'GOOD THINGS ARE HAPPENING'}</span><h1>{theme.id==='wizard'?'The owl post':'Your updates'}</h1><p>A thank-you in the making.</p></div><button className="button secondary" disabled={busy||!unread} onClick={()=>perform(async()=>{await rpc('read_notifications');await refresh()},'You’re all caught up.')}>Mark all as read</button></div><section className="panel notification-list">{notifications.map(n=><article className={`notification-row ${!n.read_at?'unread':''}`} key={n.id}><span className="avatar lime"><Icon name="check"/></span><div><strong>{n.message}</strong><p>{houses.find(h=>h.id===n.household_id)?.name||'Your household'} · {when(n.created_at)}</p></div>{!n.read_at&&<i aria-label="Unread"/>}</article>)}{!notifications.length&&<Empty icon="bell" title="A quiet moment." text="When someone else does a chore, you’ll hear about their little win here."/>}</section></>}
    </>}
    <footer className="app-footer"><span>{theme.id==='wizard'?'Mischief managed. Chores accomplished.':'Small chores. Shared wins.'}</span><span>A little magic for the people you call home. <span>✦</span></span></footer>
    </main></div><nav className="mobile-nav" style={{'--nav-count':nav.length}} aria-label="Mobile navigation">{nav.map(([key,icon,label])=><button key={key} onClick={()=>setView(key)} className={view===key?'active':''} aria-label={label}><Icon name={icon}/><span>{key==='chores'?'Chores':key==='household'?'Household':key==='notifications'?'Updates':key==='workshop'?'Workshop':'Overview'}</span>{key==='notifications'&&unread>0&&<i/>}</button>)}</nav>
    {modal?.type==='deleteHousehold'&&owner&&modal.household.id===houseId&&<Modal title="Delete household?" onClose={busy?()=>{}:closeModal}><DeleteHousehold key={houseId} household={modal.household} busy={busy} onCancel={closeModal} onDelete={confirmation=>perform(async()=>{await rpc('delete_household',{p_household:modal.household.id,p_confirmation:confirmation});closeModal();setTags([]);setMembers([]);setTeams([]);setDashboard(null);setBindings([]);setReleaseRequests([]);setNotifications([]);localStorage.removeItem('dishes-household');await loadHouses();setView('dashboard')},'Household deleted. Its stickers are available to claim again.')}/></Modal>}
    {modal?.type==='completionDetails'&&<Modal title={modal.completion.chore} onClose={closeModal}><CompletionDetailView completion={modal.completion}/></Modal>}
    {modal?.type==='sorting'&&<Modal title="Choose your team" onClose={closeModal}><ChooseTeam current={me?.team_id} teams={teams} busy={busy} onChoose={team=>perform(async()=>{await rpc('choose_team',{p_household:houseId,p_team:team,p_user:null});await refresh();setModal(null)},'Your team is chosen. Every point counts.')}/></Modal>}
    {['adminRole','transferAdmin'].includes(modal?.type)&&owner&&<Modal title={modal.type==='transferAdmin'?'Transfer admin role':'Change household admin'} onClose={closeModal}><AdminConfirmation action={modal} busy={busy} onCancel={closeModal} onConfirm={()=>perform(async()=>{if(modal.type==='transferAdmin')await rpc('transfer_household_admin',{p_household:houseId,p_user:modal.member.user_id});else await rpc('set_household_admin',{p_household:houseId,p_user:modal.member.user_id,p_admin:modal.makeAdmin});closeModal();await refresh()},'Household admin access updated.')}/></Modal>}
    {modal?.type==='rewards'&&owner&&<Modal title="Household reward system" onClose={closeModal} wide><RewardSettings key={houseId+reward.id} household={activeHouse} busy={busy} onSave={value=>perform(async()=>{await rpc('set_reward_scheme',{p_household:houseId,p_scheme:value});await loadHouses(houseId)},'Reward system updated. Your chore history is preserved.')}/></Modal>}
    {modal?.type==='themeSettings'&&owner&&<Modal title="Household theme & teams" onClose={closeModal} wide><ThemeSettings key={houseId+activeHouse.theme} household={activeHouse} teams={teams} members={members} busy={busy} onSaveTheme={value=>perform(async()=>{await rpc('set_household_theme',{p_household:houseId,p_theme:value});await loadHouses(houseId)},'Household theme updated. Teams and points are preserved.')} onEditTeam={team=>setModal({type:'editTeam',team})} onAddStarters={()=>perform(async()=>{await rpc('add_theme_teams',{p_household:houseId});await refresh()},'Starter teams added. Existing teams are unchanged.')}/></Modal>}
    {modal?.type==='editTeam'&&owner&&<Modal title={modal.team?'Edit team':'A new household team'} onClose={closeModal}><TeamForm household={activeHouse} team={modal.team} busy={busy} onCancel={()=>setModal({type:'themeSettings'})} onSave={parameters=>perform(async()=>{await rpc('save_team',parameters);await refresh();setModal({type:'themeSettings'})},'Team saved.')}/></Modal>}
    {modal?.type==='household'&&<Modal title="Make yourself at home" onClose={closeModal}><HouseholdForm invite={route.invite} name={currentName} busy={busy} onSubmit={householdSubmit}/></Modal>}
    {modal?.type==='editTag'&&owner&&<Modal title={modal.tag?'Edit chore sticker':'A new little job'} onClose={closeModal}><TagForm household={houses.find(h=>h.id===modal.tag?.household_id)||activeHouse} tag={modal.tag} members={members} busy={busy} onSubmit={saveTag} onCancel={closeModal}/></Modal>}
    {modal?.type==='sticker'&&owner&&<Modal title="Your chore and sticker" onClose={closeModal}><StickerInfo tag={modal.tag} binding={bindings.find(b=>b.chore_tag_id===modal.tag.id)} reward={reward} onEdit={()=>setModal({type:'editTag',tag:modal.tag})} onAssign={()=>openScan(true,modal.tag)} onRelease={()=>setModal({type:'releaseSticker',token:bindings.find(b=>b.chore_tag_id===modal.tag.id).token})} onMessage={notify}/></Modal>}
    {modal?.type==='releaseSticker'&&owner&&<Modal title="Release this physical sticker?" onClose={closeModal}><p>The sticker will become unassigned and another household can claim it. Your chore configuration and completed-chore history stay in this household. The sticker’s fixed URL does not change.</p><button className="button full" disabled={busy} onClick={()=>perform(async()=>{if(modal.request)await rpc('review_sticker_release',{p_request:modal.request.id,p_release:true});else await rpc('release_sticker',{p_token:modal.token});closeModal();await refresh()},'Sticker released. Your chore history is preserved.')}>Release sticker</button></Modal>}
    {modal?.type==='starters'&&owner&&<Modal title="Choose starter chores" onClose={closeModal}><form onSubmit={e=>{e.preventDefault();const keys=new FormData(e.currentTarget).getAll('starter_chores');perform(async()=>{await rpc('add_starter_chores',{p_household:houseId,p_keys:keys});closeModal();await refresh()},'Starter chores added. Scan preloaded stickers to assign them.')}}><StarterPicker disabled={busy}/><button className="button full" disabled={busy}>Add selected chores</button></form></Modal>}
    {modal?.type==='invite'&&owner&&<Modal title="Everyone’s invited" onClose={closeModal}><p>Anyone with this link can request to join <strong>{activeHouse?.name}</strong>. Only an admin can approve membership. Share it with the people who live with you.</p><textarea readOnly rows={3} value={inviteLink(modal.code)} onFocus={e=>e.target.select()}/><button className="button full" onClick={()=>navigator.clipboard.writeText(inviteLink(modal.code)).then(()=>notify('Invitation copied.')).catch(()=>notify('Select and copy the invitation above.',true))}>Copy invitation link</button><button className="text-button" disabled={busy} onClick={()=>perform(async()=>{const code=await rpc('invite_code',{p_household:houseId,p_rotate:true});setModal({type:'invite',code})},'New invitation created. The old link no longer works.')}>Replace invitation link</button></Modal>}
    {modal?.type==='scan'&&<Modal title={modal.configure?'Tap a sticker to configure it':'Ready for your little win?'} onClose={closeModal}><div className="scan-modal-art"><Icon name="scan" size={60}/></div><p>Hold your phone near a programmed NFC sticker. You can also tap a sticker while this app is closed; your phone will offer to open its link.</p><p className="muted">Use a sticker that was preloaded in the platform Tag workshop. An admin can claim an unassigned sticker and configure its chore after scanning.</p>{owner&&<button className="button full" onClick={()=>{scanner.current?.abort();setModal({type:'editTag'})}}>Configure a custom chore<Icon name="plus"/></button>}</Modal>}
    {scanState&&<Modal title={scanState.loading?'Logging your chore…':scanState.error?'Not quite yet.':'A little win. Well done.'} onClose={finishScan}><div className={`completion-symbol ${scanState.error?'warning':''}`}><Icon name={scanState.error?'clock':'check'} size={40}/></div>{scanState.loading?<p>Checking your sticker and household limits…</p>:scanState.error?<p role="alert">{scanState.error}</p>:<><h3 className="completion-name">{scanState.completion.chore}</h3><p className="completion-points">{completionReward(reward,scanState.completion.points)}</p><p className="muted">Logged for you. Your household has been notified.</p></>}<button className="button full" onClick={finishScan}>Back to your household</button></Modal>}
    {recovery&&<Modal title="Choose a new password" onClose={()=>setRecovery(false)}><form onSubmit={e=>{e.preventDefault();const password=new FormData(e.currentTarget).get('password');perform(async()=>{const {error}=await supabase.auth.updateUser({password});if(error)throw error;setRecovery(false)},'Your password has been updated.')}}><label>New password<input name="password" type="password" minLength={8} autoComplete="new-password" required/></label><button className="button full" disabled={busy}>Update password</button></form></Modal>}
    {toast&&<Toast toast={toast} onClose={()=>setToast(null)}/>}
  </div>
}

function Toast({toast,onClose}){return <div className={`toast ${toast.error?'error':''}`} role={toast.error?'alert':'status'}><Icon name={toast.error?'bell':'check'} size={20}/><span>{toast.message}</span><button onClick={onClose} aria-label="Dismiss message">×</button></div>}
function Stat({label,value,note,icon,color}){return <section className={`stat-card ${color}`}><div className="stat-top"><span>{label}</span><Icon name={icon}/></div><strong className="stat-value">{value}</strong><p>{note}</p></section>}
function Empty({icon,title,text}){return <div className="empty-state"><span className="empty-icon"><Icon name={icon} size={32}/></span><h2>{title}</h2><p>{text}</p></div>}
function Activity({items,reward=rewardFor(),onInspect}){return <div className="activity-list">{items.map(a=><div className="activity-row" key={a.id}><span className="activity-check"><Icon name="check" size={16}/></span><div><p><strong>{a.display_name}</strong> completed <strong>{a.chore}</strong></p><small>{when(a.completed_at)}</small>{onInspect&&<button className="text-button" onClick={()=>onInspect(a)}>View details<span className="sr-only"> for {a.chore}</span></button>}</div><span className="activity-points">{reward.id==='points'?`+${a.points}`:reward.id==='stars'?'★ +1':'✓'}</span></div>)}{!items.length&&<p className="empty-inline">A fresh start. Your household’s first little win will show up here.</p>}</div>}
