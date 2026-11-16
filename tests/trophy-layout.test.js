import test from 'node:test'
import assert from 'node:assert/strict'
import {trophyKind,trophyWord,trophyLayout,TROPHY_CAPACITY} from '../src/rewards/trophy-layout.js'

test('each weekly win has one collectible, with separate reward-mode art',()=>{
 assert.equal(trophyKind('points'),'wizard');assert.equal(trophyKind('wizard'),'wizard');assert.equal(trophyKind('poker'),'poker');assert.equal(trophyKind('cats'),'cats');assert.equal(trophyKind('stars'),'stars');assert.equal(trophyKind('parents'),'stars')
 assert.equal(trophyWord('poker'),'chip trophy');assert.equal(trophyWord('cats'),'sleeping cat')
 for(let wins=0;wins<=75;wins++){const layout=trophyLayout(wins);assert.equal(layout.items.length,wins);assert.equal(new Set(layout.items.map(t=>t.id)).size,wins);assert.equal(layout.hidden,0)}
 assert.equal(trophyLayout(0).stage,'empty');assert.equal(trophyLayout(TROPHY_CAPACITY).stage,'filling');assert.equal(trophyLayout(16).stage,'crowded');assert.equal(trophyLayout(40).stage,'overstuffed')
})
test('crowded shelves settle deterministically, push old trophies, and bound large displays',()=>{
 const full=trophyLayout(15),crowded=trophyLayout(16),stuffed=trophyLayout(10000)
 assert.deepEqual(crowded,trophyLayout(16));assert.ok(crowded.items.some(t=>t.id<5&&(t.x!==full.items[t.id].x||t.y!==full.items[t.id].y)))
 for(const item of stuffed.items){assert.ok(Number.isFinite(item.x)&&Number.isFinite(item.y)&&Number.isFinite(item.angle));assert.ok(item.x>=26&&item.x<=274);assert.ok(item.y>=0&&item.y<=228)}
 assert.equal(stuffed.items.length,75);assert.equal(stuffed.hidden,9925);assert.equal(trophyLayout(100,{maxVisible:45}).hidden,55)
 for(const wins of [-1,1.5,Infinity,NaN])assert.throws(()=>trophyLayout(wins),RangeError)
})
