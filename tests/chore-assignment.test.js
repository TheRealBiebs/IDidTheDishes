import test from 'node:test'
import assert from 'node:assert/strict'
import {assignmentValue,assignmentFields,choreAssignmentLabel} from '../src/stickers/assignment.js'
import {assignedPending,unassignedAvailable} from '../src/stickers/schedule.js'

test('one assignment choice clears conflicting person/team restrictions',()=>{
 const old={eligible_users:['mia'],assigned_team_id:'red'}
 assert.deepEqual(assignmentFields('person:mia',old,true),{p_team:null,p_eligible:['mia']})
 assert.deepEqual(assignmentFields('team:red',old,true),{p_team:'red',p_eligible:[]})
 assert.deepEqual(assignmentFields('anyone',old,true),{p_team:null,p_eligible:[]})
 assert.equal(assignmentValue({},true),'anyone')
 assert.equal(assignmentValue({eligible_users:['mia']},false),'person:mia')
 assert.equal(assignmentValue({assigned_team_id:'red'},true),'team:red')
 assert.equal(choreAssignmentLabel({},[],[],true),'Assigned to anyone')
})
test('editing old multi-person or combined assignments preserves restrictions until changed',()=>{
 const old={eligible_users:['mia','andrew'],assigned_team_id:'red'}
 assert.equal(assignmentValue(old,true),'legacy')
 assert.deepEqual(assignmentFields('legacy',old,true),{p_team:'red',p_eligible:['mia','andrew']})
})
test('person-assigned chores appear in assigned lists rather than anyone availability',()=>{
 const person={active:true,eligible:true,assigned_to_me:true,eligible_users:['mia'],remaining:1,frequency:'weekly'}
 const anyone={...person,assigned_to_me:false,eligible_users:[]}
 assert.deepEqual(assignedPending([person,anyone],'weekly'),[person])
 assert.deepEqual(unassignedAvailable([person,anyone]),[anyone])
})
