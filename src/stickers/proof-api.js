import { supabase } from '../supabase'
import { rpc } from '../api'
import { detailsParams,prepareProof } from './chore-details'

export async function saveCompletionDetails(completion,details,photoCache){
  let path=completion.proof_path||null
  if(details.photo){
    if(photoCache.current?.file!==details.photo){
      const blob=await prepareProof(details.photo)
      path=`${completion.household_id}/${completion.user_id}/${completion.id}/${crypto.randomUUID()}.jpg`
      const {error}=await supabase.storage.from('chore-proof').upload(path,blob,{contentType:'image/jpeg',upsert:false,cacheControl:'300'})
      if(error)throw new Error('Could not upload photo proof: '+error.message)
      photoCache.current={file:details.photo,path}
    }else path=photoCache.current.path
  }
  const updated=await rpc('save_chore_details',{p_completion:completion.id,...detailsParams(details),p_photo_path:path})
  // Once the new proof is attached, old proof is unattached and can be removed.
  if(completion.proof_path&&completion.proof_path!==path)supabase.storage.from('chore-proof').remove([completion.proof_path]).catch(()=>{})
  return updated
}
export async function proofUrl(path){const {data,error}=await supabase.storage.from('chore-proof').createSignedUrl(path,300);if(error)throw error;return data.signedUrl}
