import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { createHash } from 'node:crypto'
import { readdir,readFile,writeFile } from 'node:fs/promises'
import { resolve,relative } from 'node:path'

function pwaAssets(){
  let config
  return {name:'chip-in-pwa',apply:'build',configResolved(value){config=value},async closeBundle(){
    const root=resolve(config.root,config.build.outDir)
    async function files(dir){const entries=await readdir(dir,{withFileTypes:true});return (await Promise.all(entries.map(e=>e.isDirectory()?files(resolve(dir,e.name)):[resolve(dir,e.name)]))).flat()}
    const paths=(await files(root)).filter(p=>!p.endsWith('sw.js')&&!p.endsWith('.map')).sort()
    const source=await readFile(resolve(root,'sw.js'),'utf8'),hash=createHash('sha256').update(source)
    for(const p of paths)hash.update(relative(root,p)).update(await readFile(p))
    const assets=paths.map(p=>relative(root,p).replaceAll('\\','/'))
    await writeFile(resolve(root,'sw.js'),source.replace('__BUILD_VERSION__',hash.digest('hex').slice(0,16)).replace('__PRECACHE_ASSETS__',JSON.stringify(assets)))
  }}
}

export default defineConfig({
  plugins: [react(),pwaAssets()],
  // Relative assets work at both username.github.io and /repository/ URLs.
  base: './',
})
