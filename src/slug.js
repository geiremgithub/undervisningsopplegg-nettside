/**
 * Lager en URL-vennlig ID av en overskrift, f.eks. «3. Søk på nett» → «3-sok-pa-nett».
 * Brukes både i nettleseren (overskrift-ID-er) og i byggesteget (søkeindeksen), så de alltid er like.
 */
export function slugify(text) {
  return (
    text
      .toLocaleLowerCase('nb')
      .replace(/æ/g, 'ae')
      .replace(/ø/g, 'o')
      .replace(/å/g, 'a')
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'seksjon'
  );
}

/** Gir ID-er unike på samme måte som på siden: andre forekomst får «-2», tredje «-3» osv. */
export function createSlugger() {
  const used = new Set();
  return (text) => {
    const base = slugify(text);
    let id = base;
    for (let i = 2; used.has(id); i++) id = `${base}-${i}`;
    used.add(id);
    return id;
  };
}

const VIDEO_PATTERNS = [
  [/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([\w-]{11})/i, 'youtube'],
  [/vimeo\.com\/(?:video\/)?(\d+)/i, 'vimeo'],
];

/** Finner leverandør og video-ID i en YouTube- eller Vimeo-lenke. Returnerer null for andre lenker. */
export function parseVideoUrl(url) {
  for (const [pattern, provider] of VIDEO_PATTERNS) {
    const match = String(url).match(pattern);
    if (match) return { provider, id: match[1] };
  }
  return null;
}
