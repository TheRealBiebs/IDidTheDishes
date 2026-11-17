import {useEffect,useState} from 'react'
import {rpc} from '../../api'
export default function CatSettings({household,onSaved}){
 const [target,setTarget]=useState(household.cat_daily_target||20),[busy,setBusy]=useState(false),[error,setError]=useState(''),[saved,setSaved]=useState(false)
 useEffect(()=>setTarget(household.cat_daily_target||20),[household.cat_daily_target])
 return <section className="cat-target-settings"><h3>Cat care target</h3><form onSubmit={async e=>{e.preventDefault();setBusy(true);setError('');setSaved(false);try{await rpc('set_cat_daily_target',{p_household:household.id,p_target:Number(target)});await onSaved?.();setSaved(true)}catch(e){setError(e.message)}finally{setBusy(false)}}}><label>Daily points per person<input aria-label="Daily points per person" type="number" value={target} onChange={e=>{setTarget(e.target.value);setSaved(false)}} min="1" max="10000" step="1" required/></label><p>Applies immediately today and to upcoming days. Past days keep their targets. Feed at 25%, play at 50%, cuddle at 75%, and sleep at 100%.</p><button className="button secondary" disabled={busy}>{busy?'Saving…':'Save cat target'}</button>{saved&&<p role="status">Cat target updated.</p>}{error&&<p role="alert" className="form-error">{error}</p>}</form></section>
}
