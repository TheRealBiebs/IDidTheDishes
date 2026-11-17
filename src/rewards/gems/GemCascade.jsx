import {useMemo} from 'react'
import {GemTube} from '../../WizardTheme'
import Gemstone,{gemPalette} from './Gemstone'
import {cascadeStones,visibleWinners} from './cascade-layout'
import './gem-cascade.css'

export default function GemCascade({variant='score',points=0,color='#54cba0',teamName,winners=[]}){
 const recap=variant==='recap'
 const entries=recap?(winners.length?visibleWinners(winners):[{name:'New week',points:0,color:'#a99776'}]):[{name:teamName||'',points,color}]
 const label=recap?(winners.length?`Faceted gemstones rise from the winning tubes and cascade in celebration of ${winners.map(w=>w.name).join(', ')}`:'A new week begins with an empty gemstone tube'):points>0?`${points} points: faceted gemstones cascade into your brass and glass tube`:'No points awarded; an empty gemstone tube'
 return <div className={`gem-cascade cascade-${variant} ${entries.length>1?'cascade-multiple':''}`} role="img" aria-label={label}>
  <div className="gem-cascade-scenes" aria-hidden="true">{entries.map((entry,i)=><GemScene key={entry.team_id||i} entry={entry} recap={recap} seed={i+1}/>)}</div>
  {recap&&winners.length>entries.length&&<p className="cascade-more-winners">+{winners.length-entries.length} more tied winners</p>}
 </div>
}
function GemScene({entry,recap,seed}){
 const palette=gemPalette(entry.color),points=Math.max(0,Number(entry.points??entry.score)||0),capacity=Math.max(40,Math.ceil(points/20)*40)
 const stones=useMemo(()=>cascadeStones(points,{recap,seed}),[points,recap,seed])
 return <div className={`gem-cascade-scene ${points>0?'cascade-has-points':'cascade-empty'}`} style={{'--cascade-color':palette.color,'--cascade-light':palette.light}}>
  <div className="cascade-arch"/><div className="cascade-halo"/>
  <div className="cascade-apparatus"><GemTube house={{...palette,name:entry.name||'Your',light:palette.light}} points={points} capacity={capacity}/></div>
  <div className="cascade-particles">{stones.map(stone=><span className="gem-flight" key={stone.id} style={{'--delay':stone.delay+'s','--flight-duration':stone.duration+'s','--gem-size':stone.size+'px','--start':stone.start+'px','--end':stone.end+'px','--landing':stone.landing+'px','--arc':stone.arc+'px','--spread':stone.spread+'px','--lift':stone.lift+'px','--spin':stone.spin+'deg','--turn':stone.turn+'deg'}}><Gemstone color={palette.color} variant={stone.id}/></span>)}</div>
  <div className="cascade-lens"/>
  {points>0&&<><div className="cascade-impact"/><div className="cascade-sparks">{Array.from({length:6},(_,i)=><i key={i} style={{'--spark-delay':(.4+i*.25)+'s',left:(24+(i*23)%55)+'%',top:(20+(i*31)%53)+'%'}}>✦</i>)}</div></>}
  {entry.name&&<span className="cascade-team-name">{entry.name}</span>}
 </div>
}
