import { defineConfig } from 'vite'

export default defineConfig({
  // @slidev/client's code.css uses `--uno: ... dark-text-gray-600` inside a
  // `::before` rule; UnoCSS expands that into a nested `.dark ...` selector,
  // which lightningcss (vite 8's CSS minifier) rejects with
  // "Invalid token in pseudo element". Vite 8 no longer ships esbuild either,
  // so skip CSS minification — a slide deck does not need those bytes.
  build: {
    cssMinify: false,
  },
})
