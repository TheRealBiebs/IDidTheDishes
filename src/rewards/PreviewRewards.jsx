import { competitionEntries } from '../household-experience'

export default function PreviewRewards({household,theme,teams,members,scores,loading}){
  const cats=household.theme==='cats'
  const entries=competitionEntries({household,teams,members,scores,colors:theme.colors})
  return <section className="panel preview-rewards"><h2>{cats?'Cat companions':'Poker chips'}</h2><p>{cats?'Cat growth and breeding are coming later. For now, chores earn points.':'Chore points will become play money for a weekly poker game. Gambling is coming later; no money or bets are active.'}</p><div className="preview-reward-entries">{entries.map(entry=><article key={entry.id} style={{'--reward-color':entry.color}}><span className={cats?'preview-cat':'preview-chip'} aria-hidden="true">{cats?'🐈':'♠'}</span><strong>{entry.name}</strong><span>{loading?'—':entry.points} points this week</span></article>)}</div></section>
}
