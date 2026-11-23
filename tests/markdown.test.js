import { describe, expect, it } from 'vitest';
import { addHeadingIds, collapseAnswers, renderMarkdown, rewriteLinks, stripFrontmatter } from '../src/markdown.js';

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
});
