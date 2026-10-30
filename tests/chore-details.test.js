import test from 'node:test'
import assert from 'node:assert/strict'
import { detailsParams,proofDimensions,QUALITY_CHOICES,CONDITION_CHOICES } from '../src/stickers/chore-details.js'
test('ignored optional fields remain null without choosing a rating for the user',()=>{
  assert.deepEqual(detailsParams(),{p_quality:null,p_condition:null,p_comment:null})
  assert.equal(QUALITY_CHOICES.length,3);assert.equal(CONDITION_CHOICES.length,3)
})
test('quality, starting condition and comment are independent of points',()=>{
  assert.deepEqual(detailsParams({quality:'perfection',starting_condition:'disaster',comment:'  All done  ',points:10000}),{p_quality:'perfection',p_condition:'disaster',p_comment:'All done'})
})
test('photo dimensions retain aspect ratio, cap large camera images and never upscale',()=>{
  assert.deepEqual(proofDimensions(4000,3000),[1600,1200]);assert.deepEqual(proofDimensions(3000,4000),[1200,1600]);assert.deepEqual(proofDimensions(300,200),[300,200])
})
