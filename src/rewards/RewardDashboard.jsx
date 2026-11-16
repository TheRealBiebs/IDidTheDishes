import { TeamCup } from '../HouseholdThemes'
import { rewardFor } from './registry'
import GoldStarCalendar from './GoldStarCalendar'
import PreviewRewards from './PreviewRewards'
import AdventurerRewards from './AdventurerRewards'

// One household theme chooses its reward presentation.
const presentations = { stars: GoldStarCalendar, cats:PreviewRewards, poker:PreviewRewards, adventure: AdventurerRewards }
export default function RewardDashboard(props) {
  const scheme = rewardFor(props.household?.reward_scheme)
  const Presentation = presentations[scheme.id]
  return Presentation ? <Presentation {...props}/> : <TeamCup {...props}/>
}
