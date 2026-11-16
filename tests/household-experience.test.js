import test from 'node:test'
import assert from 'node:assert/strict'
import {competitionEntries,experienceTheme,rewardForTheme,teamsEnabled} from '../src/household-experience.js'
import {rewardFor,rewardValue,completionReward} from '../src/rewards/registry.js'

test('themes pair rewards, migrate the clean theme, and use individual mode by default',()=>{
 assert.equal(rewardForTheme('wizard'),'points');assert.equal(rewardForTheme('parents'),'stars')
 assert.equal(rewardForTheme('cats'),'cats');assert.equal(rewardForTheme('poker'),'poker');assert.equal(experienceTheme('clean'),'poker')
 assert.equal(teamsEnabled({}),false);assert.equal(teamsEnabled({teams_enabled:false}),false);assert.equal(teamsEnabled({teams_enabled:true}),true)
 for(const id of ['cats','poker']){assert.equal(rewardValue(rewardFor(id),{points:17,chores:2}),17);assert.equal(completionReward(rewardFor(id),17),'+17 points')}
})
test('individual scoring includes unteamed members; team mode sums member contributions once',()=>{
 const members=[{user_id:'a',display_name:'A',team_id:'red'},{user_id:'b',display_name:'B',team_id:'red'},{user_id:'c',display_name:'C',team_id:null}]
 const scores=[{user_id:'a',points:10},{user_id:'b',points:15},{user_id:'c',points:20}]
 const teams=[{id:'red',name:'Red',active:true,color:'#ff0000'}]
 assert.deepEqual(competitionEntries({household:{teams_enabled:false},members,scores,teams}).map(e=>[e.name,e.points]),[['A',10],['B',15],['C',20]])
 assert.deepEqual(competitionEntries({household:{teams_enabled:true},members,scores,teams}).map(e=>[e.name,e.points,e.count]),[['Red',25,2]])
})
