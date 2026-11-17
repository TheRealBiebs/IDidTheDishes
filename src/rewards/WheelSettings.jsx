import {useEffect,useState} from 'react'
import {rpc} from '../api'
import {WHEEL_TYPES,wheelSettings} from './wheel-settings'
import './unexpected-chore.css'

export default function WheelSettings({household,onSaved}){
 const [settings,setSettings]=useState(()=>wheelSettings(household)),[busy,setBusy]=useState(false),[error,setError]=useState(''),[saved,setSaved]=useState(false)
 useEffect(()=>{setSettings(wheelSettings(household));setSaved(false)},[household.id,JSON.stringify(household.unexpected_wheels)])
 function change(id,patch){setSettings(s=>({...s,[id]:{...s[id],...patch}}));setSaved(false);setError('')}
 async function save(e){e.preventDefault();setBusy(true);setError('');setSaved(false);try{await rpc('save_unexpected_wheels',{p_household:household.id,p_settings:settings});await onSaved?.();setSaved(true)}catch(e){setError(e.message)}finally{setBusy(false)}}
 return <section className="wheel-settings"><h3>Random chore wheels</h3><p>Log an unexpected chore with a required description, then spin for a reward. Each of the four segments is equally likely; repeating a value makes it more likely.</p>{household.reward_scheme==='stars'&&<p>Sticker Calendar awards one random calendar sticker instead of points. Point values below are saved for other reward systems.</p>}<form onSubmit={save}><fieldset disabled={busy}>{WHEEL_TYPES.map(([id,name])=><section className="wheel-setting-row" key={id}><h4>{name}</h4>{id!=='standard'&&<label className="check-label"><input type="checkbox" checked={settings[id].enabled} onChange={e=>change(id,{enabled:e.target.checked})}/>Enable {name.toLowerCase()} wheel</label>}<div className="wheel-segment-settings">{settings[id].values.map((value,i)=><label key={i}>Segment {i+1}<input type="number" aria-label={`${name} segment ${i+1} points`} min="0" max="1000" step="1" required disabled={!settings[id].enabled} value={value} onChange={e=>change(id,{values:settings[id].values.map((old,j)=>j===i?(e.target.value===''?'':Number(e.target.value)):old)})}/></label>)}</div></section>)}</fieldset>{error&&<p className="form-error" role="alert">{error}</p>}<button className="button secondary" disabled={busy}>{busy?'Saving…':'Save wheel settings'}</button>{saved&&<p role="status">Wheel settings updated.</p>}</form></section>
}
