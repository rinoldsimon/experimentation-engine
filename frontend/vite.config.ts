import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Bind to all interfaces (not just localhost) so the dev server running
    // inside the Docker container is reachable from the host's browser.
    host: true,
    port: 4000,
    strictPort: true,
  },
})
