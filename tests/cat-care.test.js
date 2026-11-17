import test from 'node:test'
import assert from 'node:assert/strict'
import {CAT_TYPES,catType,careUnlocked} from '../src/rewards/cats/catalog.js'
test('cat catalog contains dozens of distinct persistent appearances',()=>{
 assert.ok(CAT_TYPES.length>=24)
 assert.equal(new Set(CAT_TYPES.map(t=>t[0])).size,CAT_TYPES.length)
 assert.equal(catType(0)[0],'Siamese')
 assert.equal(catType(1)[0],'Sphynx')
 assert.equal(catType(2)[0],'Calico')
})
test('care actions unlock at exact quarters, including fractional point targets',()=>{
 assert.deepEqual(careUnlocked(4,20),[false,false,false,false])
 assert.deepEqual(careUnlocked(5,20),[true,false,false,false])
 assert.deepEqual(careUnlocked(10,20),[true,true,false,false])
 assert.deepEqual(careUnlocked(15,20),[true,true,true,false])
 assert.deepEqual(careUnlocked(20,20),[true,true,true,true])
 assert.deepEqual(careUnlocked(100,20),[true,true,true,true])
 assert.deepEqual(careUnlocked(1,7),[false,false,false,false])
 assert.deepEqual(careUnlocked(2,7),[true,false,false,false])
})
