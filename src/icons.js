/**
 * Enkle strek-ikoner (24 × 24) for emner og grensesnitt.
 * Et emne velger ikon med feltet "ikon" i emne.json, f.eks. "ikon": "database".
 * Nytt ikon: legg til en linje under med SVG-innholdet (path, rect, circle …).
 */
const ICONS = {
  // Fagområder
  database: '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/><path d="M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6"/>',
  chart: '<path d="M3 3v18h18"/><rect x="7" y="12" width="3" height="5" rx="0.5"/><rect x="12" y="8" width="3" height="9" rx="0.5"/><rect x="17" y="5" width="3" height="12" rx="0.5"/>',
  layers: '<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 13 9 5 9-5"/><path d="m3 17.5 9 4.5 9-4.5" opacity="0.6"/>',
  bot: '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 4v4"/><circle cx="12" cy="3.5" r="1"/><circle cx="9" cy="14" r="1.3"/><circle cx="15" cy="14" r="1.3"/><path d="M2 13v3M22 13v3"/>',
  plug: '<path d="M9 2v5M15 2v5"/><path d="M6 7h12v4a6 6 0 0 1-12 0V7Z"/><path d="M12 17v5"/>',
  'search-doc': '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5"/><path d="M14 3v5h5"/><path d="M14 3l5 5v3"/><circle cx="16.5" cy="16.5" r="3.5"/><path d="m19 19 3 3"/><path d="M7.5 9h3M7.5 13h3"/>',
  sparkles: '<path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8Z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8Z"/><path d="M5 16l.6 1.4L7 18l-1.4.6L5 20l-.6-1.4L3 18l1.4-.6Z"/>',
  'git-branch': '<circle cx="6" cy="5" r="2.2"/><circle cx="6" cy="19" r="2.2"/><circle cx="18" cy="7" r="2.2"/><path d="M6 7.2v9.6"/><path d="M18 9.2c0 5-6 3.5-11 7.8"/>',
  code: '<rect x="2.5" y="4" width="19" height="16" rx="2.5"/><path d="M2.5 8.5h19"/><path d="m9 12.5-2.5 2.5L9 17.5M15 12.5l2.5 2.5-2.5 2.5"/>',
  api: '<path d="M8 3c-2 0-3 1-3 3v3c0 1.5-1 2.5-2.5 3C4 12.5 5 13.5 5 15v3c0 2 1 3 3 3"/><path d="M16 3c2 0 3 1 3 3v3c0 1.5 1 2.5 2.5 3-1.5.5-2.5 1.5-2.5 3v3c0 2-1 3-3 3"/><circle cx="9" cy="12" r="0.9"/><circle cx="12" cy="12" r="0.9"/><circle cx="15" cy="12" r="0.9"/>',
  cloud: '<path d="M7 18a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 18 8.5a4.75 4.75 0 0 1-.5 9.5H7Z"/>',
  book: '<path d="M4 19.5V5a2 2 0 0 1 2-2h13v15H6.5A2.5 2.5 0 0 0 4 20.5 2.5 2.5 0 0 0 6.5 23H19v-5"/><path d="M8 7h7M8 11h5"/>',

  // Grensesnitt
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  moon: '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5Z"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  play: '<circle cx="12" cy="12" r="9.5"/><path d="M10 8.5v7l5.5-3.5Z" fill="currentColor"/>',
  'arrow-right': '<path d="M5 12h14M13 6l6 6-6 6"/>',
  'chevron-down': '<path d="m6 9 6 6 6-6"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  doc: '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9Z"/><path d="M14 3v6h6"/>',
  hash: '<path d="M5 9h14M5 15h14M10 3 8 21M16 3l-2 18"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
};

/** Returnerer SVG-kode for et ikon. Ukjente navn gir bok-ikonet. */
export function iconSvg(name, { size = 24, className = 'icon' } = {}) {
  const body = ICONS[name] ?? ICONS.book;
  return `<svg class="${className}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${body}</svg>`;
}

/** Samme som iconSvg, men som DOM-element. */
export function icon(name, options) {
  const template = document.createElement('template');
  template.innerHTML = iconSvg(name, options);
  return template.content.firstElementChild;
}

export const ICON_NAMES = Object.keys(ICONS);
