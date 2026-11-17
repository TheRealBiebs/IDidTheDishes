import test from 'node:test'
import assert from 'node:assert/strict'
import {catProgress,catDaylight} from '../src/rewards/cats/progress.js'
test('a satisfied day counts before care clicks and the cat sleeps only after all three',()=>{
 const c={points:20,target:20,actions:[]};assert.equal(catProgress(c).satisfied,true);assert.equal(catProgress(c).sleeping,false);assert.ok(catProgress(c).activities.every(a=>a.unlocked));
 for(const actions of [['feed'],['feed','play']])assert.equal(catProgress({...c,actions}).sleeping,false)
 assert.equal(catProgress({...c,actions:['feed','play','cuddle']}).sleeping,true)
 assert.equal(catProgress({...c,points:15,actions:['feed','play','cuddle']}).sleeping,false)
})
test('linked chores unlock each activity independently of points and clicks',()=>{
 const activities=[{action:'feed',chore:'Brush your teeth',unlocked:true},{action:'play',chore:'Clean room',unlocked:false},{action:'cuddle',chore:'Read',unlocked:true}];
 const c={care_mode:'chores',points:1000,target:20,activities,actions:[]};let p=catProgress(c);assert.equal(p.value,2);assert.equal(p.maximum,3);assert.equal(p.satisfied,false);assert.deepEqual(p.activities.map(a=>a.unlocked),[true,false,true]);
 p=catProgress({...c,points:0,activities:activities.map(a=>({...a,unlocked:true}))});assert.equal(p.satisfied,true);assert.equal(p.sleeping,false)
 assert.equal(catProgress({...c,activities:activities.map(a=>({...a,unlocked:true})),actions:['feed','play','cuddle']}).sleeping,true)
})
test('cat daylight follows the household clock including day/night boundaries and DST',()=>{
 assert.equal(catDaylight(new Date('2026-11-17T13:59:00Z'),'America/Los_Angeles').night,true)
 assert.equal(catDaylight(new Date('2026-11-17T14:00:00Z'),'America/Los_Angeles').night,false)
 assert.equal(catDaylight(new Date('2026-11-18T01:59:00Z'),'America/Los_Angeles').night,false)
 assert.equal(catDaylight(new Date('2026-11-18T02:00:00Z'),'America/Los_Angeles').night,true)
 assert.equal(catDaylight(new Date('2026-07-17T13:00:00Z'),'America/Los_Angeles').hour,6)
 assert.equal(catDaylight(new Date('2026-11-17T18:00:00Z'),'Asia/Tokyo').night,true)
 assert.equal(catDaylight(new Date('2026-11-17T18:00:00Z'),'America/Los_Angeles').night,false)
})
