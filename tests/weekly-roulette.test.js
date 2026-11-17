import test from 'node:test'
import assert from 'node:assert/strict'
import {RED_NUMBERS,WHEEL_ORDER,pocketLabel,pocketColor,insideBet,rouletteReturn,betKey,betStake,wheelAngles} from '../src/rewards/roulette/rules.js'

test('American wheel has 38 unique pockets and ball lands in the actual rotated winning pocket',()=>{
 assert.equal(new Set(WHEEL_ORDER).size,38)
 assert.deepEqual([...WHEEL_ORDER].sort((a,b)=>a-b),Array.from({length:38},(_,i)=>i))
 for(const [i,n] of WHEEL_ORDER.entries()){
  const {wheel,ball}=wheelAngles(n),angle=((ball-wheel)%360+360)%360
  assert.ok(Math.abs(angle-(i+.5)*360/38)<1e-9,`pocket ${n}`)
 }
 assert.equal(pocketLabel(37),'00');assert.equal(pocketColor(37),'green');assert.equal(RED_NUMBERS.length,18)
})
test('inside bets follow the table geometry including zero splits, with canonical identities',()=>{
 assert.deepEqual(insideBet('split',4,1),{kind:'split',numbers:[1,4]})
 for(const pair of [[0,37],[0,1],[0,2],[2,37],[3,37]])assert.ok(insideBet('split',...pair))
 for(const pair of [[3,4],[6,7],[0,3],[36,37],[1,1]])assert.equal(insideBet('split',...pair),null)
 assert.deepEqual(insideBet('street',11).numbers,[10,11,12])
 assert.deepEqual(insideBet('corner',32).numbers,[32,33,35,36])
 assert.equal(insideBet('corner',33),null);assert.equal(insideBet('corner',35),null)
 assert.deepEqual(insideBet('sixline',31).numbers,[31,32,33,34,35,36]);assert.equal(insideBet('sixline',34),null)
 assert.equal(betKey({kind:'split',numbers:[2,1]}),betKey({kind:'split',numbers:[1,2]}))
})
test('all inside payouts include the original wager, and zeros lose every outside bet',()=>{
 const bets=[['straight',[37],36],['split',[1,2],18],['street',[1,2,3],12],['trio',[0,1,2],12],['corner',[1,2,4,5],9],['sixline',[1,2,3,4,5,6],6],['basket',[0,1,2,3,37],7]]
 for(const [kind,numbers,mult] of bets)for(let outcome=0;outcome<38;outcome++)assert.equal(rouletteReturn({kind,numbers,amount:5},outcome),numbers.includes(outcome)?5*mult:0)
 const outside=['red','black','even','odd','low','high','dozen1','dozen2','dozen3','column1','column2','column3']
 for(const kind of outside){assert.equal(rouletteReturn({kind,amount:7},0),0);assert.equal(rouletteReturn({kind,amount:7},37),0);const wins=Array.from({length:36},(_,i)=>rouletteReturn({kind,amount:7},i+1)).filter(Boolean);assert.equal(wins.length,kind.startsWith('dozen')||kind.startsWith('column')?12:18)}
 assert.equal(betStake([{amount:5},{amount:25}]),30)
 // Unbet money remains safe, and a straight-number win adds profit only once.
 assert.equal(100-5+rouletteReturn({kind:'straight',numbers:[17],amount:5},17),275)
})
