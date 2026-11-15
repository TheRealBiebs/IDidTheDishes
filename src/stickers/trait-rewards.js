export const TRAIT_CHOICES=[['shabbily','Shabbily'],['good_enough','Good enough'],['perfection','To perfection'],['maintenance','Quick maintenance'],['standard','Standard'],['disaster','Nightmare / disaster area']]
export const traitDelta=(rules,key)=>Number(rules?.[key]||0)
export const signedPoints=value=>value>0?`+${value}`:String(value)
export const traitReward=(base,rules,quality,condition)=>Math.max(0,Number(base)+traitDelta(rules,quality)+traitDelta(rules,condition))
