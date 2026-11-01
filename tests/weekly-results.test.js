import test from 'node:test'
import assert from 'node:assert/strict'
import { weeklyWinners,weeklyUnit,weekLabel,weeklyWinnerLabel } from '../src/rewards/weekly-results.js'
test('weekly winners include positive tied leaders and exclude empty weeks',()=>{
 const result={team_scores:[{name:'Ember',score:10,winner:true},{name:'Moon',score:10,winner:true},{name:'Other',score:2,winner:false}]}
 assert.equal(weeklyWinners(result).length,2);assert.equal(weeklyWinnerLabel(result),'Ember & Moon');assert.equal(weeklyWinnerLabel({team_scores:[{name:'Zero',score:0,winner:true}]}),'No team winner')
})
test('weekly score units respect independent reward schemes',()=>{assert.equal(weeklyUnit('points'),'points');assert.equal(weeklyUnit('stars'),'stars');assert.equal(weeklyUnit('adventure'),'chores')})
test('closed week labels exclude the next Monday across a daylight saving change',()=>{
 const label=weekLabel('2026-10-26','2026-11-02');assert.ok(label.includes('26'));assert.ok(label.includes('1'));assert.ok(!label.includes('Nov 2,'));assert.ok(!label.includes('Invalid'))
})
