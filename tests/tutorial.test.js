import test from 'node:test'
import assert from 'node:assert/strict'
import {tutorialSteps,tutorialStepIndex,tutorialPlacement} from '../src/tutorial/steps.js'

test('the tour covers every regular tab and only offers role-appropriate controls',()=>{
 const member=tutorialSteps(),admin=tutorialSteps({admin:true,teams:true,hasChores:true,platformAdmin:true,reward:'poker'})
 assert.deepEqual([...new Set(member.map(step=>step.view))],['dashboard','chores','household','notifications','community'])
 for(const id of ['create-chore','claim-sticker','manage-chore','household-settings','invitations','workshop','feedback-inbox','assignments','choose-team'])assert.ok(!member.some(step=>step.id===id))
 for(const id of ['create-chore','claim-sticker','manage-chore','household-settings','invitations','workshop','feedback-inbox','assignments','choose-team'])assert.ok(admin.some(step=>step.id===id))
 assert.equal(new Set(admin.map(step=>step.id)).size,admin.length)
 assert.ok(!tutorialSteps({admin:true}).some(step=>step.id==='manage-chore'))
 assert.match(admin.find(step=>step.id==='rewards').body,/chip stacks/)
 assert.equal(tutorialStepIndex(member,'create-chore'),0);assert.equal(tutorialStepIndex(member,'community'),member.findIndex(step=>step.id==='community'))
})
test('fly-around cards stay inside narrow and short viewports, above or below their highlight',()=>{
 const viewport={width:390,height:844}
 const low=tutorialPlacement({left:10,top:760,right:380,bottom:820,width:370,height:60},viewport,260)
 assert.equal(low.side,'above');assert.ok(low.top>=12&&low.top+260<=844-12)
 const high=tutorialPlacement({left:12,top:30,right:100,bottom:80,width:88,height:50},viewport,260)
 assert.equal(high.side,'below');assert.ok(high.left>=12&&high.left+high.width<=390-12)
 const tiny=tutorialPlacement({left:0,top:50,bottom:200,width:320,height:150},{width:320,height:280},300)
 assert.ok(tiny.left>=12&&tiny.left+tiny.width<=308);assert.ok(tiny.top>=12)
 const welcome=tutorialPlacement(null,viewport,280);assert.equal(welcome.top,(844-280)/2)
})
