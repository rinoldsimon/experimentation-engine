import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // Bind to all interfaces (not just localhost) so the dev server running
    // inside the Docker container is reachable from the host's browser.
    host: true,
    port: 4000,
    strictPort: true,
  },
})
