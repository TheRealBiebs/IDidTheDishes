import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // Relative assets work at both username.github.io and /repository/ URLs.
  base: './',
})
