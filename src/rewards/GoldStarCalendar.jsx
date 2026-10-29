import { useEffect, useRef, useState } from 'react'
import { rpc, localDate } from '../api'
import { monthCells, shiftMonth, starCount } from './registry'

const dateLabel = day => new Date(`${day}T12:00:00Z`).toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })
export default function GoldStarCalendar({ household, members, currentUser, revision }) {
  const today = localDate(household.timezone)
  const currentMonth = today.slice(0, 7)
  const [month, setMonth] = useState(currentMonth), [person, setPerson] = useState(currentUser)
  const [rows, setRows] = useState([]), [selected, setSelected] = useState(today), [loading, setLoading] = useState(true), [error, setError] = useState(''), [retry, setRetry] = useState(0)
  const loadedResource = useRef('')
  useEffect(() => {
    let active = true
    const resource = `${household.id}:${month}`
    if (loadedResource.current !== resource) { setLoading(true); setRows([]) }
    setError('')
    rpc('reward_calendar', { p_household: household.id, p_month: `${month}-01` }).then(data => {
      if (active) { loadedResource.current = resource; setRows(data || []) }
    }).catch(e => { if (active) setError(e.message || 'Could not load the calendar.') }).finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [household.id, month, revision, retry])
  const visible = person === 'all' ? rows : rows.filter(row => row.user_id === person)
  const daily = new Map()
  for (const row of visible) daily.set(row.day, (daily.get(row.day) || 0) + Number(row.stars))
  const detail = visible.filter(row => row.day === selected)
  const title = new Date(`${month}-01T12:00:00Z`).toLocaleDateString(undefined, { month: 'long', year: 'numeric', timeZone: 'UTC' })
  function changeMonth(value) { setMonth(value); setSelected(value === currentMonth ? today : `${value}-01`) }
  return <section className="panel star-rewards" aria-labelledby="star-calendar-title"><div className="reward-panel-heading"><div><span className="eyebrow">LITTLE DEEDS, GOLDEN DAYS</span><h2 id="star-calendar-title">Your gold-star calendar</h2><p>One star for every chore. A whole month of showing up.</p></div><div className="star-month-total"><span aria-hidden="true">★</span><strong>{loading ? '—' : starCount(visible)}</strong><small>stars this month</small></div></div><div className="calendar-toolbar"><div className="calendar-month"><button className="icon-button" aria-label="Previous month" onClick={() => changeMonth(shiftMonth(month, -1))}>‹</button><h3 aria-live="polite">{title}</h3><button className="icon-button" aria-label="Next month" disabled={month >= currentMonth} onClick={() => changeMonth(shiftMonth(month, 1))}>›</button></div><label>Whose stars?<select value={person} onChange={e => setPerson(e.target.value)}><option value="all">Everyone in the household</option>{members.map(member => <option key={member.user_id} value={member.user_id}>{member.display_name}{member.user_id === currentUser ? ' (you)' : ''}</option>)}</select></label></div>{error ? <div className="calendar-error" role="alert"><p>{error}</p><button className="button secondary" onClick={() => setRetry(n => n + 1)}>Try calendar again</button></div> : <div className="calendar-layout"><div className="calendar-board" aria-busy={loading}><div className="calendar-weekdays" aria-hidden="true">{['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day, i) => <span key={i}>{day}</span>)}</div><div className="calendar-days" aria-label={`${title} gold stars`}>{monthCells(month).map((day, i) => day ? <button key={day} className={`calendar-day ${day === selected ? 'selected' : ''} ${day === today ? 'today' : ''} ${daily.get(day) ? 'has-stars' : ''}`} aria-label={`${dateLabel(day)}: ${loading ? 'loading' : daily.get(day) || 0} gold stars`} aria-pressed={day === selected} onClick={() => setSelected(day)}><span className="day-number">{Number(day.slice(-2))}</span><span className="day-stars" aria-hidden="true">{Array.from({ length: Math.min(daily.get(day) || 0, 3) }, (_, n) => <i key={n}>★</i>)}{(daily.get(day) || 0) > 3 && <small>+{daily.get(day) - 3}</small>}</span></button> : <span key={`blank-${i}`} className="calendar-blank"/>)}</div></div><aside className="star-day-detail" aria-live="polite"><span className="eyebrow">THE LITTLE WINS</span><h3>{dateLabel(selected)}</h3>{loading ? <p>Gathering your gold stars…</p> : detail.length ? <ul>{detail.map(row => <li key={`${row.user_id}:${row.tag_id}:${row.chore}`}><span className="detail-star" aria-hidden="true">★</span><div><strong>{row.chore}</strong><small>{members.find(member => member.user_id === row.user_id)?.display_name || 'Household member'}</small></div><b>{row.stars}</b><span className="sr-only">gold star{Number(row.stars) === 1 ? '' : 's'}</span></li>)}</ul> : <p>No stars on this day yet. Each chore you log adds one here.</p>}<p className="calendar-note">Dates follow your household’s {household.timezone} time zone. Stars include chores logged before this system was selected.</p></aside></div>}</section>
}
