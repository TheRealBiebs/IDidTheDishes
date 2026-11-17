import { TeamCup } from '../HouseholdThemes'
import { rewardFor } from './registry'
import GoldStarCalendar from './GoldStarCalendar'
import CatDashboard from './cats/CatDashboard'
import AdventurerRewards from './AdventurerRewards'

// One household theme chooses its reward presentation.
const presentations = { stars: GoldStarCalendar, cats:CatDashboard, adventure: AdventurerRewards }
export default function RewardDashboard(props) {
  const scheme = rewardFor(props.household?.reward_scheme)
  if(scheme.id==='poker')return null
  const Presentation = presentations[scheme.id]
  return Presentation ? <Presentation {...props}/> : <TeamCup {...props}/>
}
