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
    themeVariables: {
      fontFamily: 'Fira Code, ui-monospace, monospace',
      fontSize: '17px',
      // Nodes are dark glass on the slide's indigo, outlined in magenta.
      primaryColor: '#241b3a',
      primaryTextColor: '#d4c8ff',
      primaryBorderColor: '#f92aad',
      secondaryColor: '#150d2b',
      tertiaryColor: '#1a1033',
      background: '#1a1033',
      mainBkg: '#241b3a',
      // Edges are the cyan register — "what you call".
      lineColor: '#00f0ff',
      textColor: '#d4c8ff',
      edgeLabelBackground: '#150d2b',
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
      /* Neon, not ink: every node and edge throws light. */
      .node rect, .node polygon, .node circle, .node path {
        filter: drop-shadow(0 0 6px rgba(249, 42, 173, 0.55));
      }
      .edgePath .path, .flowchart-link {
        filter: drop-shadow(0 0 5px rgba(0, 240, 255, 0.65));
        stroke-width: 1.8px;
      }
      .edgeLabel, .edgeLabel p {
        color: #8bfff5 !important;
        background: #150d2b !important;
        fill: #150d2b !important;
      }
      marker path { fill: #00f0ff !important; stroke: #00f0ff !important; }
    `,
    flowchart: {
      curve: 'basis',
      nodeSpacing: 60,
      rankSpacing: 60,
      padding: 12,
    },
  }
})
