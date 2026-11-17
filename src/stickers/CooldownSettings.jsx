import {useState} from 'react'
import { automaticCooldown, cooldownDuration } from './cooldown'

export default function CooldownSettings({dailyLimit,mode,onModeChange,minutes,onMinutesChange}) {
  const [unit,setUnit]=useState(()=>minutes>=1440&&minutes%1440===0?1440:minutes>=60&&minutes%60===0?60:1)
  const automatic=automaticCooldown(dailyLimit)
  return <fieldset><legend>Cooldown between completions</legend>
    <label>Cooldown<select aria-label="Cooldown" value={mode} onChange={e=>onModeChange(e.target.value)}>
      <option value="auto">Automatic ({automatic?cooldownDuration(automatic):'no cooldown'})</option>
      <option value="custom">Custom duration</option>
      <option value="off">No cooldown</option>
    </select></label>
    {mode==='custom'&&<div className="form-row"><label>Wait between completions<input aria-label="Wait between completions" type="number" min="1" max={44640/unit} step="1" required value={minutes===''?'':Number(minutes)/unit} onChange={e=>onMinutesChange(e.target.value===''?'':Number(e.target.value)*unit)}/></label><label>Cooldown unit<select aria-label="Cooldown unit" value={unit} onChange={e=>{const next=Number(e.target.value);onMinutesChange(minutes===''?'':Math.min(44640,Math.max(1,Math.round(Number(minutes)/unit*next))));setUnit(next)}}><option value="1">Minutes</option><option value="60">Hours</option><option value="1440">Days</option></select></label></div>}
    <small>{mode==='off'?'No extra wait. The household limit for the selected repeat schedule still applies.':`Everyone shares this wait, including across day, week and month resets. Custom durations can be up to 31 days.${mode==='auto'?' Automatic uses 12 hours divided by the completion limit, with no automatic wait when the limit is one.':''}`}</small>
  </fieldset>
}
