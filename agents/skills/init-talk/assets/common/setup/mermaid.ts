import { defineMermaidSetup } from '@slidev/types'

// Mermaid renders into a shadow root, so styling has to go through
// themeVariables/themeCSS here — rules in styles.css do not reach it.
//
// It also sizes each box by measuring the label with its own default font, not
// the one below, so a box is never exactly the width of the text in it. Do not
// try to fix that by restyling labels from styles.css: those rules land on the
// element mermaid measures and corrupt the layout. The themeCSS below makes the
// discrepancy harmless instead — the label centres in whatever box it gets, and
// overflows rather than clipping.
export default defineMermaidSetup(() => {
  return {
    theme: 'base',
    look: 'handDrawn',
    handDrawnSeed: 42,
    themeVariables: {
      fontFamily: 'Caveat',
      fontSize: '26px',
      primaryColor: '#ffffff',
      primaryTextColor: '#000000',
      primaryBorderColor: '#3f3f46',
      lineColor: '#3f3f46',
      tertiaryColor: '#ffffff',
      edgeLabelBackground: '#ffffff',
    },
    themeCSS: `
      /* Mermaid sizes this div shrink-to-fit and then leaves it at the left
         edge of the independently measured foreignObject, which is what pushes
         labels off-centre. Centre it with an auto margin — do NOT give it a
         width (100%, or block display): mermaid reads this box back when
         laying out, and a stretched div inflates every node to the 200px
         max-width. overflow:visible keeps a slightly oversized label visible
         instead of clipped. */
      foreignObject { overflow: visible; }
      foreignObject > div {
        display: table !important;
        margin: 0 auto !important;
      }
    `,
    flowchart: {
      curve: 'basis',
      nodeSpacing: 60,
      rankSpacing: 60,
      padding: 12,
    },
  }
})
