import test from 'node:test'
import assert from 'node:assert/strict'
import { runContinuousWriter } from '../src/stickers/continuous-writer.js'

function fixture(){
  const abort=new AbortController(),pending={current:null},reserved=[],writes=[],marked=[];let next=0
  const options={pending,signal:abort.signal,nextToken:()=>`token-${++next}`,reserve:async token=>reserved.push(token),inspect:async()=>({claimed:false}),write:async(token,params)=>{writes.push([token,params.verifyOnly]);return {verified:true,locked:false}},mark:async(token,locked)=>marked.push([token,locked]),onPhase:()=>{},onReady:async()=>abort.abort()}
  return {abort,pending,reserved,writes,marked,options}
}
test('one Start prepares successive unique stickers until Stop, without a preset count',async()=>{
  const f=fixture();f.options.onReady=async()=>{if(f.marked.length===3)f.abort.abort()}
  await runContinuousWriter(f.options)
  assert.deepEqual(f.marked.map(x=>x[0]),['token-1','token-2','token-3']);assert.equal(f.writes.length,3);assert.equal(f.pending.current,null)
})
test('formatting automatically waits for a verification retap using the same URL',async()=>{
  const f=fixture();f.options.write=async(token,params)=>{f.writes.push([token,params.verifyOnly]);return {verified:f.writes.length>1,locked:true}}
  await runContinuousWriter(f.options)
  assert.deepEqual(f.writes,[['token-1',false],['token-1',true]]);assert.deepEqual(f.marked,[['token-1',true]])
})
test('retry after a failed server acknowledgement keeps the verified receipt and never rewrites',async()=>{
  const f=fixture();f.options.mark=async()=>{throw Error('Offline')}
  await assert.rejects(runContinuousWriter(f.options),/Offline/);assert.equal(f.writes.length,1)
  f.options.mark=async(token,locked)=>f.marked.push([token,locked]);await runContinuousWriter(f.options)
  assert.equal(f.writes.length,1);assert.deepEqual(f.reserved,['token-1','token-1']);assert.equal(f.pending.current,null)
})
test('Stop during reservation does not write, and Resume retains the reserved URL',async()=>{
  const f=fixture();f.options.reserve=async token=>{f.reserved.push(token);f.abort.abort()}
  await assert.rejects(runContinuousWriter(f.options),{name:'AbortError'});assert.equal(f.writes.length,0)
  const nextAbort=new AbortController();f.options.signal=nextAbort.signal;f.options.reserve=async token=>f.reserved.push(token);f.options.onReady=async()=>nextAbort.abort()
  await runContinuousWriter(f.options);assert.deepEqual(f.writes,[['token-1',false]])
})
test('a claimed sticker cannot be written or registered by a resumed session',async()=>{
  const f=fixture();f.options.inspect=async()=>({claimed:true})
  await assert.rejects(runContinuousWriter(f.options),/already claimed/);assert.equal(f.writes.length,0);assert.equal(f.marked.length,0)
})
