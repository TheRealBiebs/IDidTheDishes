import test from 'node:test'
import assert from 'node:assert/strict'
import {cascadeStones,visibleWinners} from '../src/rewards/gems/cascade-layout.js'
test('gem cascades have stable staggered paths and a bounded rendering cost',()=>{
 for(const points of [1,10,100,10000000])for(const recap of [false,true]){
  const stones=cascadeStones(points,{recap})
  assert.ok(stones.length>=10&&stones.length<=32)
  assert.deepEqual(stones,cascadeStones(points,{recap}))
  assert.ok(stones.every(s=>Object.values(s).every(Number.isFinite)))
  assert.ok(stones.every((s,i)=>!i||s.delay>stones[i-1].delay))
 }
 for(const invalid of [0,-1,NaN,Infinity])assert.deepEqual(cascadeStones(invalid),[])
 assert.equal(visibleWinners(Array.from({length:20},(_,i)=>i)).length,3)
})
