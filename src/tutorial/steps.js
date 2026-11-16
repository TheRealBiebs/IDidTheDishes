export const TUTORIAL_VERSION=1
const step=(id,view,title,body,targets)=>({id,view,title,body,targets})
export function tutorialSteps({admin=false,teams=false,hasChores=false,platformAdmin=false,reward='points'}={}){
 const rewardText=reward==='poker'?'Your poker table turns chore points into exact-value chip stacks.':reward==='stars'?'Each completed chore adds a star to your household calendar.':reward==='cats'?'Your cat companions show chore points while cat growth and breeding are still being developed.':'Your gemstone tubes fill as chore points are earned.'
 return [
  step('overview','dashboard','Your overview','The tabs keep chores, household settings, updates, and community comparisons close at hand. Let’s look around.', ['[data-tour-nav="dashboard"]']),
  step('rewards','dashboard','Watch your rewards grow',`${rewardText} ${teams?'Teams share totals, while your personal contributions stay visible.':'Members collect points individually; an admin can enable teams later.'}`,['[data-tour="rewards"]']),
  ...(teams?[step('assignments','dashboard','Know what is still assigned','These tiles separate your team’s unfinished chores for today, this week, and this month. Open a tile to see its list.', ['.assigned-grid'])]:[]),
  step('totals','dashboard','Open the numbers','These tiles open the matching chore records. Your daily chores and points share a tile; household and other-member totals show the wider picture.', ['[data-tour="totals"]']),
  step('trophies','dashboard','Collect weekly wins','Weekly winners earn a permanent collectible. Trophy cases gradually fill, crowd, and overflow. They use cups, chip trophies, sleeping cats, or calendar stars to match the household theme.', ['.trophy-gallery .trophy-case','.trophy-gallery']),
  step('activity','dashboard','Celebrate and keep things fair','Open a completed chore to see details and photo proof, leave likes or comments, or refute it with a reason. Its doer is notified and can redo the chore or remove the completion.', ['[data-tour="activity"]']),
  step('chores','chores','Chores and stickers','Scan a configured NFC sticker with your phone to log a chore. Optional quality, starting condition, a comment, and photo proof can be added afterward. Daily, weekly, monthly, and cooldown limits apply.', ['[data-tour-nav="chores"]']),
  ...(admin?[
   step('create-chore','chores','Configure your chores','Add a chore and choose its points, repeat schedule, shared limit, cooldown, and eligible members. You can configure bonuses and penalties for quality and starting condition too.', ['[data-tour="add-chore"]']),
   step('claim-sticker','chores','Claim a preloaded sticker','Scan an unassigned sticker to claim it for this household and select an existing chore or create one. Friends don’t need to write the URL themselves.', ['[data-tour="configure-sticker"]']),
   ...(hasChores?[step('manage-chore','chores','Keep chores and stickers organized','Edit a chore, manage or release its sticker, or delete the chore. Deletion asks for confirmation, preserves completed-chore history, and releases the sticker for reuse.', ['.chore-card-actions'])]:[]),
  ]:[]),
  step('unexpected','chores','Log the unexpected','For a job that has no sticker, describe the unexpected chore here. The reward wheel assigns 0–3 points.', ['.unexpected-chore-entry']),
  step('household','household','Your household','Switch between households here or create or join another one. Joining through an invitation requires a household admin’s approval.', ['[aria-label="Switch household"]']),
  ...(admin?[step('household-settings','household','Choose the household experience','One theme sets both appearance and rewards. Enable teams if you want shared team scores; otherwise members compete individually. Team names, colours, emblems, and membership can be configured.', ['[data-tour="household-settings"]'])]:[]),
  step('members','household','The people pitching in',admin?'Admins can assign teams, add co-admins, or transfer their admin role. Members need an admin’s approval to join; the last admin cannot be removed.':'This list shows the household’s members and admins. Admins manage chores, approve new members, and change household settings.', ['[data-tour="members"]']),
  ...(teams?[step('choose-team','household','Choose your team','Join one of the household’s teams here. Current-week contributions follow your team; your personal chore history stays with you.', ['.affiliation-panel'])]:[]),
  ...(admin?[step('invitations','household','Invite and approve members','Share an invitation link, then review join requests here. You can rotate an invitation link when needed. Only household admins can approve new members.', ['.invite-panel'])]:[]),
  step('hall-of-fame','household','Look back at winning weeks','The Hall of Fame keeps weekly winners and their trophy cases. Open a week, filter by participant, and drill into the chores, comments, and proof from that week.', ['.weekly-result-button','.hall-of-fame']),
  step('updates','notifications','Keep up with the household','Updates collect chore completions, likes, comments, and refutations. Open a notification to return to its chore conversation.', ['[data-tour-nav="notifications"]']),
  step('phone-notifications','notifications','Notifications on your phone','Use this control when you are ready to allow phone notifications. On iPhone, add Chip In to the Home Screen and open it there first. The tour will not request permission for you.', ['.notification-panel']),
  step('community','community','Compare trophy cases privately',admin?'Joining the community is optional. Read and accept the disclosure yourself to share household and team names, weekly wins, and trophy-case appearance. Individual identities and chore records stay private.':'A household admin must join the community first. You can then accept its disclosure to view household trophy cases. Individual identities and chore records stay private.', ['.community-consent','.community-disclosure','.community']),
  step('following','community','Follow the households you know','After joining, follow households and choose Following to focus on them and your own household. Team cases can be expanded, and every household keeps its own themed display.', ['.community-toolbar','.community-consent','.community']),
  ...(platformAdmin?[
   step('workshop','workshop','Your platform-admin workshop','This tab is restricted to platform admins. Create a writing session, then use the Android app to prepare unique sticker URLs in batches. Permanent locking is optional and irreversible.', ['.workshop-panel']),
   step('feedback-inbox','workshop','Read feedback from everyone','This private inbox collects ideas, bug reports, and general feedback. Filter new or reviewed reports, browse older pages, and mark items reviewed.', ['.feedback-inbox']),
  ]:[]),
  step('help','dashboard','Feedback and a tour whenever you need it','Send feedback, ideas, or bug reports here. Only platform admins can read them. Replay this tutorial anytime using the button beside it.', ['[data-tour="help"]']),
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
