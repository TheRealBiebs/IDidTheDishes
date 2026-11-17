import test from 'node:test'
import assert from 'node:assert/strict'
import {cooldownMinutes,cooldownDuration} from '../src/stickers/cooldown.js'

test('all repeat frequencies honor automatic, custom and disabled cooldowns',()=>{
 for(const frequency of ['daily','weekly','monthly']){
  assert.equal(cooldownMinutes({frequency,daily_limit:3,cooldown_minutes:null}),240)
  assert.equal(cooldownMinutes({frequency,daily_limit:1,cooldown_minutes:2880}),2880)
  assert.equal(cooldownMinutes({frequency,daily_limit:3,cooldown_minutes:0}),0)
  assert.equal(cooldownMinutes({frequency,daily_limit:1,cooldown_minutes:null}),0)
 }
 assert.equal(cooldownDuration(2880),'2d')
 assert.equal(cooldownDuration(1501),'1d 1h 1m')
})
