import { describe, expect, it } from 'vitest';
import { buildSearchIndex, highlightParts, search } from '../src/search.js';

const courses = [
  {
    slug: 'rag',
    title: 'RAG-løsninger',
    description: 'Chunking og embeddings',
    icon: 'search-doc',
    topics: [
      {
        slug: '01-kjeden',
        title: 'RAG-kjeden',
        description: '',
        headings: [{ level: 2, text: '3. Chunking: del opp', id: '3-chunking-del-opp' }],
        videos: [{ title: 'Chunking Strategies Explained', url: 'https://youtu.be/x', meta: 'YouTube – Redis · 8:25', anchor: 'chunking' }],
      },
    ],
  },
  { slug: 'git', title: 'Git og GitHub', description: 'Versjonskontroll', topics: [{ slug: '01', title: 'Grunnleggende', description: 'Søk i historikken', headings: [], videos: [] }] },
];
const routes = { course: (c) => `#/emne/${c.slug}`, topic: (c, t, a) => `#/emne/${c.slug}/tema/${t}${a ? `/${a}` : ''}` };

describe('søk', () => {
  const index = buildSearchIndex(courses, routes);

  it('finner emner, seksjoner og videoer og lenker rett til riktig sted', () => {
    const groups = search(index, 'chunking');
    expect(groups.map((g) => g.type)).toEqual(['emne', 'video', 'seksjon']);
    expect(groups.find((g) => g.type === 'seksjon').items[0].href).toBe('#/emne/rag/tema/01-kjeden/3-chunking-del-opp');
    expect(groups.find((g) => g.type === 'video').items[0].href).toBe('#/emne/rag/tema/01-kjeden/chunking');
  });

  it('krever alle ordene, og skiller ikke på store bokstaver og aksenter', () => {
    expect(search(index, 'GIT versjon').flatMap((g) => g.items.map((i) => i.title))).toEqual(['Git og GitHub']);
    expect(search(index, 'sok historikk').length).toBe(0);
    expect(search(index, 'søk historikk')[0].items[0].title).toBe('Grunnleggende');
    expect(search(index, '   ')).toEqual([]);
  });

  it('markerer treffene i teksten', () => {
    expect(highlightParts('RAG-løsninger', 'løsning')).toEqual([
      { text: 'RAG-', match: false },
      { text: 'løsning', match: true },
      { text: 'er', match: false },
    ]);
  });
});
