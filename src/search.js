/**
 * Søk i emner, temaer, seksjoner (overskrifter) og videoer.
 * Indeksen bygges fra innholdsoversikten som lages i byggesteget (scripts/content-plugin.js),
 * så søket virker uten at temaene må lastes inn.
 */

export const SEARCH_TYPES = [
  { type: 'emne', label: 'Emner', limit: 4, weight: 40 },
  { type: 'tema', label: 'Temaer', limit: 6, weight: 30 },
  { type: 'video', label: 'Videoer', limit: 6, weight: 20 },
  { type: 'seksjon', label: 'Seksjoner', limit: 6, weight: 10 },
];

/** Små bokstaver og uten aksenter (é → e, å → a). Æ og ø har ingen aksent og beholdes. */
export function normalize(text) {
  return String(text).toLocaleLowerCase('nb').normalize('NFKD').replace(/[\u0300-\u036f]/g, '');
}

/**
 * routes: { course(course), topic(course, topicSlug, anchor?) } – lager lenkene.
 */
export function buildSearchIndex(courses, routes) {
  const entries = [];
  for (const course of courses) {
    entries.push({ type: 'emne', title: course.title, sub: course.description, href: routes.course(course), icon: course.icon });
    for (const topic of course.topics) {
      entries.push({ type: 'tema', title: topic.title, sub: course.title, extra: topic.description, href: routes.topic(course, topic.slug), icon: course.icon });
      for (const h of topic.headings ?? []) {
        entries.push({ type: 'seksjon', title: h.text, sub: `${course.title} › ${topic.title}`, href: routes.topic(course, topic.slug, h.id), icon: course.icon });
      }
      for (const v of topic.videos ?? []) {
        entries.push({ type: 'video', title: v.title, sub: v.meta || course.title, extra: course.title, href: routes.topic(course, topic.slug, v.anchor), url: v.url, icon: course.icon });
      }
    }
  }
  for (const e of entries) {
    e.normTitle = normalize(e.title);
    e.haystack = normalize(`${e.title} ${e.sub ?? ''} ${e.extra ?? ''}`);
  }
  return entries;
}

/** Returnerer treff gruppert etter type: [{ type, label, items: [...] }]. Alle ordene i søket må finnes. */
export function search(entries, query) {
  const terms = normalize(query).split(/\s+/).filter(Boolean);
  if (!terms.length) return [];
  const weight = Object.fromEntries(SEARCH_TYPES.map((t) => [t.type, t.weight]));
  const hits = [];
  for (const e of entries) {
    if (!terms.every((t) => e.haystack.includes(t))) continue;
    let score = weight[e.type];
    for (const t of terms) {
      if (e.normTitle.includes(t)) score += 5;
      if (e.normTitle.startsWith(t) || e.normTitle.includes(` ${t}`)) score += 3;
    }
    if (e.normTitle === terms.join(' ')) score += 20;
    hits.push({ ...e, score });
  }
  hits.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title, 'nb'));
  return SEARCH_TYPES.map(({ type, label, limit }) => {
    const all = hits.filter((h) => h.type === type);
    return { type, label, total: all.length, items: all.slice(0, limit) };
  }).filter((g) => g.items.length);
}

/** Deler en tekst i biter merket match: true/false, for utheving av søkeordene. */
export function highlightParts(text, query) {
  const terms = normalize(query).split(/\s+/).filter(Boolean);
  const chars = [...text];
  // Normaliser tegn for tegn, så posisjonene i den normaliserte teksten stemmer med originalen.
  const norm = chars.map((c) => {
    const n = normalize(c);
    return n.length === 1 ? n : c.toLowerCase();
  });
  const joined = norm.join('');
  const marked = new Array(chars.length).fill(false);
  for (const t of terms) {
    for (let i = joined.indexOf(t); i !== -1; i = joined.indexOf(t, i + 1)) {
      for (let k = i; k < i + t.length && k < marked.length; k++) marked[k] = true;
    }
  }
  const parts = [];
  chars.forEach((c, i) => {
    const last = parts[parts.length - 1];
    if (last && last.match === marked[i]) last.text += c;
    else parts.push({ text: c, match: marked[i] });
  });
  return parts;
}
