import { describe, expect, it } from 'vitest';
import { addHeadingIds, collapseAnswers, embedVideo, enhanceVideos, renderMarkdown, rewriteLinks, stripFrontmatter } from '../src/markdown.js';

function render(markdown) {
  const root = document.createElement('div');
  root.innerHTML = renderMarkdown(markdown);
  return root;
}

describe('markdown-visning', () => {
  it('fjerner frontmatter og uthever SQL', () => {
    expect(stripFrontmatter('---\ntitle: X\n---\n# Hei')).toBe('# Hei');
    expect(render('```sql\nSELECT 1\n```').querySelector('.hljs-keyword').textContent).toBe('SELECT');
  });

  it('legger fasit bak «Vis fasit» og stopper ved neste spørsmål', () => {
    const root = render(
      ['**1. (F, 1 p)** Spørsmål?', '**Fasit:** b.', 'Forklaring.', '```sql\nSELECT 1\n```', '**2. (K, 2 p)** Neste?'].join('\n\n'),
    );
    collapseAnswers(root);
    const details = root.querySelectorAll('details.collapsible--answer');
    expect(details).toHaveLength(1);
    expect(details[0].querySelector('summary').textContent).toBe('Vis fasit');
    expect(details[0].querySelector('pre')).not.toBeNull();
    expect(root.lastElementChild.textContent).toContain('Neste?');
  });

  it('gir et lærernotat i sitat rett etter en fasit sin egen knapp', () => {
    const root = render('**Fasit:** b.\n\n> **Lærernotat:** Sjekk datatypen.');
    collapseAnswers(root);
    expect(root.querySelector('details.collapsible--answer').textContent).not.toContain('Sjekk datatypen');
    expect(root.querySelector('details.collapsible--teacher').textContent).toContain('Sjekk datatypen');
  });

  it('legger lærervedlegg bak sammenleggbar seksjon frem til neste overskrift på samme nivå', () => {
    const root = render('## Oppgaver\n\nTekst\n\n## Vedlegg: hurtigreferanse for læreren\n\nHemmelig\n\n### Under\n\nMer\n\n## Neste\n');
    addHeadingIds(root);
    collapseAnswers(root);
    const teacher = root.querySelector('details.collapsible--teacher');
    expect(teacher.querySelector('summary h2').id).toBe('vedlegg-hurtigreferanse-for-laereren');
    expect(teacher.textContent).toContain('Mer');
    expect(teacher.textContent).not.toContain('Neste');
  });

  it('gjør filnavn og relative lenker om til interne ruter', () => {
    const root = render('Se `case/03-etl.sql`, [samling](01-samling-1.md#lab), [ankeret](#Mål) og [Fabric](#/emne/fabric/tema/02-lakehouse).');
    rewriteLinks(root, {
      resolve: (t) => ({ 'case/03-etl.sql': '#/fil/case/03-etl.sql', '01-samling-1.md': '#/tema/01-samling-1' })[t] ?? null,
      imageUrl: () => null,
      currentRoute: '#/tema/x',
    });
    const hrefs = [...root.querySelectorAll('a')].map((a) => a.getAttribute('href'));
    expect(hrefs).toEqual(['#/fil/case/03-etl.sql', '#/tema/01-samling-1/lab', '#/tema/x/mal', '#/emne/fabric/tema/02-lakehouse']);
  });

  it('merker lenker til YouTube og Vimeo som video', () => {
    const root = render('[A](https://www.youtube.com/watch?v=abc) [B](https://youtu.be/abc) [C](https://vimeo.com/1) [D](https://learn.microsoft.com)');
    rewriteLinks(root, { resolve: () => null, imageUrl: () => null, currentRoute: '#/' });
    const links = [...root.querySelectorAll('a')];
    expect(links.map((a) => a.classList.contains('video-link'))).toEqual([true, true, true, false]);
    expect(links[0].textContent).toContain('(video, åpnes i ny fane)');
  });

  it('gjør videolister og videotabeller om til kort som laster spilleren først ved klikk', () => {
    const root = render([
      '### Kortvideo',
      '- **Kanal / kilde:** YouTube – IBM · 3:46',
      '- **Lenke:** https://www.youtube.com/watch?v=BBBBBBBBBBB',
      '- **Nivå:** Nybegynner',
      '',
      '### Vanlig liste',
      '- **Lenke:** https://learn.microsoft.com',
      '',
      '| Video | Kilde | Om |',
      '|---|---|---|',
      '| [Tabellvideo](https://vimeo.com/123) | Vimeo – X · 5:22 | Beskrivelse |',
    ].join('\n'));
    rewriteLinks(root, { resolve: () => null, imageUrl: () => null, currentRoute: '#/' });
    enhanceVideos(root);

    const card = root.querySelector('.video-card');
    expect(card.querySelector('h3').textContent).toBe('Kortvideo');
    expect([...card.querySelectorAll('.chip')].map((c) => c.textContent)).toEqual(['⏱ 3:46', 'Nybegynner']);
    expect(root.querySelectorAll('.video-card')).toHaveLength(1);
    expect(root.querySelector('table')).toBeNull();
    const tile = root.querySelector('.video-tile');
    expect(tile.querySelector('.video-url').textContent).toBe('https://vimeo.com/123');
    expect(tile.querySelector('.video-tile-desc').textContent).toBe('Beskrivelse');
    expect(root.querySelector('iframe')).toBeNull();

    const iframe = embedVideo(card.querySelector('.video-play'));
    expect(iframe.src).toBe('https://www.youtube-nocookie.com/embed/BBBBBBBBBBB?autoplay=1&rel=0');
    expect(card.querySelector('.video-play')).toBeNull();
  });
});
