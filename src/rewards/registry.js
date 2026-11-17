// Themes choose one paired reward experience. Legacy adventure IDs remain readable in history.
export const REWARD_SCHEMES = {
  points: { id: 'points', name: 'Gemstone points', icon: '◆', status: 'Ready', description: 'Earn chore points and fill your team’s colourful gemstone tubes.', rule: 'Each chore has its own point value. Team tubes show the current week.', unit: 'pts' },
  stars: { id: 'stars', name: 'Gold-star calendar', icon: '★', status: 'Ready', description: 'A gold star for every completed chore, collected on a monthly calendar.', rule: 'One completion = one star, regardless of the chore’s point value. All logged chores appear on their original dates.', unit: 'stars' },
  cats: {id:'cats',name:'Cat companions',icon:'🐾',status:'Ready',description:'Care for your own weekly cat with daily chore points.',rule:'Feed at 25%, play at 50%, cuddle at 75%, sleep at 100%. Seven satisfied days earns your cat as a trophy.',unit:'pts'},
  poker: {id:'poker',name:'Poker chips',icon:'♠',status:'Ready',description:'Earn exact-value chip stacks on your household poker table.',rule:'White 1, red 5, blue 10, green 25, black 100. Poker games and betting are coming later.',unit:'pts'},
  adventure: { id: 'adventure', name: 'Household adventurers', icon: '⚔', status: 'Preview', description: 'A place for chore loot, character equipment, and friendly household battles.', rule: 'Preview only: chores are logged, but loot drops, equipment ownership, and real battles are not active yet.', unit: 'chores' },
}
export const rewardFor = id => REWARD_SCHEMES[id] || REWARD_SCHEMES.points
export const rewardValue = (scheme, score) => Number((['stars','adventure'].includes(scheme.id) ? score?.chores : score?.points) || 0)
export const completionReward = (scheme, points) => !['stars','adventure'].includes(scheme.id) ? `+${points} points` : scheme.id === 'stars' ? '+1 gold star' : 'Chore recorded'
export function rankedScores(scheme, scores = []) {
  return [...scores].sort((a, b) => rewardValue(scheme, b) - rewardValue(scheme, a))
}
export function monthCells(month) {
  const [year, number] = month.split('-').map(Number)
  const offset = (new Date(Date.UTC(year, number - 1, 1)).getUTCDay() + 6) % 7
  const days = new Date(Date.UTC(year, number, 0)).getUTCDate()
  return [...Array(offset).fill(null), ...Array.from({ length: days }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`)]
}
export function shiftMonth(month, amount) {
  const [year, number] = month.split('-').map(Number)
  return new Date(Date.UTC(year, number - 1 + amount, 1)).toISOString().slice(0, 7)
}
export const starCount = rows => rows.reduce((sum, row) => sum + Number(row.stars || 0), 0)
