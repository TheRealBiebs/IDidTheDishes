import { TeamCup } from '../HouseholdThemes'
import { rewardFor } from './registry'
import GoldStarCalendar from './GoldStarCalendar'
import AdventurerRewards from './AdventurerRewards'

// Each system owns its presentation. Add future systems here without coupling
// them to themes, NFC, Auth, or completion logging.
const presentations = { stars: GoldStarCalendar, adventure: AdventurerRewards }
export default function RewardDashboard(props) {
  const scheme = rewardFor(props.household?.reward_scheme)
  const Presentation = presentations[scheme.id]
  return Presentation ? <Presentation {...props}/> : <TeamCup {...props}/>
}
