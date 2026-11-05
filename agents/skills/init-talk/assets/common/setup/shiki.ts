import { defineShikiSetup } from '@slidev/types'

// shiki ships a `synthwave-84` theme — the same lineage as the deck's palette,
// so code blocks match the slides without a hand-written token map.
export default defineShikiSetup(() => ({
  themes: {
    dark: 'synthwave-84',
    light: 'synthwave-84',
  },
}))
