import { automaticCooldown, cooldownDuration } from './cooldown'

export default function CooldownSettings({dailyLimit,mode,onModeChange,minutes,onMinutesChange}) {
  if (!(dailyLimit > 1)) return null
  return <fieldset><legend>Cooldown between completions</legend>
    <label>Cooldown<select aria-label="Cooldown" value={mode} onChange={e=>onModeChange(e.target.value)}>
      <option value="auto">Automatic ({cooldownDuration(automaticCooldown(dailyLimit))})</option>
      <option value="custom">Custom duration</option>
      <option value="off">No cooldown</option>
    </select></label>
    {mode==='custom'&&<label>Wait between completions (minutes)<input type="number" min="1" max="1440" step="1" required value={minutes} onChange={e=>onMinutesChange(e.target.value)}/></label>}
    <small>{mode==='off'?'No extra wait between completions. The daily household limit still applies.':`Everyone in the household shares this wait, including across midnight.${mode==='auto'?' Automatic uses 12 hours divided by the daily limit.':''}`}</small>
  </fieldset>
}
