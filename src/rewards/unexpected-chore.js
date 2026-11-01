export function cleanUnexpectedDescription(value){
  const description=String(value||'').trim()
  if(!description||description.length>500)throw new Error('Describe the chore in 1 to 500 characters.')
  return description
}
export function rouletteRotation(points){
  if(!Number.isInteger(points)||points<0||points>3)throw new Error('The server returned an invalid reward. Retry the same submission.')
  // Labels begin at north, east, south, west. Bring the awarded label to north.
  return 8*360-points*90
}
export const unexpectedRequestKey=(household,user)=>`dishes-unexpected:${user}:${household}`
export function readUnexpectedRequest(storage,key){
  try{const value=JSON.parse(storage.getItem(key));if(value&&/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value.requestId)&&cleanUnexpectedDescription(value.description)===value.description)return value}catch{}
  return null
}
