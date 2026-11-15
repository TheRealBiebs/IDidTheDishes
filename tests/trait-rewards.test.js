import test from 'node:test'
import assert from 'node:assert/strict'
import { traitReward } from '../src/stickers/trait-rewards.js'

test('reward preview combines independently selected traits and recalculates from the saved base',()=>{
 const rules={perfection:5,disaster:8,shabbily:-9,maintenance:-4}
 assert.equal(traitReward(10,rules,null,null),10)
 assert.equal(traitReward(10,rules,'perfection','disaster'),23)
 assert.equal(traitReward(10,rules,'shabbily','maintenance'),0)
 assert.equal(traitReward(10,rules,'perfection',null),15)
 assert.equal(traitReward(10,{},'perfection','disaster'),10)
})
