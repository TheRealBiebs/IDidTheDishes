import test from 'node:test'
import assert from 'node:assert/strict'
import { webScanRequest } from '../src/pwa.js'

test('a sticker page keeps one request through reloads and changes it for a new visit or account',()=>{
  const history={state:{other:'preserved'},replaceState(next){this.state=next}}
  const first=webScanRequest('sticker-one','member-one',history)
  assert.equal(webScanRequest('sticker-one','member-one',history),first)
  assert.equal(history.state.other,'preserved')
  assert.notEqual(webScanRequest('sticker-one','member-two',history),first)
  assert.notEqual(webScanRequest('sticker-two','member-two',history),first)
  history.state=null
  assert.notEqual(webScanRequest('sticker-one','member-one',history),first)
})
