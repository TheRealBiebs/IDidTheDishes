import { useState } from 'react'
import { STARTER_CHORES } from './starter-chores'

export default function StarterPicker({ name='starter_chores', onChange, disabled=false }) {
  const [selected,setSelected]=useState([])
  const change=keys=>{setSelected(keys);onChange?.(keys)}
  return <fieldset className="starter-picker" disabled={disabled}><legend>Your starter chores</legend><p>Choose any of these 12 chores. Configure them now, then scan preloaded stickers to assign them.</p><div className="starter-picker-actions"><button type="button" className="text-button" onClick={()=>change(STARTER_CHORES.map(c=>c.key))}>Select all 12</button><button type="button" className="text-button" onClick={()=>change([])}>Clear selection</button><small>{selected.length} selected</small></div><div className="starter-options">{STARTER_CHORES.map(chore=><label className="check-label" key={chore.key}><input type="checkbox" name={name} value={chore.key} checked={selected.includes(chore.key)} onChange={e=>change(e.target.checked?[...selected,chore.key]:selected.filter(k=>k!==chore.key))}/><span>{chore.name}</span></label>)}</div></fieldset>
}
