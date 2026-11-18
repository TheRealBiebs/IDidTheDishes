import {randomChoresAvailable} from './rewards/wheel-settings'
import {manualRequest,clearManualRequest} from './stickers/manual-request'
import RewardCelebration from './stickers/RewardCelebration'
import {CALENDAR_STICKERS} from './rewards/stickers'
import {assignmentValue,assignmentFields,choreAssignmentLabel} from './stickers/assignment'
import HouseholdTutorial from './tutorial/HouseholdTutorial'
import {TrophyCaseGrid} from './rewards/TrophyCase'
import {FeedbackForm} from './Feedback'
import DeleteTeam from './DeleteTeam'
import DeleteChore from './DeleteChore'
import {teamsEnabled} from './household-experience'
import TraitRewardSettings from './stickers/TraitRewardSettings'
import { TRAIT_CHOICES } from './stickers/trait-rewards'
import CommunityLeaderboard from './CommunityLeaderboard'
import PwaSetup from './PwaSetup'
import { webScanRequest } from './pwa'
import AssignedChores, { AssignedChoreList } from './AssignedChores'
import { frequencyLabel, unassignedAvailable, chorePeriodView } from './stickers/schedule'
import ChoreHistory from './ChoreHistory'
import CooldownSettings from './stickers/CooldownSettings'
import { automaticCooldown, cooldownMinutes, cooldownDuration } from './stickers/cooldown'
import Brand from './Brand'
import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase, configurationError } from './supabase'
import { api, rpc, localDate, weekStart } from './api'
import { isNative, authRedirectUrl, setNativeBarStyle } from './native'
import { restoreGoogleDestination, signInWithGoogle } from './google-auth'
import { disablePush, enablePush, hasPush, inviteLink, scanSticker, siteRoot, tagLink, writeSticker } from './platform'
import { GemTube, HallBanners, WIZARD_HOUSES } from './WizardTheme'
import { ChooseTeam, TeamBadge, TeamForm, ThemeAtmosphere, ThemeSettings, THEMES, NEUTRAL_THEME, teamAppearance, teamFor, themeFor } from './HouseholdThemes'
import RewardDashboard from './rewards/RewardDashboard'
import Casino from './rewards/casino/Casino'
import HallOfFame from './rewards/HallOfFame'
import WeeklyCelebration from './rewards/WeeklyCelebration'
import UnexpectedChore from './rewards/UnexpectedChore'
import DeleteHousehold from './DeleteHousehold'
import { rewardFor, rewardValue, completionReward } from './rewards/registry'
import './rewards/rewards.css'
import './styles.css'
import './wizard.css'
import './themes.css'
import './neutral.css'
import { isHouseholdAdmin, adminCount } from './household-access'
import { AdminMemberActions, AdminConfirmation } from './HouseholdAdmins'
import './admins.css'
import StarterPicker from './stickers/StarterPicker'
import TagWorkshop from './stickers/TagWorkshop'
import TagScanPage from './stickers/TagScanPage'
import CompletionDetails, { CompletionDetailView } from './stickers/CompletionDetails'
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
function readRoute() { const q = new URLSearchParams(location.search); return { tag:q.get('tag'), invite:q.get('invite'), household:q.get('household'), view:q.get('view'),completion:q.get('completion') } }
function scanRequest(token,userId) {
  if(!isNative)return webScanRequest(token,userId)
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
        onMessage('Signed in.')
      }
    } catch (e) { setError(e.message || 'Unable to sign in. Please try again.') } finally { setBusy(false) }
  }
  return <div className={`auth-page theme-${theme.id} ${theme.id!=='wizard'?'theme-light':''}`}><ThemeAtmosphere theme={theme}/><div className="auth-story">{theme.id==='wizard'&&<HallBanners/>}<Brand /><div className="auth-copy">{theme.id==='neutral'?<NeutralWelcomeArt/>:<div className="auth-vault-art" aria-hidden="true"><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[1]:teamAppearance({name:'Team',color:theme.colors[0]})} points={64} capacity={100}/><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[0]:teamAppearance({name:'Team',color:theme.colors[1]})} points={82} capacity={100}/><GemTube house={theme.id==='wizard'?WIZARD_HOUSES[2]:teamAppearance({name:'Team',color:theme.colors[2]})} points={48} capacity={100}/></div>}</div></div><main className="auth-form-wrap"><div className="auth-form"><div className="mobile-brand"><Brand /></div><h2>{mode==='signup'?'Create account':mode==='reset'?'Reset password':'Sign in'}</h2>{mode!=='reset'&&<><button type="button" className="google-button" disabled={busy} onClick={googleSignIn}><GoogleMark/><span>{busy?'One moment…':'Continue with Google'}</span></button><div className="auth-divider"><span>or continue with email</span></div></>}<form onSubmit={submit}>{mode==='signup'&&<label>Your name<input name="name" autoComplete="name" placeholder="What should we call you?" required maxLength={60}/></label>}<label>Email address<input name="email" type="email" autoComplete="email" placeholder="you@example.com" required/></label>{mode!=='reset'&&<label>Password<input name="password" type="password" autoComplete={mode==='signup'?'new-password':'current-password'} placeholder="Your password" required minLength={mode==='signup'?8:1}/></label>}{error&&<p className="form-error" role="alert">{error}</p>}{notice&&<p className="form-notice" role="status">{notice}</p>}<button className="button full" disabled={busy}>{busy?'One moment…':mode==='signup'?'Create account':mode==='reset'?'Send reset link':'Sign in'}<Icon name="arrow"/></button></form><div className="auth-links">{mode==='login'?<><button onClick={()=>{setMode('signup');setError('');setNotice('')}}>New here? Create an account</button><button onClick={()=>{setMode('reset');setError('');setNotice('')}}>Forgot password?</button></>:<button onClick={()=>{setMode('login');setError('');setNotice('')}}>Back to sign in</button>}</div><PwaSetup/><p className="privacy-note"><Icon name="home" size={15}/>Your household’s activity stays in your household.</p></div></main></div>
}
function NeutralWelcomeArt(){return <div className="neutral-welcome-art" aria-hidden="true">{['Dishes put away','Plants watered','A hand with the laundry'].map((chore,i)=><div className="neutral-welcome-row" key={chore}><i><Icon name="check" size={15}/></i><span>{chore}</span></div>)}</div>}
function GoogleMark() { return <svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#4285F4" d="M43.6 24.5c0-1.4-.1-2.7-.4-4H24v7.6h11a9.5 9.5 0 0 1-4.1 6.3v5.2h6.7c3.9-3.6 6-8.8 6-15.1Z"/><path fill="#34A853" d="M24 44c5.5 0 10.1-1.8 13.5-4.9l-6.7-5.2c-1.8 1.2-4.1 1.9-6.8 1.9-5.3 0-9.8-3.6-11.4-8.4H5.7v5.4A20.4 20.4 0 0 0 24 44Z"/><path fill="#FBBC05" d="M12.6 27.4a12 12 0 0 1 0-7.8v-5.4H5.7a20 20 0 0 0 0 18.6l6.9-5.4Z"/><path fill="#EA4335" d="M24 11.2c3 0 5.6 1 7.7 3l5.8-5.8A19.4 19.4 0 0 0 24 3a20.4 20.4 0 0 0-18.3 11.2l6.9 5.4A12 12 0 0 1 24 11.2Z"/></svg> }

function HouseholdForm({ invite, name, onSubmit, busy }) {
  const [mode,setMode]=useState(invite?'join':'create')
  const [chosenTheme,setChosenTheme]=useState('wizard')
  return <><div className="segmented"><button className={mode==='create'?'selected':''} onClick={()=>setMode('create')}>Create a household</button><button className={mode==='join'?'selected':''} onClick={()=>setMode('join')}>Join a household</button></div><form onSubmit={e=>{e.preventDefault();const form=new FormData(e.currentTarget);onSubmit(mode,{...Object.fromEntries(form),starter_chores:form.getAll('starter_chores')})}}><label>Your name in this household<input name="display_name" defaultValue={name} required maxLength={60}/></label>{mode==='create'?<><label>Household name<input name="name" placeholder="The Maple Street house" required maxLength={80}/></label><label>Household theme<select aria-label="Household theme" name="theme" value={chosenTheme} onChange={e=>setChosenTheme(e.target.value)}>{Object.values(THEMES).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></label><p className="muted">{THEMES[chosenTheme].description}</p><label className="check-label"><input name="teams_enabled" type="checkbox"/>Enable teams</label><small>Leave off for individual points.</small><label>Household time zone<select name="timezone" defaultValue={Intl.DateTimeFormat().resolvedOptions().timeZone}>{[...new Set([Intl.DateTimeFormat().resolvedOptions().timeZone,...(Intl.supportedValuesOf?.('timeZone')||['UTC'])])].map(zone=><option key={zone}>{zone}</option>)}</select><small>Daily chore limits reset at midnight in this time zone.</small></label><StarterPicker/></>:<label>Invitation link or code<small>A valid invitation adds you to the household immediately.</small><input name="code" defaultValue={invite||''} placeholder="Paste the invitation from your household admin" required/></label>}<button className="button full" disabled={busy}>{busy?'One moment…':mode==='create'?'Create household':'Join household'}<Icon name="arrow"/></button></form></>
}

function TagForm({ household, tag, members, teams=[], busy, onSubmit, onCancel, submitLabel }) {
  const [assignment,setAssignment]=useState(()=>assignmentValue(tag,teamsEnabled(household)))
  const [frequency,setFrequency]=useState(tag?.frequency||'daily')
  const [dailyLimit,setDailyLimit]=useState(tag?.daily_limit||1)
  const [cooldownMode,setCooldownMode]=useState(tag?.cooldown_minutes===0?'off':tag?.cooldown_minutes>0?'custom':'auto')
  const [customCooldown,setCustomCooldown]=useState(tag?.cooldown_minutes||automaticCooldown(tag?.daily_limit>1?tag.daily_limit:3))
  return <form onSubmit={e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.currentTarget));onSubmit({p_household:household.id,p_tag:tag?.id||null,p_chore:v.chore,p_location:v.location,p_points:Number(v.points),p_limit:Number(v.daily_limit),p_sticker:v.calendar_sticker||tag?.calendar_sticker||'star',p_frequency:frequency,...assignmentFields(assignment,tag,teamsEnabled(household)),p_cooldown_minutes:cooldownMode==='off'?0:cooldownMode==='custom'?Number(customCooldown):null,p_active:true,p_adjustments:Object.fromEntries(TRAIT_CHOICES.map(([id])=>[id,Number(v['adjustment_'+id])]))})}}>
    <p className="muted">Configure the schedule, team assignment, and completion limit. Its title appears in the public sticker preview; household details stay private.</p><label>What’s the chore?<input name="chore" defaultValue={tag?.chore||''} placeholder="Do the dishes" required maxLength={100}/></label><label>Where does the sticker live?<input name="location" defaultValue={tag?.location||''} placeholder="Kitchen · next to the sink" maxLength={80}/></label><label>Repeat schedule<select aria-label="Repeat schedule" value={frequency} onChange={e=>setFrequency(e.target.value)}><option value="daily">Daily</option><option value="weekly">Weekly</option><option value="monthly">Monthly</option></select><small>Weeks reset Monday; months reset on the first, in the household time zone.</small></label><div className="form-row"><label>Points per completion<input name="points" type="number" min="1" max="1000" defaultValue={tag?.points||10} required/></label>{household.reward_scheme==='stars'&&<p className="muted">Each completion still earns one calendar sticker. These adjustments affect chore point totals.</p>}{household.reward_scheme==='adventure'&&<p className="muted">Chore points are recorded. Loot drops are still in preview.</p>}<label>Times per {frequencyLabel({frequency})}, total<input name="daily_limit" type="number" min="1" max="100" value={dailyLimit} onChange={e=>setDailyLimit(e.target.value)} required/></label></div><details className="chore-additional-settings"><summary>Additional Settings</summary><CooldownSettings dailyLimit={dailyLimit} mode={cooldownMode} onModeChange={setCooldownMode} minutes={customCooldown} onMinutesChange={setCustomCooldown}/><label>Assigned to<select aria-label="Assigned to" value={assignment} onChange={e=>setAssignment(e.target.value)}><option value="anyone">Anyone in the household</option><optgroup label="People">{members.map(m=><option key={m.user_id} value={'person:'+m.user_id}>{m.display_name}</option>)}</optgroup>{teamsEnabled(household)&&<optgroup label="Teams">{teams.filter(t=>t.active||t.id===tag?.assigned_team_id).map(t=><option key={t.id} value={'team:'+t.id} disabled={!t.active}>{t.name}{!t.active?' (inactive)':''}</option>)}</optgroup>}{assignmentValue(tag,teamsEnabled(household))==='legacy'&&<option value="legacy">{choreAssignmentLabel(tag,members,teams,teamsEnabled(household))} (existing)</option>}</select><small>Only the assigned person or team can log this chore. Choose anyone to let all household members do it.</small></label><TraitRewardSettings rules={tag?.trait_adjustments}/></details><div className="form-actions"><button className="button secondary" type="button" onClick={onCancel}>Cancel</button><button className="button" disabled={busy}>{busy?'Saving…':submitLabel||(tag?'Save changes':'Create chore')}</button></div>
  </form>
}

export default function App() {
  const [tutorialOpen,setTutorialOpen]=useState(false),[tutorialReplay,setTutorialReplay]=useState(0)
  const [scheduleRows,setScheduleRows]=useState([])
  const [session,setSession]=useState(null),[authReady,setAuthReady]=useState(false),[houses,setHouses]=useState([]),[houseId,setHouseId]=useState(''),[housesReady,setHousesReady]=useState(false)
  const [weeklyScores,setWeeklyScores]=useState([])
  const [teams,setTeams]=useState([]),[tags,setTags]=useState([]),[members,setMembers]=useState([]),[dashboard,setDashboard]=useState(null),[notifications,setNotifications]=useState([]),[loading,setLoading]=useState(false)
  const [route,setRoute]=useState(readRoute),[view,setView]=useState(['notifications','workshop'].includes(readRoute().view)?readRoute().view:'dashboard'),[modal,setModal]=useState(null),[busy,setBusy]=useState(false),[toast,setToast]=useState(null),[pushEnabled,setPushEnabled]=useState(false),[scanState,setScanState]=useState(null)
  const [recovery,setRecovery]=useState(false)
  const [manualDetailsPending,setManualDetailsPending]=useState(false)
  const manualInFlight=useRef(false),manualRequests=useRef(new Map())
  const [weeklyFocus,setWeeklyFocus]=useState(null)
  const [casinoVisit,setCasinoVisit]=useState(0)
  const [platformAdmin,setPlatformAdmin]=useState(null),[bindings,setBindings]=useState([]),[releaseRequests,setReleaseRequests]=useState([]),[tagAuthMode,setTagAuthMode]=useState(null)
  const [pendingSticker,setPendingSticker]=useState(null)
  const scanConfigure=useRef(false),scanTarget=useRef(null)
  const accessUser=useRef(null);accessUser.current=session?.user.id
  const activeHouse=houses.find(h=>h.id===houseId), me=members.find(m=>m.user_id===session?.user.id), owner=isHouseholdAdmin(me)
  const storedTheme=activeHouse?.theme||localStorage.getItem('dishes-theme')
  const theme=storedTheme?themeFor(storedTheme):NEUTRAL_THEME
  const reward=rewardFor(activeHouse?.reward_scheme)
  const requestVersion=useRef(0), scanned=useRef(''), scanner=useRef(null)
  const notify=useCallback((message,error=false)=>setToast({message,error}),[])
  const closeModal=useCallback(()=>{if(new URLSearchParams(location.search).has('completion')){const url=new URL(location.href);url.searchParams.delete('completion');history.replaceState(null,'',url);setRoute(readRoute())}setModal(null);scanner.current?.abort();scanner.current=null;scanConfigure.current=false;scanTarget.current=null},[])
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
    return()=>{subscription.unsubscribe();window.removeEventListener('popstate',routeChanged);window.removeEventListener('native-error',nativeError);window.removeEventListener('native-notification',nativeNotice);scanner.current?.abort()}
  },[notify])
  useEffect(()=>{if(!toast||toast.error)return;const t=setTimeout(()=>setToast(null),6000);return()=>clearTimeout(t)},[toast])
  useEffect(()=>{if(['notifications','workshop'].includes(route.view))setView(route.view)},[route.view])
  useEffect(()=>setTagAuthMode(null),[route.tag])
  useEffect(()=>{
    if(!session?.user.id||!uuid(route.completion))return
    let active=true
    rpc('chore_social',{p_completion:route.completion}).then(data=>{if(active){setHouseId(data.completion.household_id);setView('notifications');setModal({type:'completionDetails',completion:data.completion})}}).catch(e=>{if(active)notify(e.message,true)})
    return()=>{active=false}
  },[session?.user.id,route.completion,notify])
  useEffect(()=>{const id=session?.user.id;setPlatformAdmin(null);if(!id)return;rpc('is_platform_admin').then(value=>{if(accessUser.current===id)setPlatformAdmin(Boolean(value))}).catch(()=>{if(accessUser.current===id)setPlatformAdmin(false)})},[session?.user.id])

  useEffect(()=>{setNativeBarStyle(theme.id);if(activeHouse?.theme)localStorage.setItem('dishes-theme',activeHouse.theme);document.title='Chip In';document.querySelector('meta[name=theme-color]')?.setAttribute('content',theme.id==='wizard'?'#111419':theme.colors[0])},[theme.id,activeHouse?.theme])

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

  const inviteAttempt=useRef('')
  useEffect(()=>{
    const user=session?.user,code=route.invite
    if(!user||!housesReady||!uuid(code)||recovery)return
    const key=user.id+':'+code
    if(inviteAttempt.current===key)return
    inviteAttempt.current=key
    const name=user.user_metadata?.display_name||user.user_metadata?.full_name||user.user_metadata?.name||'Household member'
    householdSubmit('join',{code,display_name:name.slice(0,60)})
  },[session?.user.id,housesReady,route.invite,recovery])
  const refresh=useCallback(async()=>{
    if(!session||!houseId)return
    const version=++requestVersion.current
    const [t,m,d,n,ts,links,releases,schedule,weekly]=await Promise.all([api.tags(houseId),api.members(houseId),rpc('household_dashboard',{p_household:houseId}),api.notifications(),api.teams(houseId),rpc('household_stickers',{p_household:houseId}),api.releaseRequests(houseId),rpc('chore_schedule',{p_household:houseId}),rpc('household_weekly_scores',{p_household:houseId})])
    if(version!==requestVersion.current)return
    setWeeklyScores(weekly);setScheduleRows(schedule);setTags(t);setMembers(m);setDashboard(d);setNotifications(n);setTeams(ts);setBindings(links);setReleaseRequests(releases);setLoading(false)
  },[houseId,session?.user.id])
  useEffect(()=>{
    setWeeklyScores([]);setScheduleRows([]);setTags([]);setMembers([]);setTeams([]);setBindings([]);setReleaseRequests([]);setDashboard(null)
    if(!houseId||!session)return
    localStorage.setItem('dishes-household',houseId);setLoading(true)
    refresh().catch(e=>{setLoading(false);notify(e.message,true)})
    const channel=supabase.channel(`household:${houseId}:${session.user.id}`)
    let timer
    const update=()=>{clearTimeout(timer);timer=setTimeout(()=>refresh().catch(()=>{}),150)}
    for(const table of ['chore_completions','chore_tags','household_members','household_teams'])channel.on('postgres_changes',{event:'*',schema:'public',table,filter:`household_id=eq.${houseId}`},update)
    channel.on('postgres_changes',{event:'*',schema:'public',table:'sticker_release_requests',filter:`owner_household_id=eq.${houseId}`},update)
    channel.on('postgres_changes',{event:'UPDATE',schema:'public',table:'households',filter:`id=eq.${houseId}`},()=>loadHouses(houseId).catch(()=>{}))
    channel.on('postgres_changes',{event:'INSERT',schema:'public',table:'notifications',filter:`user_id=eq.${session.user.id}`},event=>{notify(event.new.message);update()}).subscribe()
    const removed=()=>{closeModal();notify('Completion and its points removed.');update()}
    window.addEventListener('chore-completion-removed',removed)
    const interval=setInterval(update,30000)
    const visible=()=>{if(document.visibilityState==='visible'){update();loadHouses(houseId).catch(()=>{})}}
    document.addEventListener('visibilitychange',visible)
    return()=>{window.removeEventListener('chore-completion-removed',removed);requestVersion.current++;clearTimeout(timer);clearInterval(interval);document.removeEventListener('visibilitychange',visible);supabase.removeChannel(channel)}
  },[houseId,refresh,notify,session?.user.id,loadHouses,closeModal])

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
      if(scanAction(info,{signedIn:Boolean(session),configuring:scanConfigure.current})==='complete'){
        setHouseId(info.household_id);setScanState({identity,info,loading:true})
        try{const completion=await rpc('complete_chore',{p_token:route.tag,p_request:scanRequest(route.tag,session.user.id)});if(active)setScanState({identity,info,completion})}
        catch(e){if(active)setScanState({identity,info,error:e.message})}
      }
    }).catch(e=>{if(active)setScanState({identity,info:{status:'invalid'},error:e.message})})
    return()=>{active=false}
  },[authReady,session?.user.id,route.tag])

  async function perform(action,message){setBusy(true);try{const result=await action();if(message)notify(message);return result}catch(e){notify(e.message||'Something went wrong. Please try again.',true);return null}finally{setBusy(false)}}
  async function householdSubmit(mode,v){await perform(async()=>{
    let id
    if(mode==='create')id=await rpc('create_household_experience',{p_name:v.name,p_display_name:v.display_name,p_timezone:v.timezone,p_theme:v.theme||'wizard',p_starters:v.starter_chores||[],p_teams_enabled:v.teams_enabled==='on'})
    else{let code=v.code.trim();try{code=new URL(code).searchParams.get('invite')||code}catch{}if(!uuid(code))throw new Error('Paste a valid household invitation link or code.');id=await rpc('join_household',{p_code:code,p_display_name:v.display_name})}
    await loadHouses(id)
    if(mode==='join')notify('You joined the household.')
    setModal(null);setView(mode==='create'?'chores':'dashboard')
    const url=new URL(location.href);url.searchParams.delete('invite')
    const pending=sessionStorage.getItem('dishes-tag-setup')
    if(mode==='create'&&uuid(pending)){url.searchParams.set('tag',pending);sessionStorage.removeItem('dishes-tag-setup');scanned.current=''}
    history.replaceState(null,'',url);setRoute(readRoute())
  },mode==='create'?'Your household is ready. Scan preloaded stickers to assign your chores.':undefined)}
  async function saveTag(parameters){await perform(async()=>{await rpc('save_chore_rewards',parameters);await refresh();closeModal()},'Chore settings saved.')}
  function finishScan(){setScanState(null);scanConfigure.current=false;scanTarget.current=null;scanned.current='';const url=new URL(location.href);url.searchParams.delete('tag');history.replaceState(null,'',url);setRoute(readRoute());refresh().catch(e=>notify(e.message,true))}
  async function openScan(configure=false,target=null,knownToken=null){
    scanConfigure.current=configure;scanTarget.current=target?{householdId:houseId,choreId:target.id}:null;
    scanner.current?.abort();scanner.current=new AbortController();setModal({type:'scan',configure})
    const handleToken=async token=>{
      if(!token){notify('Couldn’t read that sticker. Please try again.',true);return}
      scanner.current?.abort()
      closeModal();scanConfigure.current=configure;scanTarget.current=target?{householdId:houseId,choreId:target.id}:null;const url=new URL(location.href);url.searchParams.set('tag',token);history.pushState(null,'',url);scanned.current='';setRoute(readRoute())
    }
    try{if(knownToken){setPendingSticker(null);await handleToken(knownToken)}else await scanSticker(handleToken,scanner.current.signal)}catch(e){if(e.name!=='AbortError')notify(e.message,true)}
  }

  if(!authReady)return <div className="splash"><Brand/><p>Making room for a little teamwork…</p></div>
  if(!supabase)return <div className="splash"><Brand/><p role="alert">{configurationError||'Supabase configuration is missing.'}</p></div>
  async function doChore(tag){
    const userId=session?.user.id;if(!userId||manualInFlight.current||busy)return
    manualInFlight.current=true;setBusy(true)
    const key=userId+':'+tag.id,request=manualRequests.current.get(key)||manualRequest(sessionStorage,userId,tag.id)
    manualRequests.current.set(key,request)
    try{
      const completion=await rpc('complete_chore_by_id',{p_chore:tag.id,p_request:request})
      if(accessUser.current!==userId)return
      manualRequests.current.delete(key);clearManualRequest(sessionStorage,userId,tag.id)
      setManualDetailsPending(false);setModal({type:'manualCompletion',completion})
      await refresh()
    }catch(e){if(accessUser.current===userId)notify(e.message,true)}finally{manualInFlight.current=false;setBusy(false)}
  }
  async function logCurrentScan(){const userId=session?.user.id;setBusy(true);try{const completion=await rpc('complete_chore',{p_token:route.tag,p_request:scanRequest(route.tag,session.user.id)});if(accessUser.current!==userId)return;setScanState(previous=>({...previous,error:'',completion}));setHouseId(completion.household_id)}catch(e){setScanState(previous=>({...previous,error:e.message}))}finally{setBusy(false)}}
  function tagHouseholds(){if(route.tag)sessionStorage.setItem('dishes-tag-setup',route.tag);finishScan();setView('household')}
  const currentScan=scanState?.identity===((session?.user.id||'public')+':'+route.tag+':'+scanConfigure.current)?scanState:null
  const weeklyHouse=houses.find(h=>h.id===(currentScan?.info?.member?currentScan.info.household_id:houseId))
  const weeklyCelebration=session&&weeklyHouse?<WeeklyCelebration key={weeklyHouse.id+session.user.id} household={weeklyHouse} enabled={!tutorialOpen&&!modal&&!busy&&(!route.tag||Boolean(currentScan&&!currentScan.loading))&&view!=='workshop'} renderDialog={props=><Modal {...props}/>} onCasino={result=>{if(route.tag)finishScan();setHouseId(result.household_id);setCasinoVisit(n=>n+1);setView('dashboard')}} onInspect={result=>{if(route.tag)finishScan();setHouseId(result.household_id);setWeeklyFocus(result);setView('household')}}/>:null
  if(route.tag&&(!tagAuthMode||session))return <TagScanPage key={(session?.user.id||'public')+route.tag} token={route.tag} info={currentScan?.info} loading={!currentScan||currentScan.loading} error={currentScan?.error} completion={currentScan?.completion} session={session} houses={houses} configure={scanConfigure.current} initialTarget={scanTarget.current} busy={busy} onDone={finishScan} onSignIn={setTagAuthMode} onHouseholds={tagHouseholds} onChores={()=>{setPendingSticker(route.tag);finishScan();setView('chores')}} onLog={logCurrentScan} weeklyCelebration={weeklyCelebration} onSaved={updated=>setScanState(previous=>previous?.completion?.id===updated.id?{...previous,completion:updated}:previous)} renderTagForm={props=><TagForm {...props}/>} onClaimed={async id=>{await loadHouses(id);finishScan();setView('chores');notify('Sticker claimed and configured. No writing is needed.')}} onSaveConfiguration={async params=>{await rpc('save_chore_rewards',params);finishScan();notify('Chore configuration saved.')}}/>
  if(!session)return <>{route.tag&&<div className="tag-auth-banner"><span>Your sticker will be here after sign-in.</span><button className="text-button" onClick={()=>setTagAuthMode(null)}>Back to sticker</button></div>}<Auth initialMode={tagAuthMode||'login'} onMessage={notify} invite={route.invite} theme={theme}/>{toast&&<Toast toast={toast} onClose={()=>setToast(null)}/>}</>
  const unread=notifications.filter(n=>!n.read_at).length
  const nav=[['dashboard','grid','Dashboard'],['chores','tag','Chores & stickers'],['household','users','Your household'],['notifications','bell','Notifications'],['community','trophy','Leaderboard'],...(platformAdmin?[['workshop','tag','Tag workshop']]:[])]
  const currentName=me?.display_name||session.user.user_metadata?.display_name||session.user.user_metadata?.full_name||session.user.user_metadata?.name||'there'
  const dailyCount=tag=>Number(scheduleRows.find(row=>row.id===tag.id)?.done||0)
  const myTeamId=members.find(m=>m.user_id===session?.user.id)?.team_id
  const otherTeamUserIds=members.filter(m=>teamsEnabled(activeHouse)?m.team_id&&m.team_id!==myTeamId:m.user_id!==session.user.id).map(m=>m.user_id)
  const otherScoreTitle=`${teamsEnabled(activeHouse)?"Other teams":"Other members"}’ ${reward.id==='stars'?'stickers':reward.id==='adventure'?'chores':'points'}`
  const otherTeamScore=(dashboard?.scores||[]).filter(score=>otherTeamUserIds.includes(score.user_id)).reduce((total,score)=>total+rewardValue(reward,score),0)
  function openChoreHistory(scope,title){
    const today=dashboard?.today||localDate(activeHouse.timezone)
    setModal({type:'choreHistory',title,selection:{householdId:houseId,timezone:activeHouse.timezone,from:scope==='personalToday'?today:dashboard?.week_start||weekStart(activeHouse.timezone),through:today,userId:scope==='personalToday'?session.user.id:null,userIds:scope==='otherTeams'?otherTeamUserIds:undefined}})
  }
  const todaysTags=unassignedAvailable(scheduleRows)
  return <div className={`app-shell theme-${theme.id} ${theme.id!=='wizard'?'theme-light':''}`}><ThemeAtmosphere theme={theme}/>
    <aside className="sidebar"><Brand/><nav aria-label="Main navigation">{nav.map(([key,icon,label])=><button key={key} data-tour-nav={key} className={view===key?'active':''} onClick={()=>setView(key)}><Icon name={icon}/><span>{label}</span>{key==='notifications'&&unread>0&&<b className="count">{unread}</b>}</button>)}</nav><button className="account" onClick={()=>perform(async()=>{await disablePush();setPushEnabled(false);const {error}=await supabase.auth.signOut();if(error)throw error})}><span className="avatar">{initials(currentName)}</span><span><strong>{currentName}</strong><small>Sign out</small></span><Icon name="exit" size={18}/></button></aside>
    <div className="workspace"><header className="topbar"><span className="breadcrumb"><Icon name="home" size={17}/>{activeHouse?.name||'Your household'}<span>/</span>{nav.find(n=>n[0]===view)?.[2]}</span><div className="topbar-actions"><button className="icon-button" onClick={()=>setView('notifications')} aria-label={`Notifications, ${unread} unread`}><Icon name="bell"/>{unread>0&&<i/>}</button><span className="avatar small">{initials(currentName)}</span><button className="mobile-signout icon-button" onClick={()=>perform(async()=>{await disablePush();setPushEnabled(false);const {error}=await supabase.auth.signOut();if(error)throw error})} aria-label="Sign out"><Icon name="exit" size={18}/></button></div></header><main className="content">
    {view==='workshop'?(platformAdmin?<TagWorkshop/>:<Empty icon="tag" title={platformAdmin===null?'Checking platform access…':'Platform admin access required'} text="Batch writing is separate from household administration."/>):!housesReady?<div className="empty-state"><Icon name="home" size={40}/><h2>Finding your household…</h2></div>:!houses.length?<section className="welcome"><h1>Households</h1><div className="welcome-form"><HouseholdForm invite={route.invite} name={currentName==='there'?'':currentName} onSubmit={householdSubmit} busy={busy}/></div></section>:<>
    {route.invite&&<div className="banner"><span>Joining your invited household…</span><button className="text-button" onClick={()=>setModal({type:'household'})}>Join this household →</button></div>}
    {view==='dashboard'&&<>
      <div className="page-heading"><div><h1>Dashboard</h1></div></div>
      <AssignedChores rows={scheduleRows} loading={loading} onOpen={(frequency,title)=>setModal({type:'assignedChores',frequency,title})}/><div data-tour="rewards"><RewardDashboard key={houseId+reward.id} household={activeHouse} theme={theme} teams={teams} scores={dashboard?.scores||[]} members={members} currentUser={session.user.id} loading={loading} revision={dashboard} householdPoints={dashboard?.week_points} onChoose={()=>setModal({type:'sorting'})}/><Casino key={houseId+session.user.id} household={activeHouse} members={members} currentUser={session.user.id} revision={dashboard} visitToken={casinoVisit} onChanged={()=>refresh().catch(e=>notify(e.message,true))}/></div><div className="stats-grid" data-tour="totals"><Stat onOpen={()=>openChoreHistory('personalToday','Your chores today')} label="Your chores today" value={dashboard?.personal_today?.chores??(dashboard?0:'—')} secondaryValue={dashboard?rewardValue(reward,dashboard.personal_today):'—'} secondaryLabel={!['stars','adventure'].includes(reward.id)?'Points today':reward.id==='stars'?'Gold stars today':'Chores recorded today'} icon="check" color="lime"/><Stat onOpen={()=>openChoreHistory('household',!['stars','adventure'].includes(reward.id)?'Household points':reward.id==='stars'?'Household stickers':'Household chores')} label={!['stars','adventure'].includes(reward.id)?'Household points':reward.id==='stars'?'Household stickers':'Household chores'} value={!['stars','adventure'].includes(reward.id)?(dashboard?.week_points??'—'):(dashboard?.week_count??dashboard?.scores?.reduce((n,m)=>n+Number(m.chores),0)??'—')} icon="trophy" color="peach"/><Stat onOpen={()=>openChoreHistory('otherTeams',otherScoreTitle)} label={otherScoreTitle} value={dashboard?otherTeamScore:'—'} icon="users" color="lavender"/></div>
      <section className="panel trophy-gallery"><div className="trophy-gallery-heading"><h2>Trophy cases</h2><span className="pill">Collectibles</span></div>{loading&&!weeklyScores.length?<p role="status">Opening trophy cases…</p>:<TrophyCaseGrid entries={weeklyScores} mode={reward.id} householdId={houseId} preferredId={teamsEnabled(activeHouse)&&myTeamId?myTeamId:session.user.id}/>}</section>
      <div className="lower-grid"><section className="panel" data-tour="activity"><div className="panel-heading"><div><h2>Recent activity</h2></div><button className="text-button" onClick={()=>setView('notifications')}>View updates →</button></div><Activity onInspect={completion=>setModal({type:'completionDetails',completion})} reward={reward} items={dashboard?.activity?.slice(0,5)||[]} timezone={activeHouse?.timezone}/></section><section className="panel"><div className="panel-heading"><div><h2>Assigned to anyone</h2></div><button className="text-button" onClick={()=>setView('chores')}>View all →</button></div>{todaysTags.slice(0,4).map(t=><div className="today-row" key={t.id}><span className="chore-symbol"><Icon name="tag" size={18}/></span><div><strong>{t.chore}</strong><small>{t.location||'Around the house'}</small></div><span className={`pill ${dailyCount(t)>=t.daily_limit?'done':''}`}>{t.done}/{t.daily_limit} this {frequencyLabel(t)}</span></div>)}{!todaysTags.length&&<p className="empty-inline">No chores assigned to anyone are available right now.</p>}</section></div>
    </>}
    {view==='chores'&&<><div className="page-heading"><div><h1>Chores & stickers</h1></div>{owner&&<div className="heading-buttons" data-tour="chore-setup"><button className="button secondary" data-tour="configure-sticker" onClick={()=>openScan(true,null,pendingSticker)}><Icon name="scan"/>{pendingSticker?'Configure scanned sticker':'Tap to configure'}</button><button className="button" data-tour="add-chore" onClick={()=>setModal({type:'editTag'})}><Icon name="plus"/>Add chore</button></div>}</div>{randomChoresAvailable(activeHouse)&&<div className="unexpected-chore-entry"><button className="button secondary" onClick={()=>setModal({type:'unexpectedChore',household:activeHouse})}>Log unexpected weird chore</button></div>}<div className="chores-grid">{tags.map(t=><article className="chore-card" key={t.id}><div className="chore-card-top"><button type="button" className="button chore-do-button" aria-label={'Do chore: '+t.chore} disabled={busy||loading||scheduleRows.some(row=>row.id===t.id&&(!row.eligible||row.remaining<=0))} onClick={()=>doChore(t)}>Do chore</button><span className="points-chip">{completionReward(reward,t.points)}</span></div><h2>{t.chore}</h2><p>{t.location||'Around the house'}</p><p className="muted small-text">{choreAssignmentLabel(t,members,teams,teamsEnabled(activeHouse))} · {t.frequency||'daily'}</p>{!bindings.some(b=>b.chore_tag_id===t.id)&&<p className="physical-tag-status">No sticker assigned</p>}<div className="chore-progress"><span style={{width:`${Math.min(dailyCount(t)/t.daily_limit*100,100)}%`}}/></div><div className="chore-card-meta"><span>{dailyCount(t)} of {t.daily_limit} this {frequencyLabel(t)}</span></div><p className="muted small-text">{cooldownMinutes(t)>0?`${cooldownDuration(cooldownMinutes(t))} cooldown between completions`:t.daily_limit>1?'No cooldown':`Once per ${frequencyLabel(t)}`}</p>{owner?<div className="chore-card-actions"><button className="button secondary" onClick={()=>setModal({type:'editTag',tag:t})}>Edit chore</button><button className="button secondary" onClick={()=>setModal({type:'sticker',tag:t})}>{bindings.some(b=>b.chore_tag_id===t.id)?'Manage sticker':'Assign sticker'}</button><button className="text-button chore-delete-link" onClick={()=>setModal({type:'deleteChore',tag:t})}>Delete chore</button></div>:null}</article>)}</div>{!tags.length&&!loading&&<Empty icon="tag" title="Every little job starts here." text={owner?'Add your first sticker and choose its chore, eligibility, and repeat limit.':'Your household admin can set up chore stickers here.'}/>}</>}
    {view==='household'&&<><PwaSetup/><div className="page-heading"><div><h1>{activeHouse?.name}</h1></div><div className="heading-buttons"><label><span className="sr-only">Switch household</span><select aria-label="Switch household" value={houseId} onChange={e=>setHouseId(e.target.value)}>{houses.map(h=><option key={h.id} value={h.id}>{h.name}</option>)}</select></label><button className="button secondary" onClick={()=>setModal({type:'household'})}><Icon name="plus"/>Create or join another</button></div></div>{owner&&<section className="panel household-style-panel"><div><span className="style-panel-icon">{theme.emoji}</span><div><h2>{theme.name}</h2><p>Change your household’s reward system to one that suits you</p></div></div><button className="button secondary" data-tour="household-settings" onClick={()=>setModal({type:'themeSettings'})}>Household settings</button></section>}<HallOfFame key={houseId} preferredId={teamsEnabled(activeHouse)&&me?.team_id?me.team_id:session.user.id} household={activeHouse} initialResult={weeklyFocus?.household_id===houseId?weeklyFocus:null} onFocusConsumed={()=>setWeeklyFocus(null)}/>{teamsEnabled(activeHouse)&&<section className="panel affiliation-panel"><div><TeamBadge team={teamFor(me,teams)} size={45}/><div><h2>{teamFor(me,teams)?.name||'Choose your team'}</h2></div></div><button className="button secondary" onClick={()=>setModal({type:'sorting'})}>Choose your team <span>→</span></button></section>}<section className="panel" data-tour="members"><div className="panel-heading"><h2>Members</h2><span className="pill">{members.length} members · {adminCount(members)} admin{adminCount(members)===1?'':'s'}</span></div><p className="admin-guidance">Admins configure chores, invite members, and manage household settings. The person who creates a household starts as its first admin.</p>{members.map((m,i)=><div className="member-admin-entry" key={m.user_id}><div className="member-row"><span className={`avatar color-${i%4}`}>{initials(m.display_name)}</span><div><strong>{m.display_name}{m.user_id===session.user.id?' (you)':''}</strong><small>{teamsEnabled(activeHouse)?(teamFor(m,teams)?.name||'No team yet')+' · ':''} {isHouseholdAdmin(m)?'Household admin':'Household member'}</small></div>{owner&&teamsEnabled(activeHouse)?<label className="member-team-select"><span className="sr-only">Team for {m.display_name}</span><select aria-label={`Team for ${m.display_name}`} value={m.team_id||''} disabled={busy} onChange={e=>perform(async()=>{await rpc('choose_team',{p_household:houseId,p_team:e.target.value||null,p_user:m.user_id});await refresh()},'Member’s team updated.')}><option value="">No team</option>{teams.filter(t=>t.active).map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select></label>:<span className="pill">{isHouseholdAdmin(m)?'Admin':'Member'}</span>}</div>{owner&&<AdminMemberActions member={m} members={members} currentUser={session.user.id} busy={busy} onAction={setModal}/>}</div>)}</section>
    {owner&&<StickerReleaseRequests requests={releaseRequests} busy={busy} onReview={(request,release)=>release?setModal({type:'releaseSticker',token:request.token,request}):perform(async()=>{await rpc('review_sticker_release',{p_request:request.id,p_release:false});await refresh()},'Release request declined.')}/>}
    {owner&&<section className="panel invite-panel"><div><h2>Invitations</h2><p>Add family, kids, or room mates to this household</p></div><button className="button" disabled={busy} onClick={()=>perform(async()=>{const code=await rpc('invite_code',{p_household:houseId,p_rotate:false});setModal({type:'invite',code})})}>Send Invitation<Icon name="arrow"/></button></section>}{owner&&<section className="panel delete-household-panel"><div><h2>Delete household</h2><p>Permanently remove this household and its shared history for all members.</p></div><button className="button secondary" disabled={busy} onClick={()=>setModal({type:'deleteHousehold',household:activeHouse})}>Delete household</button></section>}</>}
    {view==='community'&&<CommunityLeaderboard key={houseId+session.user.id} household={activeHouse} userId={session.user.id} owner={owner} onCancel={()=>setView('dashboard')}/>}
    {view==='notifications'&&<><div className="page-heading"><div><h1>Notifications</h1></div><button className="button secondary" disabled={busy||!unread} onClick={()=>perform(async()=>{await rpc('read_notifications');await refresh()},'You’re all caught up.')}>Mark all as read</button></div><section className="panel notification-panel"><div><h2>Phone notifications</h2><small>{isNative?'Allow notifications when Android asks. You can change them later in your phone’s app settings. Delivery depends on your connection and Android settings.':'On iPhone: Share → Add to Home Screen, open the app there, then enable notifications. Delivery depends on your device and notification permissions.'}</small></div><button className="button secondary" disabled={busy} onClick={()=>perform(async()=>{if(pushEnabled){await disablePush();setPushEnabled(false)}else{await enablePush();setPushEnabled(true)}},pushEnabled?'Notifications disabled on this device.':'Phone notifications are on for this device.')}>{pushEnabled?'Turn off on this device':'Enable phone notifications'}<Icon name="bell" size={17}/></button></section><section className="panel notification-list">{notifications.map(n=><article className={`notification-row ${!n.read_at?'unread':''}`} key={n.id}><span className="avatar lime"><Icon name="check"/></span><div><button type="button" className="notification-thread-button" onClick={()=>perform(async()=>{const data=await rpc('chore_social',{p_completion:n.completion_id});setHouseId(data.completion.household_id);setModal({type:'completionDetails',completion:data.completion})})}><strong>{n.message}</strong><span className="sr-only"> Open chore comments and likes</span></button><p>{houses.find(h=>h.id===n.household_id)?.name||'Your household'} · {when(n.created_at)}</p></div>{!n.read_at&&<i aria-label="Unread"/>}</article>)}{!notifications.length&&<Empty icon="bell" title="No notifications" text="Chore notifications will appear here."/>}</section></>}
    </>}

    <div className="feedback-entry app-help-actions" data-tour="help"><button className="text-button" onClick={()=>setModal({type:'feedback'})}>Feedback, ideas & bug reports</button><button className="text-button" disabled={!activeHouse||loading||busy||view==='workshop'} onClick={()=>setTutorialReplay(n=>n+1)}>Replay tutorial</button></div>
    </main></div><nav className="mobile-nav" style={{'--nav-count':nav.length}} aria-label="Mobile navigation">{nav.map(([key,icon,label])=><button key={key} data-tour-nav={key} onClick={()=>setView(key)} className={view===key?'active':''} aria-label={label}><Icon name={icon}/><span>{key==='chores'?'Chores':key==='household'?'Household':key==='notifications'?'Updates':key==='workshop'?'Workshop':key==='community'?'Leaderboard':'Overview'}</span>{key==='notifications'&&unread>0&&<i/>}</button>)}</nav>
    <HouseholdTutorial userId={session.user.id} household={activeHouse} admin={owner} platformAdmin={Boolean(platformAdmin)} hasChores={tags.length>0} ready={Boolean(activeHouse&&me&&platformAdmin!==null&&!loading&&!busy&&!modal&&!route.tag&&!route.invite&&!route.completion&&!recovery)} canStart={view!=='workshop'} replayToken={tutorialReplay} view={view} onViewChange={setView} onActiveChange={setTutorialOpen}/>
    {modal?.type==='deleteHousehold'&&owner&&modal.household.id===houseId&&<Modal title="Delete household?" onClose={busy?()=>{}:closeModal}><DeleteHousehold key={houseId} household={modal.household} busy={busy} onCancel={closeModal} onDelete={confirmation=>perform(async()=>{await rpc('delete_household',{p_household:modal.household.id,p_confirmation:confirmation});closeModal();setTags([]);setMembers([]);setTeams([]);setDashboard(null);setBindings([]);setReleaseRequests([]);setNotifications([]);localStorage.removeItem('dishes-household');await loadHouses();setView('dashboard')},'Household deleted. Its stickers are available to claim again.')}/></Modal>}
    {modal?.type==='assignedChores'&&<Modal title={chorePeriodView(scheduleRows,modal.frequency).title} onClose={closeModal}><AssignedChoreList rows={chorePeriodView(scheduleRows,modal.frequency).chores} reward={reward}/></Modal>}
    {modal?.type==='choreHistory'&&<Modal title={modal.title} onClose={closeModal} wide><ChoreHistory key={session.user.id+modal.selection.householdId} selection={modal.selection} members={members} reward={reward}/></Modal>}
    {modal?.type==='feedback'&&<Modal title="Send feedback" onClose={closeModal}><FeedbackForm household={activeHouse} screen={view} onDone={closeModal}/></Modal>}
    {modal?.type==='manualCompletion'&&<Modal title={modal.completion.chore} onClose={manualDetailsPending?()=>{}:closeModal}><RewardCelebration scheme={reward.id} points={modal.completion.points} sticker={modal.completion.calendar_sticker} color={teamFor(me,teams)?.color||theme.colors[0]} teamName={teamFor(me,teams)?.name}/><p role="status">Chore logged · {completionReward(reward,modal.completion.points)}</p><button className="button secondary full" disabled={manualDetailsPending} onClick={closeModal}>Done</button><CompletionDetails key={modal.completion.id} completion={modal.completion} onPendingChange={setManualDetailsPending} onSaved={completion=>{setModal(previous=>previous?.type==='manualCompletion'?{...previous,completion}:previous);refresh().catch(()=>{})}}/></Modal>}
    {modal?.type==='completionDetails'&&<Modal title={modal.completion.chore} onClose={closeModal}><CompletionDetailView completion={modal.completion}/></Modal>}
    {weeklyCelebration}
    {modal?.type==='unexpectedChore'&&modal.household.id===houseId&&randomChoresAvailable(activeHouse)&&<Modal title="Unexpected weird chore" onClose={closeModal}><UnexpectedChore key={houseId+session.user.id} household={modal.household} userId={session.user.id} onLogged={()=>refresh()} onDone={closeModal}/></Modal>}
    {modal?.type==='sorting'&&<Modal title="Choose your team" onClose={closeModal}><ChooseTeam current={me?.team_id} teams={teams} busy={busy} onChoose={team=>perform(async()=>{await rpc('choose_team',{p_household:houseId,p_team:team,p_user:null});await refresh();setModal(null)},'Your team is chosen. Every point counts.')}/></Modal>}
    {['adminRole','transferAdmin'].includes(modal?.type)&&owner&&<Modal title={modal.type==='transferAdmin'?'Transfer admin role':'Change household admin'} onClose={closeModal}><AdminConfirmation action={modal} busy={busy} onCancel={closeModal} onConfirm={()=>perform(async()=>{if(modal.type==='transferAdmin')await rpc('transfer_household_admin',{p_household:houseId,p_user:modal.member.user_id});else await rpc('set_household_admin',{p_household:houseId,p_user:modal.member.user_id,p_admin:modal.makeAdmin});closeModal();await refresh()},'Household admin access updated.')}/></Modal>}
    {modal?.type==='themeSettings'&&owner&&<Modal title="Household settings" onClose={closeModal} wide><ThemeSettings key={houseId+activeHouse.theme} household={activeHouse} teams={teams} members={members} busy={busy} onSaveTheme={(value,enabled)=>perform(async()=>{await rpc('set_household_experience',{p_household:houseId,p_theme:value,p_teams_enabled:enabled});await loadHouses(houseId);await refresh()},'Household settings updated.')} onCatSaved={async()=>{await loadHouses(houseId);await refresh()}} onEditTeam={team=>setModal({type:'editTeam',team})} onDeleteTeam={team=>setModal({type:'deleteTeam',team})}/></Modal>}
    {modal?.type==='deleteTeam'&&owner&&<Modal title="Delete team" onClose={()=>setModal({type:'themeSettings'})}><DeleteTeam team={modal.team} members={members} chores={tags} busy={busy} onCancel={()=>setModal({type:'themeSettings'})} onDelete={()=>perform(async()=>{await rpc('delete_team',{p_household:houseId,p_team:modal.team.id});await refresh();setModal({type:'themeSettings'})},'Team deleted. Members and chores are unassigned; personal points and past results are preserved.')}/></Modal>}
    {modal?.type==='editTeam'&&owner&&<Modal title={modal.team?'Edit team':'A new household team'} onClose={closeModal}><TeamForm household={activeHouse} team={modal.team} busy={busy} onCancel={()=>setModal({type:'themeSettings'})} onSave={parameters=>perform(async()=>{await rpc('save_team',parameters);await refresh();setModal({type:'themeSettings'})},'Team saved.')}/></Modal>}
    {modal?.type==='household'&&<Modal title="Make yourself at home" onClose={closeModal}><HouseholdForm invite={route.invite} name={currentName} busy={busy} onSubmit={householdSubmit}/></Modal>}
    {modal?.type==='deleteChore'&&owner&&<Modal title="Delete chore" onClose={closeModal}><DeleteChore chore={modal.tag} busy={busy} onCancel={closeModal} onDelete={()=>perform(async()=>{await rpc('delete_chore',{p_household:houseId,p_chore:modal.tag.id});await refresh();closeModal()},'Chore deleted. Completed chores and points are preserved.')}/></Modal>}
    {modal?.type==='editTag'&&owner&&<Modal title={modal.tag?'Edit chore':'New chore'} onClose={closeModal}><TagForm household={houses.find(h=>h.id===modal.tag?.household_id)||activeHouse} tag={modal.tag} members={members} teams={teams} busy={busy} onSubmit={saveTag} onCancel={closeModal}/></Modal>}
    {modal?.type==='sticker'&&owner&&<Modal title={bindings.some(b=>b.chore_tag_id===modal.tag.id)?"Manage sticker":"Assign sticker"} onClose={closeModal}><StickerInfo tag={modal.tag} binding={bindings.find(b=>b.chore_tag_id===modal.tag.id)} tags={tags} bindings={bindings} busy={busy} onReassign={chore=>perform(async()=>{await rpc('reassign_sticker',{p_token:bindings.find(b=>b.chore_tag_id===modal.tag.id).token,p_chore:chore});await refresh();closeModal()},'Sticker assigned to its new chore.')} onAssign={()=>openScan(true,modal.tag)} onRelease={()=>setModal({type:'releaseSticker',token:bindings.find(b=>b.chore_tag_id===modal.tag.id).token})} onMessage={notify}/></Modal>}
    {modal?.type==='releaseSticker'&&owner&&<Modal title="Release this physical sticker?" onClose={closeModal}><p>The sticker will become unassigned and another household can claim it. Your chore configuration and completed-chore history stay in this household.</p><button className="button full" disabled={busy} onClick={()=>perform(async()=>{if(modal.request)await rpc('review_sticker_release',{p_request:modal.request.id,p_release:true});else await rpc('release_sticker',{p_token:modal.token});closeModal();await refresh()},'Sticker released. Your chore history is preserved.')}>Release sticker</button></Modal>}
    {modal?.type==='invite'&&owner&&<Modal title="Everyone’s invited" onClose={closeModal}><p>Anyone with this link can join <strong>{activeHouse?.name}</strong>. They are added automatically after signing in. Share it with the people who live with you.</p><textarea readOnly rows={3} value={inviteLink(modal.code)} onFocus={e=>e.target.select()}/><button className="button full" onClick={()=>navigator.clipboard.writeText(inviteLink(modal.code)).then(()=>notify('Invitation copied.')).catch(()=>notify('Select and copy the invitation above.',true))}>Copy invitation link</button><button className="text-button" disabled={busy} onClick={()=>perform(async()=>{const code=await rpc('invite_code',{p_household:houseId,p_rotate:true});setModal({type:'invite',code})},'New invitation created. The old link no longer works.')}>Replace invitation link</button></Modal>}
    {modal?.type==='scan'&&<Modal title={modal.configure?'Configure sticker':'Scan sticker'} onClose={closeModal}><div className="scan-modal-art"><Icon name="scan" size={60}/></div><p>Hold your phone near a Chore Chip Sticker. You can also tap a sticker while this app is closed; your phone will offer to open its link.</p><p className="muted">An admin can claim an unassigned sticker and configure its chore after scanning.</p>{owner&&<button className="button full" onClick={()=>{scanner.current?.abort();setModal({type:'editTag'})}}>Configure a custom chore<Icon name="plus"/></button>}</Modal>}
    {scanState&&<Modal title={scanState.loading?'Logging your chore…':scanState.error?'Could not log chore':'Chore logged'} onClose={finishScan}><div className={`completion-symbol ${scanState.error?'warning':''}`}><Icon name={scanState.error?'clock':'check'} size={40}/></div>{scanState.loading?<p>Checking your sticker and household limits…</p>:scanState.error?<p role="alert">{scanState.error}</p>:<><h3 className="completion-name">{scanState.completion.chore}</h3><p className="completion-points">{completionReward(reward,scanState.completion.points)}</p><p className="muted">Logged for you. Your household has been notified.</p></>}<button className="button full" onClick={finishScan}>Back to your household</button></Modal>}
    {recovery&&<Modal title="Choose a new password" onClose={()=>setRecovery(false)}><form onSubmit={e=>{e.preventDefault();const password=new FormData(e.currentTarget).get('password');perform(async()=>{const {error}=await supabase.auth.updateUser({password});if(error)throw error;setRecovery(false)},'Your password has been updated.')}}><label>New password<input name="password" type="password" minLength={8} autoComplete="new-password" required/></label><button className="button full" disabled={busy}>Update password</button></form></Modal>}
    {toast&&<Toast toast={toast} onClose={()=>setToast(null)}/>}
  </div>
}

function Toast({toast,onClose}){return <div className={`toast ${toast.error?'error':''}`} role={toast.error?'alert':'status'}><Icon name={toast.error?'bell':'check'} size={20}/><span>{toast.message}</span><button onClick={onClose} aria-label="Dismiss message">×</button></div>}
function Stat({label,value,secondaryValue,secondaryLabel,icon,color,onOpen}){return <button type="button" className={`stat-card ${color}`} onClick={onOpen} aria-haspopup="dialog"><span className="stat-top"><span>{label}</span><Icon name={icon}/></span><strong className="stat-value">{value}</strong>{secondaryLabel&&<span className="stat-secondary"><strong>{secondaryValue}</strong><span>{secondaryLabel}</span></span>}</button>}
function Empty({icon,title,text}){return <div className="empty-state"><span className="empty-icon"><Icon name={icon} size={32}/></span><h2>{title}</h2><p>{text}</p></div>}
function Activity({items,reward=rewardFor(),onInspect}){const Row=onInspect?'button':'div';return <div className="activity-list">{items.map(a=><Row type={onInspect?'button':undefined} className={'activity-row'+(onInspect?' activity-open':'')} key={a.id} onClick={onInspect?()=>onInspect(a):undefined} aria-label={onInspect?'View '+a.display_name+'’s chore: '+a.chore:undefined}><span className="activity-check"><Icon name="check" size={16}/></span><span className="activity-summary"><span className="activity-description"><strong>{a.display_name}</strong> completed <strong>{a.chore}</strong></span><small>{when(a.completed_at)}</small>{onInspect&&<span className="activity-action">Comments, likes & refutations</span>}</span><span className="activity-points">{!['stars','adventure'].includes(reward.id)?`+${a.points}`:reward.id==='stars'?'★ +1':'✓'}</span></Row>)}{!items.length&&<p className="empty-inline">No recent activity.</p>}</div>}
