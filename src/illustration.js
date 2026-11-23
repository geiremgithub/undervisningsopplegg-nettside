/**
 * Dekorativ illustrasjon til toppseksjonen på forsiden: kodevindu, database, sky, KI-nettverk og Git-gren.
 * Fargene styres fra CSS (klassene ill-*), så den passer både lyst og mørkt tema.
 */
export const HERO_ILLUSTRATION = `
<svg class="hero-illustration" viewBox="0 0 560 440" role="img" aria-labelledby="hero-ill-title" focusable="false">
  <title id="hero-ill-title">Illustrasjon av et kodevindu koblet til en database, en sky, et KI-nettverk og en Git-gren</title>
  <defs>
    <linearGradient id="ill-accent" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2563EB" />
      <stop offset="1" stop-color="#06B6D4" />
    </linearGradient>
    <radialGradient id="ill-glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#06B6D4" stop-opacity="0.35" />
      <stop offset="1" stop-color="#2563EB" stop-opacity="0" />
    </radialGradient>
  </defs>

  <circle cx="290" cy="210" r="210" fill="url(#ill-glow)" />

  <!-- Koblingslinjer -->
  <g class="ill-wires" fill="none" stroke-width="2" stroke-dasharray="5 7">
    <path d="M150 320 C 170 300, 180 290, 200 280" />
    <path d="M420 120 C 440 110, 450 100, 455 92" />
    <path d="M400 260 C 420 280, 430 290, 445 300" />
    <path d="M96 200 C 110 190, 120 180, 130 170" />
  </g>

  <!-- Kodevindu -->
  <g class="float-a">
    <rect class="ill-card" x="120" y="70" width="300" height="220" rx="18" />
    <rect class="ill-card-bar" x="120" y="70" width="300" height="36" rx="18" />
    <rect class="ill-card-bar" x="120" y="88" width="300" height="18" />
    <circle cx="144" cy="88" r="5" fill="#F87171" />
    <circle cx="162" cy="88" r="5" fill="#FBBF24" />
    <circle cx="180" cy="88" r="5" fill="#34D399" />
    <rect class="ill-muted" x="300" y="83" width="96" height="10" rx="5" />
    <g>
      <rect class="ill-c1" x="146" y="126" width="54" height="10" rx="5" />
      <rect class="ill-c2" x="208" y="126" width="88" height="10" rx="5" />
      <rect class="ill-c3" x="166" y="148" width="120" height="10" rx="5" />
      <rect class="ill-c2" x="294" y="148" width="40" height="10" rx="5" />
      <rect class="ill-c3" x="166" y="170" width="70" height="10" rx="5" />
      <rect class="ill-c1" x="244" y="170" width="100" height="10" rx="5" />
      <rect class="ill-c3" x="186" y="192" width="150" height="10" rx="5" />
      <rect class="ill-c2" x="186" y="214" width="64" height="10" rx="5" />
      <rect class="ill-c3" x="258" y="214" width="58" height="10" rx="5" />
      <rect class="ill-c1" x="146" y="236" width="40" height="10" rx="5" />
      <rect class="ill-cursor" x="194" y="234" width="3" height="14" rx="1.5" />
    </g>
  </g>

  <!-- Database -->
  <g class="float-b">
    <path class="ill-db" d="M40 300 v64 c0 12 24 22 54 22 s54 -10 54 -22 v-64" />
    <ellipse class="ill-db-top" cx="94" cy="300" rx="54" ry="20" />
    <path class="ill-db-line" d="M40 332 c0 12 24 22 54 22 s54 -10 54 -22" fill="none" />
  </g>

  <!-- Sky -->
  <g class="float-c">
    <path class="ill-cloud" d="M446 96 a26 26 0 0 1 -2 -52 a34 34 0 0 1 64 -4 a26 26 0 0 1 10 56 Z" />
    <path d="M466 66 l12 -12 l12 12 M478 54 v28" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round" />
  </g>

  <!-- KI-nettverk -->
  <g class="float-b ill-net">
    <g class="ill-net-lines" stroke-width="2">
      <path d="M450 300 L 500 270 M450 300 L 500 330 M450 300 L 500 300 M500 270 L 540 300 M500 330 L 540 300 M500 300 L 540 300 M450 300 L 410 340 M410 340 L 500 330" />
    </g>
    <circle class="ill-node" cx="450" cy="300" r="10" />
    <circle class="ill-node ill-node--alt" cx="500" cy="270" r="8" />
    <circle class="ill-node" cx="500" cy="300" r="7" />
    <circle class="ill-node ill-node--alt" cx="500" cy="330" r="8" />
    <circle class="ill-node" cx="540" cy="300" r="10" />
    <circle class="ill-node ill-node--alt" cx="410" cy="340" r="7" />
  </g>

  <!-- Git-gren -->
  <g class="float-c ill-git" fill="none" stroke-width="3" stroke-linecap="round">
    <path d="M60 110 V 230" />
    <path d="M60 140 C 60 160, 96 160, 96 180 V 200" />
    <circle cx="60" cy="110" r="7" class="ill-git-node" />
    <circle cx="60" cy="170" r="7" class="ill-git-node" />
    <circle cx="96" cy="200" r="7" class="ill-git-node ill-git-node--alt" />
    <circle cx="60" cy="230" r="7" class="ill-git-node" />
  </g>

  <!-- Merkelapper -->
  <g class="ill-chips" font-family="ui-monospace, 'Cascadia Code', Consolas, monospace" font-size="13" font-weight="700">
    <g class="float-c">
      <rect class="ill-chip" x="250" y="20" width="76" height="30" rx="15" />
      <text x="288" y="40" text-anchor="middle">MCP</text>
    </g>
    <g class="float-a">
      <rect class="ill-chip" x="330" y="388" width="76" height="30" rx="15" />
      <text x="368" y="408" text-anchor="middle">RAG</text>
    </g>
    <g class="float-b">
      <rect class="ill-chip ill-chip--accent" x="196" y="318" width="104" height="30" rx="15" />
      <text x="248" y="338" text-anchor="middle" fill="#fff">git push</text>
    </g>
    <g class="float-a">
      <rect class="ill-chip" x="12" y="40" width="92" height="30" rx="15" />
      <text x="58" y="60" text-anchor="middle">{ JSON }</text>
    </g>
  </g>
</svg>`;
