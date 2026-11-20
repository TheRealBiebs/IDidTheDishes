import test from 'node:test'
import assert from 'node:assert/strict'
import { scanAction } from '../src/stickers/routing.js'
import { STARTER_CHORES } from '../src/stickers/starter-chores.js'

test('signed-in household members log immediately in browsers and installed apps; guests do not',()=>{
 const own={status:'assigned',member:true,admin:true}
 assert.equal(scanAction(own,{signedIn:false,installed:true}),'public')
 assert.equal(scanAction(own,{signedIn:true,installed:false}),'complete')
 assert.equal(scanAction(own,{signedIn:true,installed:true}),'complete')
 assert.equal(scanAction(own,{signedIn:true,installed:true,configuring:true}),'configure')
})
test('new issued tags require an admin; foreign ownership never becomes completion',()=>{
 assert.equal(scanAction({status:'available'},{signedIn:true,canClaim:true,configuring:true}),'claim')
 assert.equal(scanAction({status:'available'},{signedIn:true,canClaim:false}),'unassigned')
 assert.equal(scanAction({status:'available'},{signedIn:true,canClaim:true}),'claim')
 assert.equal(scanAction({status:'assigned',member:true,admin:false},{signedIn:true,configuring:true}),'complete')
 assert.equal(scanAction({status:'preparing'},{signedIn:true,canClaim:true}),'preparing')
 assert.equal(scanAction({status:'assigned',member:false},{signedIn:true,installed:true}),'foreign')
 assert.equal(scanAction({status:'invalid'},{signedIn:true,installed:true}),'invalid')
})
test('the starter catalog has twelve stable, distinct valid chores',()=>{
 assert.equal(STARTER_CHORES.length,12)
 assert.equal(new Set(STARTER_CHORES.map(c=>c.key)).size,12)
 assert.ok(STARTER_CHORES.every(c=>c.name.length<=100&&c.points>=1&&c.points<=1000&&c.limit>=1&&c.limit<=100))
})

test('only logged-out scans of valid unclaimed chips open the marketing welcome page',()=>{assert.equal(scanAction({status:'available'},{signedIn:false}),'welcome');assert.equal(scanAction({status:'available'},{signedIn:true}),'unassigned');assert.equal(scanAction({status:'assigned',member:false},{signedIn:false}),'public');assert.equal(scanAction({status:'preparing'},{signedIn:false}),'public');assert.equal(scanAction({status:'invalid'},{signedIn:false}),'invalid');assert.equal(scanAction(null,{signedIn:false}),'invalid')})
