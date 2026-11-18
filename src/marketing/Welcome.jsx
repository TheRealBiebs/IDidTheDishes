import {useEffect,useRef} from 'react'
import './welcome.css'

const root=import.meta.env.BASE_URL,app=root,assets=root+'marketing/'
export const WELCOME_URL='https://therealbiebs.github.io/IDidTheDishes/?view=welcome'
const stories=[
 {title:'For bickering couples',color:'coral',quotes:[['“I won the house cup every week so far... which I guess kinda makes me the loser, huh”','Andrew'],['“I actually really wanted those trophies, but he keeps bogarting all the chores.”','Mia']]},
 {title:'For stubborn roommates',color:'yellow',quotes:[['“Taking the garbage out is one of those things we both would wait to do, see who would cave first”','Morgan'],['“Now I’m taking out the trash twice a day to feed my gambling addiction.”','Steph']]},
 {title:'For growing good habits',color:'green',quotes:[['“If I were crazy enough to let my kids have their own phones, they would probably love this shit. Maybe in a couple years.”','Callie'],['“This app is a vibe coded monstrosity, but it fucking works. I guarantee it”','Taylor']]},
]
function Arrow(){return <span aria-hidden="true">↗</span>}
function Link({children,...props}){return <a className="mk-button" {...props}>{children}</a>}
function Logo(){return <a className="mk-logo" href={app} aria-label="Chip In app"><img src={root+'brand/chip-in-mark.png'} alt="" width="48" height="48"/><span>Chip In<span className="mk-logo-dot">.</span></span></a>}

export default function Welcome(){
 const page=useRef(null)
 useEffect(()=>{
  const oldTitle=document.title,meta=document.querySelector('meta[name="description"]'),oldDescription=meta?.content,color=document.querySelector('meta[name="theme-color"]'),oldColor=color?.content
  document.title='Chip In — Hack Your Household. Get More Chipping In.'
  if(meta)meta.content='Turn household chores into a little friendly fun. Discover peel-and-stick felt Chore Chips, colorful rewards, and a quick start for your household.'
  if(color)color.content='#f7f3e9'
  const nodes=page.current.querySelectorAll('[data-mk-reveal]')
  const observer=typeof IntersectionObserver!=='undefined'?new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting){e.target.classList.add('mk-visible');observer.unobserve(e.target)}}),{threshold:.12}):null
  nodes.forEach(n=>observer?observer.observe(n):n.classList.add('mk-visible'))
  return()=>{observer?.disconnect();document.title=oldTitle;if(meta)meta.content=oldDescription;if(color)color.content=oldColor}
 },[])

 return <div className="marketing-page" ref={page}>
  <a className="mk-skip" href="#welcome-main">Skip to content</a>
  <header className="mk-header"><Logo/><nav aria-label="Welcome navigation"><a href="#testimonials">Household stories</a><a href="#setup">Quick start</a></nav><Link href={app}>Open app <Arrow/></Link></header>
  <main id="welcome-main">
   <section className="mk-hero mk-wrap" id="intro"><div className="mk-hero-copy"><span className="mk-kicker"><i/> Your House Will Never Be Cleaner</span><h1>Hack Your Household.<br/>Get More <span>Chipping In.</span></h1><p>The lowest possible friction chore tracking app. Easy to set up and easy to stick to. When you start fighting over chores, your house will never be cleaner.</p><div className="mk-actions"><Link href={app}>Let’s chip in <Arrow/></Link><a className="mk-text-link" href="#setup">Show me how <span aria-hidden="true">↓</span></a></div><div className="mk-hero-facts"><span>iPhone + Android</span><span>App store versions coming soon</span></div></div><div className="mk-hero-image"><img src={assets+'felt-chip-hero.webp'} alt="A phone scanning a thin teal felt Chore Chip on a wooden kitchen cupboard, with colorful felt circles on the counter" width="1536" height="1024" fetchPriority="high"/><div className="mk-log-card"><span aria-hidden="true">✓</span><div><strong>Do Chores. Get Points.</strong><small>Dominate your family</small></div></div></div><a className="mk-scroll" href="#testimonials">A happier household starts here <span aria-hidden="true">↓</span></a></section>
   <section className="mk-testimonials mk-wrap" id="testimonials" aria-labelledby="stories-title"><div className="mk-section-intro" data-mk-reveal><span className="mk-kicker">Let The App Do The Nagging</span><h2 id="stories-title">Leverage your lizard brain.<br/><em>Get a clean house</em></h2></div><div className="mk-story-grid">{stories.map(story=><article className={'mk-story-card mk-'+story.color} key={story.title} data-mk-reveal><h3>{story.title}</h3>{story.quotes.map(([quote,person])=><figure key={person}><blockquote>{quote}</blockquote><figcaption>{person}</figcaption></figure>)}</article>)}</div></section>
   <section className="mk-setup" id="setup" aria-labelledby="setup-title"><div className="mk-wrap"><div className="mk-section-intro" data-mk-reveal><span className="mk-kicker">Quick Start Steps</span><h2 id="setup-title">Turn contentious duties<br/>into a <em>race for points</em><br/><em>or a soft satisfied kitten</em></h2><p>Create your household, make the chores yours, and get everyone chipping in.</p></div><div className="mk-setup-grid">{[
    ['1','Create your Household','Create an account or log in with Google (currently this looks kinda sketchy). Create and name your household, and invite your fellow dwellers'],
    ['2','Select your Rewards','There are four different reward systems to choose from - the competitive house cup, routine building cozy cats, brain hacking casino, and the classic completionist sticker chart'],
    ['3','Peel, stick, connect','Peel off the felt sticker’s backing and stick it to any non-metal surface beside the task. Tap the chore chip with your phone to set it up. Tons of options let you customize your Chip In experience'],
   ].map(([n,title,copy])=><article key={n} data-mk-reveal><span>{n}</span><h3>{title}</h3><p>{copy}</p></article>)}</div><div className="mk-setup-actions"><Link href={app}>Open Chip In <Arrow/></Link></div>

   </div></section>
  </main><footer className="mk-footer mk-wrap"><Logo/><p>Made for the people you share a home with.</p><a href={app}>Go to the app <Arrow/></a></footer>
 </div>
}
