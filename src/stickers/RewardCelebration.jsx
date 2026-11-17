import GemCascade from '../rewards/gems/GemCascade'
import {calendarSticker} from '../rewards/stickers'
import {PokerRewardDrop} from '../rewards/PokerChips'
export default function RewardCelebration({scheme='points',color='#c79b49',teamName,points=0,sticker='star'}){
  if(scheme==='cats')return <div className="reward-celebration celebration-cats" role="img" aria-label="Chore points help satisfy your cat"><div className="chore-sparkle" aria-hidden="true">🐾<span>+{points} cat-care points</span></div></div>
  if(scheme==='poker')return <PokerRewardDrop points={points}/>
  if(!['stars','adventure'].includes(scheme))return <GemCascade points={points} color={color} teamName={teamName}/>
  return <div className={`reward-celebration celebration-${scheme}`} style={{'--gem-color':/^#[0-9a-f]{6}$/i.test(color)?color:'#c79b49'}} role="img" aria-label={scheme==='stars'?'A sticker joins your chore calendar':['adventure','cats','poker'].includes(scheme)?'A completed chore is celebrated':'Colored gemstones fall into your jar'}>{scheme==='stars'?<><div className="mini-calendar"><span>Your little wins</span>{Array.from({length:14},(_,i)=><i key={i}>{i===10?<b>{calendarSticker(sticker)[1]}</b>:i+1}</i>)}</div><span className="whoosh-star" aria-hidden="true">{calendarSticker(sticker)[1]}</span></>:<div className="chore-sparkle" aria-hidden="true">✦<span>Chore recorded</span></div>}</div>
}
