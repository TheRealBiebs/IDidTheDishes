import { useState } from 'react'
import { REWARD_SCHEMES, rewardFor } from './registry'

export function RewardSummary({ household, owner, onConfigure }) {
  const scheme = rewardFor(household?.reward_scheme)
  return <section className="panel household-style-panel reward-summary"><div><span className="reward-symbol" aria-hidden="true">{scheme.icon}</span><div><span className="eyebrow">YOUR HOUSEHOLD’S REWARD SYSTEM</span><h2>{scheme.name}{scheme.id === 'adventure' && <small className="reward-preview-label">Preview</small>}</h2><p>{scheme.description}</p></div></div>{owner && <button className="button secondary" onClick={onConfigure}>Reward system</button>}</section>
}
export function RewardSettings({ household, busy, onSave }) {
  const [selected, setSelected] = useState(household.reward_scheme || 'points')
  return <><p className="settings-description">Choose how this household celebrates completed chores. Your theme, teams, and chore history stay with you when you switch.</p><div className="reward-choices" role="radiogroup" aria-label="Household reward system">{Object.values(REWARD_SCHEMES).map(scheme => <label key={scheme.id} className={`reward-choice reward-${scheme.id} ${selected === scheme.id ? 'selected' : ''}`}><input type="radio" name="household-reward" checked={selected === scheme.id} onChange={() => setSelected(scheme.id)}/><span className="reward-choice-top"><span className="reward-symbol" aria-hidden="true">{scheme.icon}</span><small>{scheme.status}</small></span><strong>{scheme.name}</strong><span>{scheme.description}</span><RewardSwatch id={scheme.id}/></label>)}</div><div className="reward-rule" role="note"><strong>How it works</strong><p>{rewardFor(selected).rule}</p></div><p className="settings-description">Changing systems never deletes completed chores. Calendar stars reflect your full chore history. Returning to gemstone points restores the point view.</p><button className="button full" disabled={busy || selected === (household.reward_scheme || 'points')} onClick={() => onSave(selected)}>{busy ? 'Saving…' : 'Save reward system'}</button></>
}
function RewardSwatch({ id }) {
  return <span className={`reward-swatch swatch-${id}`} aria-hidden="true">{id === 'points' ? <>{[40, 70, 55, 85].map((n, i) => <i key={i} style={{ '--fill': `${n}%` }}/>)}</> : id === 'stars' ? <>{['★', '', '★', '★', '', '★', ''].map((star, i) => <i key={i}>{star}</i>)}</> : <><i>♜</i><i>⚔</i><i>♢</i></>}</span>
}
