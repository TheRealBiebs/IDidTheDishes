// Keep pending outside the loop so Stop, formatting retaps and network retries
// continue with the same URL. Never mint the next token until this one is ready.
export async function runContinuousWriter({ pending, signal, nextToken, reserve, inspect, write, mark, onPhase, onReady }) {
  const check=()=>{if(signal.aborted)throw new DOMException('Writing stopped','AbortError')}
  while(!signal.aborted){
    if(!pending.current)pending.current={token:nextToken(),verifyOnly:false,receipt:null}
    const item=pending.current
    onPhase('reserving',item.token)
    await reserve(item.token);check()
    const current=await inspect(item.token);check()
    if(!current||current.claimed)throw new Error('This sticker is already claimed or unavailable. Nothing was written.')
    if(!item.receipt){
      onPhase(item.verifyOnly?'retap':'waiting',item.token)
      const receipt=await write(item.token,{verifyOnly:item.verifyOnly,signal})
      if(!receipt.verified){item.verifyOnly=true;check();continue}
      item.receipt=receipt
    }
    // Even if Stop arrives just after physical verification, finish registration.
    // If this fails, retry the server step using the saved receipt, not a rewrite.
    onPhase('saving',item.token)
    await mark(item.token,Boolean(item.receipt.locked))
    const receipt=item.receipt;pending.current=null
    await onReady(item.token,receipt)
  }
}
