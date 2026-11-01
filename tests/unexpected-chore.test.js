import test from 'node:test'
import assert from 'node:assert/strict'
import { cleanUnexpectedDescription,rouletteRotation,unexpectedRequestKey,readUnexpectedRequest } from '../src/rewards/unexpected-chore.js'
test('unexpected chores require a non-whitespace description within the limit',()=>{
  for(const value of ['',null,' \n\t ', 'a'.repeat(501)])assert.throws(()=>cleanUnexpectedDescription(value))
  assert.equal(cleanUnexpectedDescription('  Removed a mystery stain  '),'Removed a mystery stain')
})
test('roulette stops with each possible server reward under the north pointer, including zero',()=>{
  for(const points of [0,1,2,3])assert.equal((rouletteRotation(points)+points*90)%360,0)
  for(const points of [-1,4,1.5,null,'2'])assert.throws(()=>rouletteRotation(points))
})
test('pending submissions are scoped by account and household and restore the same ID',()=>{
  assert.notEqual(unexpectedRequestKey('h1','u'),unexpectedRequestKey('h2','u'))
  assert.notEqual(unexpectedRequestKey('h','u1'),unexpectedRequestKey('h','u2'))
  const pending={requestId:'00000000-0000-4000-8000-000000000001',description:'Removed a mystery stain'}
  assert.deepEqual(readUnexpectedRequest({getItem:()=>JSON.stringify(pending)},'key'),pending)
  assert.equal(readUnexpectedRequest({getItem:()=>'{broken'},'key'),null)
})
