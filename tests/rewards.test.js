import test from 'node:test'
import assert from 'node:assert/strict'
import { rewardFor, completionReward, rankedScores, monthCells, shiftMonth, starCount } from '../src/rewards/registry.js'

test('star rankings and rewards count chores rather than weighted point values', () => {
  const scores = [{ user_id: 'one', chores: 2, points: 100 }, { user_id: 'two', chores: 5, points: 5 }]
  assert.equal(rankedScores(rewardFor('points'), scores)[0].user_id, 'one')
  assert.equal(rankedScores(rewardFor('stars'), scores)[0].user_id, 'two')
  assert.equal(completionReward(rewardFor('stars'), 999), '+1 gold star')
  assert.equal(completionReward(rewardFor('adventure'), 999), 'Chore recorded')
  assert.equal(scores[0].user_id, 'one', 'sorting must not mutate the shared dashboard response')
})
test('calendar layout uses Monday columns, leap days, and dates independent of device time zone', () => {
  const feb = monthCells('2024-02')
  assert.deepEqual(feb.slice(0, 4), [null, null, null, '2024-02-01'])
  assert.equal(feb.at(-1), '2024-02-29')
  assert.equal(monthCells('2025-02').at(-1), '2025-02-28')
  assert.equal(monthCells('2026-06')[0], '2026-06-01')
  assert.equal(shiftMonth('2026-01', -1), '2025-12')
  assert.equal(shiftMonth('2026-12', 1), '2027-01')
})
test('calendar sums aggregate counts and safely defaults old households to gemstone points', () => {
  assert.equal(starCount([{ stars: '3001' }, { stars: 2 }]), 3003)
  assert.equal(rewardFor(undefined).id, 'points')
  assert.equal(rewardFor('unknown-future-system').id, 'points')
  assert.equal(rewardFor('adventure').status, 'Preview')
})
