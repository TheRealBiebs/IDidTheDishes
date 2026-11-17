import test from 'node:test'
import assert from 'node:assert/strict'
import {manualRequest,clearManualRequest} from '../src/stickers/manual-request.js'
test('manual chore retries reuse a scoped request until a confirmed completion clears it',()=>{
 const values=new Map(),storage={getItem:key=>values.get(key),setItem:(key,value)=>values.set(key,value),removeItem:key=>values.delete(key)}
 const first='00000000-0000-4000-8000-000000000001',second='00000000-0000-4000-8000-000000000002'
 assert.equal(manualRequest(storage,'user','chore',()=>first),first)
 assert.equal(manualRequest(storage,'user','chore',()=>second),first)
 assert.equal(manualRequest(storage,'other','chore',()=>second),second)
 clearManualRequest(storage,'user','chore')
 assert.equal(manualRequest(storage,'user','chore',()=>second),second)
})
