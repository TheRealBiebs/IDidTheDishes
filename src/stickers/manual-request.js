export const manualRequestKey=(user,chore)=>`chipin-manual-chore:${user}:${chore}`
export function manualRequest(storage,user,chore,createId=()=>crypto.randomUUID()){
 const key=manualRequestKey(user,chore)
 try{const saved=storage.getItem(key);if(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(saved||''))return saved}catch{}
 const id=createId();try{storage.setItem(key,id)}catch{}return id
}
export function clearManualRequest(storage,user,chore){try{storage.removeItem(manualRequestKey(user,chore))}catch{}}
