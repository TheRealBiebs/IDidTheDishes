import test from 'node:test'
import assert from 'node:assert/strict'
import {cooldownMinutes} from '../src/stickers/cooldown.js'

test('only daily repeat schedules display completion cooldowns',()=>{
 assert.equal(cooldownMinutes({frequency:'daily',daily_limit:3,cooldown_minutes:null}),240)
 assert.equal(cooldownMinutes({frequency:'weekly',daily_limit:3,cooldown_minutes:null}),0)
 assert.equal(cooldownMinutes({frequency:'monthly',daily_limit:3,cooldown_minutes:120}),0)
})
