export const TUTORIAL_VERSION=1
const step=(id,view,title,body,targets)=>({id,view,title,body,targets})
// Five focused tips plus the welcome screen: at most six screens in total.
export function tutorialSteps({admin=false}={}){
 return [
  admin
   ?step('create-chore','chores','Create and configure chores','Add a chore, set its points, schedule and eligible members, then scan a preloaded sticker to assign it. Use Edit chore to change it later.', ['[data-tour="chore-setup"]','[data-tour="add-chore"]'])
   :step('chores','chores','Log your chores','Tap a configured NFC sticker to log a chore. Your admin sets its points, schedule and eligibility. You can add optional details afterward.', ['[data-tour-nav="chores"]']),
  ...(admin?[step('invitations','household','Add household members','Get an invitation link and send it to your household. Anyone with the link is added automatically after signing in. Replace the link to stop using the old one.', ['.invite-panel'])]:[]),
  step('totals','dashboard','Today’s scores','See today’s completed chores and points here. Tap a number to see the chores behind it.', ['[data-tour="totals"] .stat-card:first-child','[data-tour="totals"]']),
  step('trophies','dashboard','Win weekly trophies','Win the week to earn a collectible. Your themed trophy case keeps every weekly win and slowly fills up over time.', ['.trophy-gallery .trophy-case','.trophy-gallery']),
  step('help','dashboard','Send feedback or ideas','Send ideas, feedback or bug reports here. Only platform admins can read them. Replay this short tour using the button beside it.', ['[data-tour="help"]']),
 ]
}
export function tutorialStepIndex(steps,id){const index=steps.findIndex(step=>step.id===id);return index<0?0:index}

export function tutorialPlacement(rect,viewport,panelHeight=260){
 const margin=12,width=Math.max(1,Math.min(360,viewport.width-margin*2)),height=Math.min(panelHeight,viewport.height-margin*2)
 const bound=(n,min,max)=>Math.max(min,Math.min(max,n))
 const left=bound(rect?rect.left+rect.width/2-width/2:(viewport.width-width)/2,margin,Math.max(margin,viewport.width-width-margin))
 let top,side='floating'
 if(rect&&viewport.height-rect.bottom>=height+28){top=rect.bottom+16;side='below'}
 else if(rect&&rect.top>=height+28){top=rect.top-height-16;side='above'}
 else top=rect?viewport.height-height-margin:(viewport.height-height)/2
 top=bound(top,margin,Math.max(margin,viewport.height-height-margin))
 return {left,top,width,side,arrow:rect?bound(rect.left+rect.width/2-left,22,width-22):width/2}
}
