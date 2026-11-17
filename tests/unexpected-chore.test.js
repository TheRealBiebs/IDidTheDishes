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

import {wheelSettings,wheelRotation,randomChoresAvailable} from '../src/rewards/wheel-settings.js'
test('configurable wheel outcomes including duplicate values stop at the selected index',()=>{for(const n of [4,17])for(let index=0;index<n;index++)assert.ok(Math.abs(((wheelRotation(index,n)+index*360/n)%360))<.000001);for(const pair of [[-1,4],[4,4],[1,1],[1,21]])assert.throws(()=>wheelRotation(...pair));assert.deepEqual(wheelSettings({}).standard.values,[0,1,2,3]);assert.equal(wheelSettings({}).low.enabled,false);assert.deepEqual(wheelSettings({unexpected_wheels:{high:{enabled:true,values:[4,4,8,12]}}}).high.values,[4,4,8,12])})
test('random chores disappear only for specific-chore cat care and saved requests retain effort',()=>{assert.equal(randomChoresAvailable({reward_scheme:'cats',cat_care_mode:'chores'}),false);for(const reward_scheme of ['points','cats','stars','poker'])assert.equal(randomChoresAvailable({reward_scheme,cat_care_mode:'points'}),true);const pending={requestId:'00000000-0000-4000-8000-000000000001',description:'Unexpected job',wheel:'high'};assert.deepEqual(readUnexpectedRequest({getItem:()=>JSON.stringify(pending)},'x'),pending);assert.equal(readUnexpectedRequest({getItem:()=>JSON.stringify({...pending,wheel:'forged'})},'x'),null)})
