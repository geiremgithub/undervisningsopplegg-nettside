import { defineConfig } from 'vite';
import { contentPlugin } from './scripts/content-plugin.js';

export default defineConfig({
  // Relative stier gjør at bygget fungerer både på rotdomene og i undermapper (GitHub Pages).
  base: './',
  plugins: [contentPlugin()],
  test: {
    environment: 'happy-dom',
  },
});
