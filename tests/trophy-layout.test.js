import test from 'node:test'
import assert from 'node:assert/strict'
import {trophyKind,trophyWord,trophyLayout,cabinetLayout,chipPileParts,TROPHY_CAPACITY} from '../src/rewards/trophy-layout.js'
const overlaps=(a,b)=>Math.abs(a.x-b.x)<(a.w+b.w)/2-.01
function verifySupport(layout){for(const t of layout.items){const floor=layout.shelves[t.shelf];const restsOnFloor=Math.abs(t.y-floor)<.001;const supported=layout.items.some(p=>p!==t&&p.shelf===t.shelf&&overlaps(t,p)&&Math.abs(t.y-(p.y-p.h))<.001);assert.ok(restsOnFloor||supported,'Unsupported item '+t.key);assert.ok(t.y-t.h>=0&&t.y<=layout.height);for(const p of layout.items)if(p!==t&&overlaps(t,p)){assert.ok(t.y<=p.y-p.h+.01||p.y<=t.y-t.h+.01,'Intersecting items')}}}
test('cup and cat rewards have distinct art; casino awards are stacks only',()=>{
 assert.equal(trophyKind('points'),'wizard');assert.equal(trophyKind('poker'),'poker');assert.equal(trophyKind('cats'),'cats');assert.equal(trophyKind('stars'),'stars');assert.equal(trophyWord('poker'),'chip stack')
 assert.equal(cabinetLayout([{id:'obsolete',mode:'poker'}]).items.length,0)
 for(let n=0;n<=75;n++){const l=trophyLayout(n);assert.equal(l.items.length,n);assert.equal(l.hidden,0);verifySupport(l)}
 assert.equal(trophyLayout(0).stage,'empty');assert.equal(trophyLayout(TROPHY_CAPACITY).stage,'filling');assert.equal(trophyLayout(16).stage,'crowded');assert.equal(trophyLayout(40).stage,'overstuffed')
})
test('groups stay on contiguous shelves and every item rests on a shelf or another item',()=>{
 const items=Array.from({length:40},(_,i)=>({id:'t'+i,mode:i%2?'cats':'points'}));items.push({id:'bank',mode:'poker',kind:'poker_bank',bank_total:50000})
 const l=cabinetLayout(items);assert.deepEqual(l,cabinetLayout(items));verifySupport(l);assert.ok(l.shelves.length>3)
 for(const shelf of new Set(l.items.map(i=>i.shelf)))assert.equal(new Set(l.items.filter(i=>i.shelf===shelf).map(i=>i.group)).size,1)
 const huge=trophyLayout(10000);assert.equal(huge.items.length,75);assert.equal(huge.hidden,9925);verifySupport(huge)
 for(const n of [-1,1.5,Infinity,NaN])assert.throws(()=>trophyLayout(n),RangeError)
})
test('chip banks grow in thickness, spread across shelves and stay bounded at large balances',()=>{
 let previous=0;for(const n of [1,25,26,99,100,499,500,501,1000,10000,100000]){const p=chipPileParts(n);const layers=p.parts.reduce((s,p)=>s+p.layers,0);assert.ok(layers>=previous);previous=layers;assert.ok(p.parts.length<=75)}
 const l=cabinetLayout([{id:'bank',mode:'poker',kind:'poker_bank',bank_total:100000}]);assert.ok(new Set(l.items.map(t=>t.shelf)).size>1);verifySupport(l)
})
