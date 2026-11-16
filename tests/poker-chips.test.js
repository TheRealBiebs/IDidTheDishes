import test from 'node:test'
import assert from 'node:assert/strict'
import {POKER_CHIPS,pokerChips,pokerChipLabel} from '../src/rewards/poker-chips.js'

test('poker denominations match the requested home set and make exact change',()=>{
 assert.deepEqual(POKER_CHIPS.map(c=>[c.name,c.value]),[['white',1],['red',5],['blue',10],['green',25],['black',100]])
 assert.deepEqual(pokerChips(141).map(c=>c.count),[1,1,1,1,1])
 assert.deepEqual(pokerChips(294).map(c=>c.count),[4,1,1,3,2])
 assert.deepEqual(pokerChips(7).map(c=>c.count),[2,1,0,0,0])
 assert.ok(pokerChips(0).every(c=>c.count===0))
 for(let value=0;value<=10000;value++)assert.equal(pokerChips(value).reduce((sum,c)=>sum+c.value*c.count,0),value)
})
test('chip descriptions and large balances stay exact; invalid balances are rejected',()=>{
 assert.match(pokerChipLabel(141),/1 white chip worth 1 each/)
 assert.match(pokerChipLabel(141),/1 black chip worth 100 each/)
 assert.equal(pokerChipLabel(0),'0 points: no chips yet')
 assert.equal(pokerChips(1000001).find(c=>c.value===100).count,10000)
 for(const value of [-1,1.2,NaN,Infinity,Number.MAX_SAFE_INTEGER+1])assert.throws(()=>pokerChips(value),RangeError)
})
