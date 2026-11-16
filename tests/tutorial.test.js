import test from 'node:test'
import assert from 'node:assert/strict'
import {tutorialSteps,tutorialStepIndex,tutorialPlacement} from '../src/tutorial/steps.js'

test('the focused tour has no more than six screens including welcome, for every role and mode',()=>{
 const member=tutorialSteps(),admin=tutorialSteps({admin:true,teams:true,hasChores:true,platformAdmin:true,reward:'poker'})
 assert.deepEqual(admin.map(step=>step.id),['create-chore','invitations','totals','trophies','help'])
 assert.deepEqual(member.map(step=>step.id),['chores','totals','trophies','help'])
 for(const isAdmin of [false,true])for(const platformAdmin of [false,true])for(const reward of ['points','poker','cats','stars']){
  const steps=tutorialSteps({admin:isAdmin,platformAdmin,teams:true,hasChores:true,reward})
  assert.ok(steps.length+1<=6,'Welcome counts toward the six-screen limit')
  assert.ok(steps.every(step=>step.body.split(/\s+/).length<=35),'Each explanation stays focused')
  assert.ok(!steps.some(step=>['notifications','community','workshop'].includes(step.view)))
 }
 assert.equal(tutorialStepIndex(member,'create-chore'),0);assert.equal(tutorialStepIndex(member,'phone-notifications'),0)
 assert.equal(tutorialStepIndex(admin,'invitations'),1)
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
