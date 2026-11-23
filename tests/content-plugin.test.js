import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { buildContentIndex, describeSqlFile, outlineTopic } from '../scripts/content-plugin.js';

let dir;
afterEach(() => dir && fs.rmSync(dir, { recursive: true, force: true }));

function project(filesByPath) {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'innhold-'));
  for (const [rel, text] of Object.entries(filesByPath)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), text);
  }
  return dir;
}

describe('innholdsskanning', () => {
  it('lager ett emne per mappe, med temaer fra frontmatter sortert på order', () => {
    const root = project({
      'content/b-emne/emne.json': '{ "title": "Emne B", "description": "Om B", "order": 2 }',
      'content/b-emne/b.md': '---\ntitle: Andre\ndescription: Beskrivelse B\norder: 2\n---\n# B',
      'content/b-emne/a.md': '---\ntitle: Første\norder: 1\n---\nBruk `case/x.sql`.',
      'content/b-emne/uten-meta.md': '# Tittel fra overskrift\n',
      'content/b-emne/_kladd.md': '---\ntitle: Kladd\n---\n',
      'content/b-emne/case/x.sql': '/* ====\n   Tittel X\n   Fil: case/x.sql\n   Beskrivelse X\n   ==== */\nSELECT 1;',
      'content/a-emne/intro.md': '# Intro',
      'content/tomt-emne/emne.json': '{ "title": "Tomt" }',
      'content/_skjult/x.md': '# Skjult',
    });
    const { courses } = buildContentIndex(root);
    expect(courses.map((c) => c.slug)).toEqual(['b-emne', 'a-emne']);
    const [b, a] = courses;
    expect(b).toMatchObject({ title: 'Emne B', description: 'Om B', order: 2 });
    expect(a.title).toBe('a-emne');
    expect(b.topics.map((t) => t.slug)).toEqual(['a', 'b', 'uten-meta']);
    expect(b.topics[1]).toMatchObject({ title: 'Andre', description: 'Beskrivelse B', order: 2 });
    expect(b.topics[2].title).toBe('Tittel fra overskrift');
    expect(b.topics[0].files).toEqual(['case/x.sql']);
    expect(b.files).toEqual([{ path: 'case/x.sql', name: 'x.sql', title: 'Tittel X', description: 'Beskrivelse X' }]);
  });

  it('gir en tydelig feilmelding ved ugyldig emne.json', () => {
    const root = project({ 'content/x/emne.json': '{ title: mangler anførselstegn }', 'content/x/a.md': '# A' });
    expect(() => buildContentIndex(root)).toThrow(/Ugyldig JSON i .*emne\.json/);
  });

  it('peker på filen når frontmatter mangler avsluttende ---', () => {
    const root = project({ 'content/x/a.md': '---\ntitle: A\n# A\n![Logo](//cdn.example.com/x.png)\n' });
    expect(() => buildContentIndex(root)).toThrow(/Ugyldig frontmatter i .*a\.md: Mangler den avsluttende ---/);
  });

  it('knytter like filnavn i ulike mapper til temaet bare når hele stien nevnes', () => {
    const root = project({
      'content/x/a.md': 'Se `del1/x.sql`.',
      'content/x/b.md': 'Se `x.sql`.',
      'content/x/del1/x.sql': 'SELECT 1;',
      'content/x/del2/x.sql': 'SELECT 2;',
    });
    const [course] = buildContentIndex(root).courses;
    expect(course.topics.map((t) => t.files)).toEqual([['del1/x.sql'], []]);
  });

  it('leser beskrivelse fra linjekommentarer i SQL', () => {
    expect(describeSqlFile('-- Tittel\n-- Mer tekst\nSELECT 1;')).toEqual({ title: 'Tittel', description: 'Mer tekst' });
  });

  it('henter overskrifter og videoer i begge formatene til søket, med samme ID-er som på siden', () => {
    const { headings, videos } = outlineTopic([
      '# Videoer',
      '## Del 1: `git init`',
      '| Video | Kilde |',
      '|---|---|',
      '| [Tabellvideo](https://youtu.be/AAAAAAAAAAA) | YouTube – Kanal · 5:22 |',
      '```markdown',
      '## Ikke en overskrift',
      '```',
      '## Del 1: `git init`',
      '### Kortvideo',
      '- **Kanal / kilde:** YouTube – IBM · 3:46',
      '- **Lenke:** https://www.youtube.com/watch?v=BBBBBBBBBBB',
      '- **Nivå:** Nybegynner',
    ].join('\n'));
    expect(headings.map((h) => h.id)).toEqual(['del-1-git-init', 'del-1-git-init-2', 'kortvideo']);
    expect(videos).toEqual([
      { title: 'Tabellvideo', url: 'https://youtu.be/AAAAAAAAAAA', meta: 'YouTube – Kanal · 5:22', level: null, anchor: 'del-1-git-init' },
      { title: 'Kortvideo', url: 'https://www.youtube.com/watch?v=BBBBBBBBBBB', meta: 'YouTube – IBM · 3:46', level: 'Nybegynner', anchor: 'kortvideo' },
    ]);
  });

  it('lager de samme overskrift-ID-ene som siden, også med innrykk, sitat og HTML-tegn', async () => {
    const { renderMarkdown, addHeadingIds } = await import('../src/markdown.js');
    const markdown = '# Tittel\n   ## A &amp; B\n> ## I sitat\n## A & B\n## C# og \\*stjerne\\* ##\n## Vanlig';
    const root = document.createElement('div');
    root.innerHTML = renderMarkdown(markdown);
    addHeadingIds(root);
    const runtime = [...root.querySelectorAll('h2, h3')].map((h) => h.id);
    expect(outlineTopic(markdown).headings.map((h) => h.id)).toEqual(runtime);
  });

  it('leser valgfritt ikon og kategori fra emne.json', () => {
    const root = project({ 'content/x/emne.json': '{ "title": "X", "ikon": "database", "kategori": "Data" }', 'content/x/a.md': '# A' });
    expect(buildContentIndex(root).courses[0]).toMatchObject({ icon: 'database', category: 'Data' });
  });
});
