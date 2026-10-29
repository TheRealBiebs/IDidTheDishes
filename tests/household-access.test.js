import test from 'node:test'
import assert from 'node:assert/strict'
import { isHouseholdAdmin, adminCount, canRemoveAdmin } from '../src/household-access.js'

test('creator and additional admins share the same capabilities', () => {
  const members = [{ user_id: 'a', role: 'owner' }, { user_id: 'b', role: 'owner' }, { user_id: 'c', role: 'member' }]
  assert.ok(isHouseholdAdmin(members[0])); assert.ok(isHouseholdAdmin(members[1]))
  assert.equal(isHouseholdAdmin(members[2]), false)
  assert.equal(adminCount(members), 2)
  assert.ok(canRemoveAdmin(members[0], members))
})
test('last-admin action is disabled and absent/loading membership cannot grant admin UI', () => {
  const only = { user_id: 'a', role: 'owner' }, members = [only, { user_id: 'b', role: 'member' }]
  assert.equal(canRemoveAdmin(only, members), false)
  assert.equal(isHouseholdAdmin(undefined), false)
  assert.equal(isHouseholdAdmin({ role: 'member' }), false)
  assert.equal(adminCount([]), 0)
})
