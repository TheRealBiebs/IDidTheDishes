import { competitionEntries,teamsEnabled,experienceTheme } from './household-experience'
import { useState } from 'react'
import { CastleAtmosphere, GemTube, HouseCrest } from './WizardTheme'

export const THEMES = {
  wizard:{id:'wizard',name:'Wizard Adventure',short:'Wizard Adventure',emoji:'✦',description:'Dark halls, firelight, house banners, and gemstones.',dashboard:'Dashboard',cup:'Team points',teamWord:'team',eyebrow:'WHERE EVERY GOOD DEED BECOMES MAGIC',title:'A little chore.',subtitle:'A little magic. A team to make proud.',intro:'Earn your team points, fill the gemstone vaults, and bring a little enchantment to the everyday.',login:'Sign in',personal:'My points',colors:['#ed5255','#43d3a1','#6b9df5','#f1c34f']},
  cats:{id:'cats',name:'The Cat’s Meow',short:'Cat theme',emoji:'🐾',description:'Raise cats that grow and breed. Cat raising coming later.',dashboard:'The Purrfect Household',cup:'The Purrfect Team Cup',teamWord:'team',eyebrow:'SMALL CHORES. BIG PURR ENERGY.',title:'A little less mess.',subtitle:'A little more room to curl up.',intro:'Round up your favourite humans. Earn your team points and make your shared home a little more purrfect.',login:'Look what the cat brought in.',personal:'Your purrsonal point jar.',colors:['#d478a0','#9c83d6','#4baca1','#d2a34f']},
  poker:{id:'poker',name:'Poker Chips',short:'Poker Chips',emoji:'♠',description:'Earn play money for weekly poker. Gambling coming later.',dashboard:'Dashboard',cup:'Weekly chips',teamWord:'team',eyebrow:'CHIP IN TOGETHER',title:'Every chore counts.',subtitle:'Build your chip stack.',intro:'Pitch in, earn points, and get ready for a weekly game.',login:'Sign in',personal:'My chips',colors:['#c64e52','#468468','#6d86bf','#d2aa50']},
  parents:{id:'parents',name:'Parents & Kids',short:'Parents & Kids',emoji:'☕',description:'Share the family load and collect stars on the calendar.',dashboard:'The Family Huddle',cup:'The Family Team Cup',teamWord:'team',eyebrow:'LESS JUGGLING. MORE TOGETHER.',title:'A thousand little things.',subtitle:'One lovely team.',intro:'From the breakfast dishes to the bedtime tidy-up, every little thing you do deserves to be seen.',login:'A moment for your team.',personal:'Your share of the good stuff.',colors:['#ca7c80','#668ea8','#89a17a','#c69b58']},
}
export const themeFor = id => THEMES[experienceTheme(id)] || THEMES.wizard
// A fresh device has no household identity yet. Keep this outside the selectable
// household themes so it is only an onboarding/login fallback.
export const NEUTRAL_THEME = {
  id:'neutral',name:'Welcome home',emoji:'✓',dashboard:'Your household',cup:'Household teamwork',
  eyebrow:'A LITTLE TEAMWORK GOES A LONG WAY',title:'A shared home.',subtitle:'A little less to do.',
  intro:'Keep track of household chores, celebrate each other’s contributions, and find a rhythm that works for everyone.',
  login:'Welcome home.',personal:'Your contributions',colors:['#42685c','#88a99a','#c5b691'],
}
export const teamFor = (member,teams=[]) => teams.find(t=>t.id===member?.team_id)
export const teamAppearance = team => {
  const color=/^#[0-9a-f]{6}$/i.test(team?.color||'')?team.color:'#b9975c'
  const rgb=color.slice(1).match(/../g).map(v=>parseInt(v,16))
  const light='#'+rgb.map(v=>Math.round(v+(255-v)*.65).toString(16).padStart(2,'0')).join('')
  return {...team,color,light,gem:'Points',symbol:team?.symbol||'star'}
}

export function TeamBadge({team,size=44}) {
  if(!team)return <span className="unsorted-crest" aria-hidden="true">✧</span>
  const t=teamAppearance(team)
  if(['lion','snake','raven','badger'].includes(t.symbol))return <HouseCrest house={t} size={size}/>
  const art={
    cat:<><path d="m16 25-1-14 13 9h8l13-9-1 14q6 6 4 17-4 13-20 13T12 42q-2-10 4-17Z"/><path d="M23 34h1m16 0h1m-12 7 3 3 3-3m-3 3v4m-15-8-10-2m10 7-10 1m40-6 10-2m-10 7 10 1"/></>,
    paw:<><ellipse cx="32" cy="42" rx="15" ry="12"/><ellipse cx="15" cy="28" rx="5" ry="7" transform="rotate(-25 15 28)"/><ellipse cx="27" cy="21" rx="5" ry="7"/><ellipse cx="40" cy="22" rx="5" ry="7"/><ellipse cx="50" cy="30" rx="5" ry="7" transform="rotate(25 50 30)"/></>,
    sponge:<><rect x="12" y="17" width="40" height="34" rx="9"/><path d="M23 29h1m16 0h1m-17 9q8 10 16 0M17 21h1m27 24h1"/></>,
    bubbles:<><circle cx="26" cy="39" r="15"/><circle cx="46" cy="20" r="9"/><circle cx="16" cy="14" r="5"/><path d="M18 34q1-4 5-5m20-12 2-1"/></>,
    heart:<path d="M32 52 13 34C-2 16 22 3 32 20 42 3 66 16 51 34Z"/>,
    coffee:<><path d="M13 26h31v17q0 11-15 11T13 43Zm31 1h4q14 1 7 13-4 5-11 2M22 18q-7-5 0-10m12 10q-7-5 0-10"/></>,
    star:<path d="m32 9 6 15 17 1-13 11 4 17-14-9-14 9 4-17L9 25l17-1Z"/>,
  }
  return <svg className={`team-badge symbol-${t.symbol}`} width={size} height={size} viewBox="0 0 64 64" aria-hidden="true" style={{color:t.color}}><circle cx="32" cy="32" r="30" fill={t.color} fillOpacity=".13" stroke={t.color} strokeOpacity=".5"/><g fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">{art[t.symbol]||art.star}</g></svg>
}

export function ThemeAtmosphere({theme}) {
  if(theme.id==='neutral')return null
  if(theme.id==='wizard')return <CastleAtmosphere/>
  return <div className={`theme-atmosphere atmosphere-${theme.id}`} aria-hidden="true">{theme.id==='cats'?<><span className="decor-cat"><TeamBadge team={{color:'#c99da9',symbol:'cat'}} size={150}/></span>{Array.from({length:8},(_,i)=><span className={`paw-print paw-${i}`} key={i}>✦</span>)}</>:theme.id==='poker'?<><span className="decor-poker">♠ ♣ ♦ ♥</span></>:<><span className="decor-coffee"><TeamBadge team={{color:'#bca58a',symbol:'coffee'}} size={130}/></span><span className="decor-heart"><TeamBadge team={{color:'#d0aaa6',symbol:'heart'}} size={85}/></span></>}</div>
}

export function TeamCup({household,theme,teams=[],scores=[],members=[],currentUser,onChoose,loading}) {
  const enabled=teamsEnabled(household),active=teams.filter(t=>t.active)
  const totals=competitionEntries({household,teams,members,scores,colors:theme.colors}).map(teamAppearance)
  const high=Math.max(0,...totals.map(t=>t.points)),capacity=Math.max(250,Math.ceil(high/250)*250)
  const me=members.find(m=>m.user_id===currentUser),mine=enabled?teamFor(me,teams):totals.find(t=>t.id===currentUser),personal=Number(scores.find(s=>s.user_id===currentUser)?.points||0)
  return <div className="house-cup-layout"><section className="house-cup" aria-labelledby="cup-title"><div className="cup-heading"><h2 id="cup-title">{enabled?'Team points':'Individual points'}</h2><span className="cup-week">This week</span></div>{totals.length?<div className="house-tubes" style={{'--team-count':totals.length}}>{totals.map(t=><article key={t.id} className={`house-column ${high>0&&t.points===high?'leading':''}`} style={{'--house-color':t.color,'--house-light':t.light}}><div className="house-banner"><TeamBadge team={t} size={45}/><span title={t.name}>{t.name}</span></div><GemTube house={t} points={t.points} capacity={capacity}/><div className="house-total"><strong>{loading?'—':t.points.toLocaleString()}</strong><span>POINTS</span></div>{enabled&&<p className="house-scholars">{t.count} members</p>}{high>0&&t.points===high&&<span className="house-leader">✧ In the lead</span>}</article>)}</div>:<p className="empty-inline">{enabled?'Add teams in Household settings.':'No members yet.'}</p>}<div className="cup-footnote">{capacity} points fills a tube · resets every Monday</div></section><section className="personal-vault" style={{'--house-color':mine?.color||theme.colors[0]}}><h2>My points</h2>{mine?<><div className="personal-tube"><GemTube house={teamAppearance(mine)} points={personal} capacity={Math.max(100,Math.ceil(personal/100)*100)} compact/><div><TeamBadge team={mine} size={37}/><span className="personal-number">{loading?'—':personal.toLocaleString()}</span><small>{enabled?`points for ${mine.name}`:'points this week'}</small></div></div>{enabled&&<button className="vault-choice" onClick={onChoose}>Your team: {mine.name}<span>Change →</span></button>}</>:enabled?<button className="button" disabled={!active.length} onClick={onChoose}>Choose your team</button>:<p>{personal} points this week</p>}</section></div>
}

export function ChooseTeam({current,teams,busy,onChoose}) {
  const [selected,setSelected]=useState(current||'')
  return <><p className="sorting-intro">Choose the team you’ll contribute to in this household.</p><div className="sorting-choices" role="radiogroup" aria-label="Household team">{teams.filter(t=>t.active).map(t=><label className={`sorting-choice ${selected===t.id?'selected':''}`} key={t.id} style={{'--house-color':t.color}}><input type="radio" name="household-team" value={t.id} checked={selected===t.id} onChange={()=>setSelected(t.id)}/><TeamBadge team={t} size={42}/><span><strong>{t.name}</strong></span><span className="sorting-dot"/></label>)}</div>{!teams.some(t=>t.active)&&<p>No teams yet. Your household owner can add them in Theme & teams.</p>}<p className="sorting-rule">Your current-week contributions follow your chosen team. Your personal chore history stays the same.</p><button className="button full" disabled={!selected||busy} onClick={()=>onChoose(selected)}>{busy?'Joining your team…':'Join this team'}<span aria-hidden="true">→</span></button></>
}

export function ThemeSettings({household,teams,members,busy,onSaveTheme,onEditTeam,onDeleteTeam,onAddStarters}) {
  const [selected,setSelected]=useState(experienceTheme(household.theme)),[enabled,setEnabled]=useState(teamsEnabled(household))
  return <><p className="settings-description">One theme sets the household’s look and rewards. Changing it keeps chore history and weekly results.</p><div className="theme-choices" role="radiogroup" aria-label="Household theme">{Object.values(THEMES).map(t=><label key={t.id} className={`theme-choice preview-${t.id} ${selected===t.id?'selected':''}`}><input type="radio" name="household-theme" aria-label={t.name} checked={selected===t.id} onChange={()=>setSelected(t.id)}/><span className="theme-emoji">{t.emoji}</span><strong>{t.name}</strong><small>{t.description}</small><span className="theme-swatches">{t.colors.map(c=><i key={c} style={{background:c}}/>)}</span></label>)}</div><label className="check-label"><input type="checkbox" checked={enabled} onChange={e=>setEnabled(e.target.checked)}/>Enable teams</label><p className="settings-description">Off: members compete individually. On: members contribute to teams. Team memberships and assignments are kept while teams are off, but team assignments do not restrict chores.</p><button className="button full" disabled={busy||(selected===household.theme&&enabled===teamsEnabled(household))} onClick={()=>onSaveTheme(selected,enabled)}>{busy?'Saving…':'Save household settings'}</button>{teamsEnabled(household)&&<><div className="team-manager-heading"><h3>Teams</h3><button className="button secondary" disabled={busy||teams.length>=20} onClick={()=>onEditTeam(null)}>+ Add team</button></div><div className="managed-teams">{teams.map(t=><div className="managed-team" key={t.id}><TeamBadge team={t} size={34}/><div><strong>{t.name}</strong><small>{members.filter(m=>m.team_id===t.id).length} members · {t.active?'Active':'Archived'} · {t.color}</small></div><div className="managed-team-actions"><button className="text-button" disabled={busy} onClick={()=>onEditTeam(t)}>Edit<span className="sr-only"> {t.name}</span></button><button className="text-button danger-action" disabled={busy} onClick={()=>onDeleteTeam(t)}>Delete<span className="sr-only"> {t.name}</span></button></div></div>)}</div><div className="starter-teams"><button className="button secondary full" disabled={busy} onClick={onAddStarters}>Add {themeFor(household.theme).short} starter teams</button></div></>}</>
}

export function TeamForm({team,household,busy,onSave,onCancel}) {
  const [name,setName]=useState(team?.name||''),[color,setColor]=useState(team?.color||'#7e9dce'),[symbol,setSymbol]=useState(team?.symbol||'star')
  return <form onSubmit={e=>{e.preventDefault();onSave({p_household:household.id,p_team:team?.id||null,p_name:name,p_color:color,p_symbol:symbol,p_active:new FormData(e.currentTarget).get('active')==='on'})}}><div className="team-live-preview"><TeamBadge team={{name,color,symbol}} size={57}/><strong>{name||'Your new team'}</strong><div className="team-preview-fill"><span style={{background:color}}/></div></div><label>Team name<input value={name} onChange={e=>setName(e.target.value)} required maxLength={40} placeholder="The Midnight Snack Crew"/></label><div className="team-color-row"><label>Reward colour<input type="color" value={color} onChange={e=>setColor(e.target.value)}/></label><label>Hex colour<input value={color} pattern="#[0-9a-fA-F]{6}" onChange={e=>setColor(e.target.value)} required maxLength={7}/></label></div><label>Team emblem<select aria-label="Team emblem" value={symbol} onChange={e=>setSymbol(e.target.value)}>{[['star','Star'],['cat','Cat'],['paw','Paw print'],['sponge','Happy sponge'],['bubbles','Bubbles'],['heart','Heart'],['coffee','Coffee cup'],['lion','Lion crest'],['snake','Snake crest'],['raven','Raven crest'],['badger','Badger crest']].map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label><label className="check-label"><input type="checkbox" name="active" defaultChecked={team?.active??true}/>Team is active</label><p className="sorting-rule">Archiving is available after all members have moved to another team. Editing the name or colour keeps memberships and points.</p><div className="form-actions"><button type="button" className="button secondary" onClick={onCancel}>Back</button><button className="button" disabled={busy}>{busy?'Saving…':'Save team'}</button></div></form>
}
