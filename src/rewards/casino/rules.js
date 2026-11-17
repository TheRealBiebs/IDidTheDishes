export const SLOT_SYMBOLS=['🍒','🍋','🍇','🔔','💎','7']
export const SLOT_MULTIPLIERS=[5,8,10,15,25,40]
export function slotMultiplier(reels){const cherries=reels.filter(n=>n===0).length;return reels.every(n=>n===reels[0])?SLOT_MULTIPLIERS[reels[0]]:cherries===2?2:cherries===1?1:0}
export function cardInfo(card){const rank=card%13,suit=Math.floor(card/13);return {rank:['A','2','3','4','5','6','7','8','9','10','J','Q','K'][rank],suit:['♠','♥','♣','♦'][suit],red:suit===1||suit===3}}
export function blackjackTotal(cards){let total=0,aces=0;for(const card of cards){const rank=card%13;if(!rank){total+=11;aces++}else total+=Math.min(10,rank+1)}while(total>21&&aces){total-=10;aces--}return total}
export const emptyWallet={available:0,banked:0,earned:0,wagered:0,returned:0,net_gambling:0,adjustment_due:0}
export function pendingCasinoKey(house,user){return `chip-in-casino:${house}:${user}`}
