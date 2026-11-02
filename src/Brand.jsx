import './brand.css'

export default function Brand(){
  return <span className="brand"><img className="brand-mark" src={`${import.meta.env.BASE_URL}brand/chip-in-mark.png`} alt=""/><span>Chip In</span></span>
}
