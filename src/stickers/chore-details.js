export const QUALITY_CHOICES=[['shabbily','Shabbily'],['good_enough','Good enough'],['perfection','To perfection']]
export const CONDITION_CHOICES=[['maintenance','Quick maintenance'],['standard','Standard'],['disaster','A disaster area']]
export const detailsParams = (details={}) => ({p_quality:details.quality||null,p_condition:details.starting_condition||null,p_comment:details.comment?.trim()||null})
export function proofDimensions(width,height,max=1600){const scale=Math.min(1,max/Math.max(width,height));return [Math.max(1,Math.round(width*scale)),Math.max(1,Math.round(height*scale))]}

// Re-encode camera/library images to a bounded JPEG, without original EXIF.
export async function prepareProof(file){
  if(!file?.type.startsWith('image/'))throw new Error('Choose an image for photo proof.')
  if(file.size>20*1024*1024)throw new Error('Choose a photo smaller than 20 MB.')
  const url=URL.createObjectURL(file),img=new Image()
  try{
    img.src=url
    try{await img.decode()}catch{throw new Error('This photo format could not be opened. Choose a JPEG, PNG, or WebP photo.')}
    const [width,height]=proofDimensions(img.naturalWidth,img.naturalHeight)
    const canvas=document.createElement('canvas');canvas.width=width;canvas.height=height
    const context=canvas.getContext('2d');if(!context)throw new Error('Photo processing is unavailable on this device.')
    context.fillStyle='#fff';context.fillRect(0,0,width,height);context.drawImage(img,0,0,width,height)
    const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',0.82))
    if(!blob||blob.size>3*1024*1024)throw new Error('Choose a smaller photo; processed proof must be under 3 MB.')
    return blob
  }finally{URL.revokeObjectURL(url)}
}
