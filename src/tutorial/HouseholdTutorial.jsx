import {useEffect,useId,useLayoutEffect,useMemo,useRef,useState} from 'react'
import {createPortal} from 'react-dom'
import {rpc} from '../api'
import {tutorialSteps,tutorialStepIndex,tutorialPlacement} from './steps'
import './tutorial.css'

const TAB_NAMES={dashboard:'Overview',chores:'Chores',household:'Household',notifications:'Updates',community:'Leaderboard',workshop:'Workshop'}
const viewport=()=>({width:window.innerWidth,height:window.visualViewport?.height||window.innerHeight})
const visibleTarget=selectors=>selectors.flatMap(selector=>[...document.querySelectorAll(selector)]).find(node=>{const rect=node.getBoundingClientRect();return rect.width>0&&rect.height>0&&getComputedStyle(node).visibility!=='hidden'})

export default function HouseholdTutorial({userId,household,admin,platformAdmin,hasChores,ready,canStart,replayToken,view,onViewChange,onActiveChange}){
 const identity=userId&&household?.id?`${userId}:${household.id}`:''
 const steps=useMemo(()=>tutorialSteps({admin,platformAdmin,hasChores,teams:household?.teams_enabled===true,reward:household?.reward_scheme}),[admin])
 const [phase,setPhase]=useState('checking'),[stepId,setStepId]=useState(null),[saving,setSaving]=useState(false),[error,setError]=useState(''),[rect,setRect]=useState(null),[screen,setScreen]=useState(viewport),[cardHeight,setCardHeight]=useState(270)
 const loaded=useRef(''),identityRef=useRef(identity),generation=useRef(0),inFlight=useRef(false),queue=useRef(Promise.resolve()),seenReplay=useRef(replayToken),returnView=useRef(view),returnScroll=useRef(0),previousFocus=useRef(null),card=useRef(null)
 const titleId=useId(),bodyId=useId(),index=tutorialStepIndex(steps,stepId),step=steps[index]
 const displayed=ready&&(phase==='welcome'||phase==='tour'),engaged=ready&&(displayed||(phase==='checking'&&canStart))
 identityRef.current=identity

 useEffect(()=>{
  loaded.current='';identityRef.current=identity;generation.current++;seenReplay.current=replayToken;inFlight.current=false;setSaving(false);setError('');setPhase('checking');setStepId(null)
  return()=>{identityRef.current='';loaded.current='';generation.current++}
 },[identity])
 useEffect(()=>{
  if(!ready||!canStart||!identity||loaded.current===identity)return
  let active=true,finished=false;const token=++generation.current;loaded.current=identity
  setPhase('checking')
  rpc('household_tutorial',{p_household:household.id}).then(progress=>{
   finished=true;if(!active||token!==generation.current)return
   if(progress.status==='active'){returnView.current=view;returnScroll.current=window.scrollY;setStepId(steps[tutorialStepIndex(steps,progress.step)].id);setPhase('tour')}
   else setPhase(progress.status==='completed'||progress.status==='skipped'?'closed':'welcome')
  }).catch(()=>{finished=true;if(active&&token===generation.current)setPhase('closed')})
  return()=>{active=false;if(!finished&&loaded.current===identity)loaded.current=''}
 },[identity,ready,canStart])
 useEffect(()=>{onActiveChange(engaged);return()=>onActiveChange(false)},[engaged,onActiveChange])

 function save(next,status){
  const expected=identity,houseId=household.id
  const job=queue.current.catch(()=>{}).then(()=>{if(identityRef.current===expected)return rpc('save_household_tutorial',{p_household:houseId,p_step:next,p_status:status})})
  queue.current=job;return job
 }
 function start(){
  generation.current++;loaded.current=identity;returnView.current=view;returnScroll.current=window.scrollY;setStepId(steps[0].id);setPhase('tour');setError('');setSaving(true);inFlight.current=true
  const expected=identity
  save(steps[0].id,'active').catch(()=>{if(identityRef.current===expected)setError('Your place could not be saved. You can retry with Next or skip the tour.')}).finally(()=>{if(identityRef.current===expected){setSaving(false);inFlight.current=false}})
 }
 useEffect(()=>{if(ready&&identity&&replayToken!==seenReplay.current){seenReplay.current=replayToken;start()}},[replayToken,ready,identity])
 async function move(next){
  if(inFlight.current)return;inFlight.current=true;setSaving(true);setError('');const token=++generation.current,complete=next>=steps.length,id=complete?step.id:steps[next].id
  try{await save(id,complete?'completed':'active');if(token!==generation.current)return;if(complete){setPhase('closed');onViewChange(returnView.current);requestAnimationFrame(()=>window.scrollTo({top:returnScroll.current,behavior:'auto'}))}else setStepId(id)}
  catch{if(token===generation.current)setError('Your place could not be saved. Try again, or skip the tour.')}
  finally{if(token===generation.current){setSaving(false);inFlight.current=false}}
 }
 function dismiss(){
  generation.current++;inFlight.current=false;setSaving(false);setError('');setPhase('closed')
  save(phase==='tour'?step.id:steps[0].id,'skipped').catch(()=>{})
  if(phase==='tour'){onViewChange(returnView.current);requestAnimationFrame(()=>window.scrollTo({top:returnScroll.current,behavior:'auto'}))}
 }

 useEffect(()=>{if(phase==='tour'&&ready&&view!==step.view)onViewChange(step.view)},[phase,ready,step.id,view,onViewChange])
 useLayoutEffect(()=>{
  if(!displayed)return
  let target=null,observed=null,frame=0,scrolled=false
  const observer=new ResizeObserver(()=>update())
  const measure=()=>{
   setScreen(previous=>{const next=viewport();return previous.width===next.width&&previous.height===next.height?previous:next})
   if(phase!=='tour'||view!==step.view){setRect(null);return}
   target=visibleTarget([...step.targets,`[data-tour-nav="${step.view}"]`])
   if(!target){setRect(null);return}
   if(target!==observed){observer.disconnect();observer.observe(target);observed=target}
   if(!scrolled){scrolled=true;target.scrollIntoView({block:'center',inline:'nearest',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'})}
   const box=target.getBoundingClientRect(),port=viewport(),left=Math.max(6,box.left-7),top=Math.max(6,box.top-7),right=Math.min(port.width-6,box.right+7),bottom=Math.min(port.height-6,box.bottom+7)
   setRect(previous=>{const next=right>left&&bottom>top?{left,top,right,bottom,width:right-left,height:bottom-top}:null;return previous&&next&&Object.keys(next).every(key=>Math.abs(previous[key]-next[key])<.5)?previous:next})
  }
  const update=()=>{cancelAnimationFrame(frame);frame=requestAnimationFrame(measure)}
  measure();const mutations=new MutationObserver(update);const shell=document.querySelector('.app-shell');if(shell)mutations.observe(shell,{childList:true,subtree:true})
  window.addEventListener('resize',update);window.addEventListener('scroll',update,true);window.visualViewport?.addEventListener('resize',update)
  return()=>{mutations.disconnect();cancelAnimationFrame(frame);observer.disconnect();window.removeEventListener('resize',update);window.removeEventListener('scroll',update,true);window.visualViewport?.removeEventListener('resize',update)}
 },[displayed,phase,step.id,view])
 useLayoutEffect(()=>{if(!displayed||!card.current)return;const node=card.current;const update=()=>setCardHeight(node.getBoundingClientRect().height);update();const observer=new ResizeObserver(update);observer.observe(node);return()=>observer.disconnect()},[displayed,step.id,phase])
 useEffect(()=>{
  if(!displayed)return
  previousFocus.current=document.activeElement
  const shell=document.querySelector('.app-shell'),wasInert=shell?.hasAttribute('inert');shell?.setAttribute('inert','')
  return()=>{if(!wasInert)shell?.removeAttribute('inert');const previous=previousFocus.current;requestAnimationFrame(()=>{if(previous?.isConnected)previous.focus?.({preventScroll:true})})}
 },[displayed])
 useEffect(()=>{if(displayed)card.current?.querySelector('h2')?.focus({preventScroll:true})},[displayed,step.id,phase])
 useEffect(()=>{if(!displayed)return;const handler=e=>keyDown(e);document.addEventListener('keydown',handler,true);return()=>document.removeEventListener('keydown',handler,true)},[displayed,phase,index,saving,identity,steps])
 useEffect(()=>{if(displayed&&!saving&&document.activeElement===document.body)card.current?.querySelector('h2')?.focus({preventScroll:true})},[displayed,saving])
 const position=tutorialPlacement(phase==='tour'?rect:null,screen,cardHeight)
 function keyDown(e){
  if(e.key==='Escape'){e.preventDefault();dismiss();return}
  if(e.key==='ArrowRight'&&phase==='tour'){e.preventDefault();move(index+1);return}
  if(e.key==='ArrowLeft'&&phase==='tour'&&index>0){e.preventDefault();move(index-1);return}
  if(e.key==='Tab'){
   const buttons=[...card.current.querySelectorAll('button:not(:disabled)')],first=buttons[0],last=buttons.at(-1)
   if(!card.current.contains(document.activeElement)){e.preventDefault();(e.shiftKey?last:first)?.focus()}
   else if(e.shiftKey&&(document.activeElement===first||document.activeElement.tagName==='H2')){e.preventDefault();last?.focus()}
   else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus()}
  }
 }
 if(!displayed)return null
 return createPortal(<div className={`tutorial-layer ${phase==='welcome'?'tutorial-welcome':''}`} data-tutorial-step={phase==='tour'?step.id:'welcome'}>
  {phase==='tour'&&rect?<div className="tutorial-spotlight" aria-hidden="true" style={{left:rect.left,top:rect.top,width:rect.width,height:rect.height}}/>:<div className="tutorial-shade" aria-hidden="true"/>}
  <section ref={card} className={`tutorial-card tutorial-${position.side}`} role="dialog" aria-modal="true" aria-labelledby={titleId} aria-describedby={bodyId} style={{left:position.left,top:position.top,width:position.width,'--tutorial-arrow':`${position.arrow}px`,maxHeight:Math.max(100,screen.height-24)}}>
   <div className="tutorial-card-top"><span aria-live="polite">{phase==='welcome'?'CHIP IN':`${TAB_NAMES[step.view]} · ${index+1} of ${steps.length}`}</span><button type="button" className="tutorial-close" aria-label="Skip tutorial" onClick={dismiss}>×</button></div>
   <h2 id={titleId} tabIndex={-1}>{phase==='welcome'?'A quick tour of Chip In':step.title}</h2>
   <p id={bodyId}>{phase==='welcome'?`${steps.length} quick tips for ${household.name}: chores, ${admin?'adding members, ':''}daily scores, weekly trophies and feedback. Skip or replay anytime.`:step.body}</p>
   {error&&<p className="tutorial-error" role="alert">{error}</p>}
   {phase==='welcome'?<div className="tutorial-actions"><button type="button" className="tutorial-secondary" onClick={dismiss}>Not now</button><button type="button" className="tutorial-primary" onClick={start}>Start tour</button></div>:<><div className="tutorial-progress" aria-hidden="true"><span style={{width:`${(index+1)/steps.length*100}%`}}/></div><div className="tutorial-actions"><button type="button" className="tutorial-secondary" disabled={saving||index===0} onClick={()=>move(index-1)}>Back</button><button type="button" className="tutorial-primary" disabled={saving} onClick={()=>move(index+1)}>{saving?'Saving…':index===steps.length-1?'Finish tour':'Next'}</button></div><button type="button" className="tutorial-skip" onClick={dismiss}>Skip tutorial</button></>}
  </section>
 </div>,document.body)
}
