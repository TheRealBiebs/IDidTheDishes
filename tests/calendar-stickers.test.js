import test from 'node:test'
import assert from 'node:assert/strict'
import {CALENDAR_STICKERS,calendarSticker} from '../src/rewards/stickers.js'
test('calendar stickers include requested icons and twelve further distinct choices',()=>{
 assert.equal(CALENDAR_STICKERS.length,17)
 assert.equal(new Set(CALENDAR_STICKERS.map(s=>s[0])).size,17)
 for(const id of ['star','rainbow','kitty','dog','heart'])assert.equal(calendarSticker(id)[0],id)
 assert.equal(calendarSticker('old-or-unknown-choice')[0],'star')
})
