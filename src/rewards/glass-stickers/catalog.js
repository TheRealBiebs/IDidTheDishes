export const GLASS_STICKERS=[['rainbow','Rainbow dreams','🌈'],['unicorn','Prismatic unicorn','🦄'],['cosmic-cat','Cosmic kitty','🐱'],['dolphin','Rainbow dolphin','🐬'],['butterfly','Holographic butterfly','🦋'],['dragon','Glitter dragon','🐉'],['tiger','Neon tiger','🐯'],['heart','Starlight heart','💖']]
export const glassSticker=id=>GLASS_STICKERS.find(s=>s[0]===id)||GLASS_STICKERS[0]
export const clampSticker=(value)=>Math.max(8,Math.min(92,value))
