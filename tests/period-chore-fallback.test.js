import test from 'node:test'
import assert from 'node:assert/strict'
import {chorePeriodView} from '../src/stickers/schedule.js'
test('each empty assigned period shows only available household chores from that period',()=>{
 const available=['daily','weekly','monthly'].map(frequency=>({frequency,chore:frequency,active:true,eligible:true,remaining:1,eligible_users:[]}))
 const restricted={...available[0],assigned_team_id:'another-team',eligible:false}
 const finished={...available[1],remaining:0}
 for(const [index,frequency] of ['daily','weekly','monthly'].entries()){
  const view=chorePeriodView([...available,restricted,finished],frequency)
  assert.equal(view.assigned,false)
  assert.match(view.title,/^Available /)
  assert.deepEqual(view.chores,[available[index]])
 }
 const mine={...available[0],assigned_team_id:'mine',assigned_to_me:true}
 assert.deepEqual(chorePeriodView([...available,mine],'daily').chores,[mine])
 assert.equal(chorePeriodView([mine],'daily').title,'Assigned today')
 assert.equal(chorePeriodView([],'weekly').title,'Available this week')
})
