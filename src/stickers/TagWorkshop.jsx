import { useEffect,useRef,useState } from 'react'
import { rpc } from '../api'
import { isNative } from '../native'
import { issuedStickerUrl,writeIssuedSticker } from './provisioning'

export default function TagWorkshop(){
  const [batches,setBatches]=useState([]),[batch,setBatch]=useState(''),[tags,setTags]=useState([]),[busy,setBusy]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState(''),[lock,setLock]=useState(false),[confirmed,setConfirmed]=useState(false),[retap,setRetap]=useState('')
  const controller=useRef(null)
  useEffect(()=>()=>controller.current?.abort(),[])
  async function load(){setBatches(await rpc('sticker_batches'))}
  useEffect(()=>{load().catch(e=>setError(e.message))},[])
  useEffect(()=>{let active=true;setTags([]);if(batch)rpc('batch_stickers',{p_batch:batch}).then(rows=>{if(active)setTags(rows)}).catch(e=>{if(active)setError(e.message)});return()=>{active=false}},[batch])
  async function create(e){e.preventDefault();setBusy(true);setError('');try{const f=new FormData(e.currentTarget);const id=await rpc('create_sticker_batch',{p_label:f.get('label'),p_count:Number(f.get('count'))});await load();setBatch(id);setMessage('Batch created. Each sticker has its own registered URL.')}catch(e){setError(e.message)}finally{setBusy(false)}}
  async function write(tag,verifyOnly=false){
    setBusy(true);setError('');setMessage('Hold the correct sticker against your phone.');controller.current=new AbortController()
    try{
      const current=(await rpc('batch_stickers',{p_batch:batch})).find(row=>row.token===tag.token)
      if(!current||current.claimed)throw new Error('This sticker is already claimed or unavailable. Nothing was written.')
      const receipt=await writeIssuedSticker(tag.token,{lock,confirmed,verifyOnly,signal:controller.current.signal})
      if(!receipt.verified){setRetap(tag.token);setMessage('URL written. Remove the sticker, then use Verify and retap it before this sticker can be claimed.');return}
      await rpc('mark_sticker_written',{p_token:tag.token,p_locked:Boolean(receipt.locked)})
      setRetap('');setMessage(receipt.locked?'Verified and locked. This sticker is ready to give away.':receipt.lockUnsupported?'Verified and ready. This sticker does not support permanent locking.':'Verified and ready to give away. The URL is still rewritable.')
      setTags(await rpc('batch_stickers',{p_batch:batch}));await load()
    }catch(e){setError(e.message)}finally{setBusy(false);controller.current=null}
  }
  function exportCsv(){const text=['number,url,status',...tags.map((tag,i)=>`${i+1},${issuedStickerUrl(tag.token)},${tag.claimed?'claimed':tag.written_at?'ready':'unwritten'}`)].join('\r\n');const href=URL.createObjectURL(new Blob([text],{type:'text/csv'}));const a=document.createElement('a');a.href=href;a.download='chore-sticker-batch.csv';a.click();URL.revokeObjectURL(href)}
  return <><div className="page-heading"><div><span className="eyebrow">PLATFORM ADMIN ONLY</span><h1>Tag workshop</h1><p>Create registered, unassigned stickers before giving them to friends.</p></div></div><section className="panel workshop-panel"><h2>Create a sticker batch</h2><form onSubmit={create}><label>Batch label<input name="label" maxLength={80} required placeholder="Friends · November"/></label><label>Number of stickers<input name="count" type="number" defaultValue={12} min={1} max={200} required/></label><button className="button" disabled={busy}>Create batch</button></form></section><section className="panel workshop-panel"><label>Choose batch<select value={batch} disabled={busy} onChange={e=>{setBatch(e.target.value);setRetap('')}}><option value="">Select a batch</option>{batches.map(row=><option key={row.id} value={row.id}>{row.label} · {row.written}/{row.count} ready · {row.locked} locked</option>)}</select></label><p>{isNative?'Write one sticker at a time. Existing content with a different URL will not be overwritten.':'Create batches here, then open Tag workshop in the Android app to write and verify the physical stickers.'}</p><label className="check-label"><input type="checkbox" checked={lock} disabled={busy} onChange={e=>{setLock(e.target.checked);setConfirmed(false)}}/>Permanently lock each sticker after verification</label>{lock&&<label className="check-label irreversible-lock"><input type="checkbox" checked={confirmed} disabled={busy} onChange={e=>setConfirmed(e.target.checked)}/>I understand locking is irreversible. Household assignments can still change without rewriting the URL.</label>}{message&&<p role="status" className="form-notice">{message}</p>}{error&&<p role="alert" className="form-error">{error}</p>}{busy&&<button className="text-button" onClick={()=>controller.current?.abort()}>Cancel waiting for sticker</button>}{batch&&<button className="button secondary" disabled={!tags.length||busy} onClick={exportCsv}>Export batch URLs</button>}<ol className="workshop-tags">{tags.map((tag,i)=><li key={tag.token}><div><strong>Sticker {i+1}</strong><small>{tag.claimed?'Claimed':tag.locked_at?'Ready · locked':tag.written_at?'Ready · unlocked':retap===tag.token?'Needs verification':'Unwritten'}</small><code>{tag.token}</code></div><button className="button secondary" disabled={!isNative||busy||tag.claimed||(lock&&!confirmed)} onClick={()=>write(tag,retap===tag.token||Boolean(tag.written_at))}>{retap===tag.token?'Verify sticker':tag.written_at?lock?'Verify & lock':'Verify again':'Write sticker'}</button></li>)}</ol></section></>
}
