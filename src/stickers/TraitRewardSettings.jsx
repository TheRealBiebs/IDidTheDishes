import { TRAIT_CHOICES } from './trait-rewards'

export default function TraitRewardSettings({rules={}}) {
  return <fieldset className="trait-reward-settings"><legend>Point adjustments</legend>
    <p className="muted">Add points with a positive number or subtract them with a negative number. Quality and starting condition add together. Unselected traits add zero; the final reward cannot go below zero.</p>
    <div className="trait-reward-grid">{TRAIT_CHOICES.map(([id,label])=><label key={id}>{label}<input name={`adjustment_${id}`} type="number" step="1" min="-1000" max="1000" defaultValue={rules[id]??0} required/></label>)}</div>
  </fieldset>
}
