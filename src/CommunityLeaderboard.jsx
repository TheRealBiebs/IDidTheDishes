import TrophyCase,{TrophyCaseGrid} from './rewards/TrophyCase'
import {rewardForTheme} from './household-experience'
import { useEffect,useState } from 'react'
import { rpc } from './api'
import './community.css'

const sharing='Participants can see your household name, team names, and weekly win points for the household and its teams, and the theme used to display their trophy cases. Member names, individual scores, chore details, comments, and photos stay private.'

export default function CommunityLeaderboard({household,userId,owner,onCancel}) {
  const preference=`chip-in-community-following:${userId}:${household.id}`
  const [status,setStatus]=useState(null),[data,setData]=useState(null),[accepted,setAccepted]=useState(false),[error,setError]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[revision,setRevision]=useState(0),[offset,setOffset]=useState(0),[leaving,setLeaving]=useState(false)
  const [expandedHouse,setExpandedHouse]=useState(null)
  const [followingOnly,setFollowingOnly]=useState(()=>{try{return localStorage.getItem(preference)==='true'}catch{return false}})
  useEffect(()=>{
    let active=true
    rpc('community_status',{p_household:household.id}).then(next=>{if(active){setStatus(next);if(!next.joined||!next.accepted)setData(null)}}).catch(e=>{if(active){setError(e.message);setLoading(false)}})
    return()=>{active=false}
  },[household.id,revision])
  useEffect(()=>{
    if(!status?.joined||!status?.accepted)return
    let active=true;setLoading(true);setError('')
    rpc('community_board',{p_household:household.id,p_followed_only:followingOnly,p_offset:offset}).then(result=>{if(active)setData(result)}).catch(e=>{if(active)setError(e.message)}).finally(()=>{if(active)setLoading(false)})
    return()=>{active=false}
  },[household.id,status?.joined,status?.accepted,followingOnly,offset,revision])
  useEffect(()=>{
    const refresh=()=>{if(document.visibilityState==='visible')setRevision(n=>n+1)}
    const timer=setInterval(refresh,30000);document.addEventListener('visibilitychange',refresh)
    return()=>{clearInterval(timer);document.removeEventListener('visibilitychange',refresh)}
  },[])
  async function perform(action){setBusy(true);setError('');try{await action();setStatus(await rpc('community_status',{p_household:household.id}));setRevision(n=>n+1)}catch(e){setError(e.message)}finally{setBusy(false)}}
  function filter(value){setFollowingOnly(value);setOffset(0);setLoading(true);try{localStorage.setItem(preference,String(value))}catch{}}
  const ready=status?.joined&&status?.accepted
  return <div className="community"><div className="page-heading"><h1>Community trophy cases</h1></div>
    {error&&<div className="form-error" role="alert"><p>{error}</p><button className="text-button" onClick={()=>{setError('');setRevision(n=>n+1)}}>Retry leaderboard</button></div>}
    {!status?<p role="status">Checking community access…</p>:!ready?<section className="panel community-consent">
      <h2>{status.joined?'View the community leaderboard?':'Join the community leaderboard?'}</h2><p>{sharing}</p>
      <p>Joining shares <strong>{household.name}</strong> with other participating households. Weekly win points come from completed weeks, with one point per winning team or individual. They accumulate across weeks.</p>
      <p>You can follow households to show just them and your own household. Follows are private to your account. A household admin can stop sharing at any time.</p>
      {!status.joined&&!owner?<><p>A household admin needs to join before members can view the board.</p><button className="button secondary" onClick={onCancel}>Back to dashboard</button></>:<><label className="check-label"><input type="checkbox" checked={accepted} onChange={e=>setAccepted(e.target.checked)}/>I understand and agree to the sharing described above.</label><div className="community-actions"><button className="button" disabled={busy||!accepted} onClick={()=>perform(()=>status.joined?rpc('accept_community',{p_household:household.id,p_accept:true}):rpc('set_community_sharing',{p_household:household.id,p_enabled:true,p_accept:true}))}>{busy?'Joining…':status.joined?'Agree and view leaderboard':'Join and view leaderboard'}</button><button className="button secondary" disabled={busy} onClick={onCancel}>Not now</button></div></>}
    </section>:<>
      <details className="community-disclosure"><summary>What is shared?</summary><p>{sharing}</p></details>
      <div className="community-toolbar"><div className="segmented" role="group" aria-label="Leaderboard households"><button aria-pressed={!followingOnly} onClick={()=>filter(false)}>All households</button><button aria-pressed={followingOnly} onClick={()=>filter(true)}>Following</button></div><button className="text-button" disabled={loading||busy} onClick={()=>setRevision(n=>n+1)}>Refresh scores</button></div>
      <p className="muted">Weekly win points from completed weeks. Chore point totals are not shown.</p>
      {followingOnly&&data?.following_count===0&&<p>Follow households in All households to compare their scores here. Your own household is always included.</p>}
      {loading?<p role="status">Loading weekly scores…</p>:data&&<><ol className="community-list">{data.households.map(h=><li className="panel community-household" key={h.id}>
        <div className="community-household-heading"><span className="community-rank" aria-label={`Community rank ${h.rank}`}>#{h.rank}</span><h2>{h.name}{h.id===household.id&&<small>Your household</small>}</h2><strong className="community-points">{h.points}<small>weekly win points</small></strong></div>
        {expandedHouse!==h.id&&<TrophyCase name={h.name} wins={h.points} trophies={h.trophies} mode={h.reward_scheme||rewardForTheme(h.theme)} compact hideName/>}
        {h.teams.length>0?<div className="community-trophy-teams"><button className="text-button" aria-expanded={expandedHouse===h.id} onClick={()=>setExpandedHouse(expandedHouse===h.id?null:h.id)}>{expandedHouse===h.id?'Hide team trophies':'Show team trophies'}</button>{expandedHouse===h.id&&<TrophyCaseGrid entries={h.teams} mode={h.reward_scheme||rewardForTheme(h.theme)} compact/>}</div>:h.teams_enabled===false&&<p className="muted">Individual mode · only the household’s combined weekly wins are shared.</p>}
        {h.id!==household.id&&<button className="button secondary" aria-label={`${h.following?'Unfollow':'Follow'} ${h.name}`} aria-pressed={h.following} disabled={busy} onClick={()=>perform(async()=>{await rpc('community_follow',{p_household:household.id,p_target:h.id,p_follow:!h.following});if(h.following&&followingOnly)setOffset(0)})}>{h.following?'Following · Unfollow':'Follow household'}</button>}
      </li>)}</ol>{!data.households.length&&<p>No households for this selection.</p>}{data.total>25&&<nav className="community-pagination" aria-label="Community leaderboard pages"><button className="button secondary" disabled={!offset} onClick={()=>setOffset(n=>Math.max(0,n-25))}>Previous</button><span>{offset+1}–{Math.min(offset+25,data.total)} of {data.total}</span><button className="button secondary" disabled={offset+25>=data.total} onClick={()=>setOffset(n=>n+25)}>Next</button></nav>}</>}
      {owner&&<section className="panel community-leave">{leaving?<><h2>Leave the community leaderboard?</h2><p>This removes your household’s name and team scores from the board and closes community access for its members.</p><div className="community-actions"><button className="button secondary" disabled={busy} onClick={()=>perform(async()=>{await rpc('set_community_sharing',{p_household:household.id,p_enabled:false,p_accept:false});setLeaving(false);setAccepted(false)})}>Stop sharing and leave</button><button className="text-button" disabled={busy} onClick={()=>setLeaving(false)}>Cancel</button></div></>:<button className="text-button" onClick={()=>setLeaving(true)}>Leave community leaderboard</button>}</section>}
    </>}
  </div>
}
