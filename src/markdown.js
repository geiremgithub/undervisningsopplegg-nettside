import MarkdownIt from 'markdown-it';
import hljs from 'highlight.js/lib/core';
import sql from 'highlight.js/lib/languages/sql';
import python from 'highlight.js/lib/languages/python';
import javascript from 'highlight.js/lib/languages/javascript';
import bash from 'highlight.js/lib/languages/bash';
import powershell from 'highlight.js/lib/languages/powershell';
import json from 'highlight.js/lib/languages/json';
import yaml from 'highlight.js/lib/languages/yaml';
import xml from 'highlight.js/lib/languages/xml';
import csharp from 'highlight.js/lib/languages/csharp';
import plaintext from 'highlight.js/lib/languages/plaintext';

for (const [name, lang] of Object.entries({ sql, python, javascript, bash, powershell, json, yaml, xml, csharp, plaintext })) {
  hljs.registerLanguage(name, lang);
}
hljs.registerAliases(['tsql', 'mssql', 'postgresql', 'psql'], { languageName: 'sql' });
hljs.registerAliases(['py'], { languageName: 'python' });
hljs.registerAliases(['js'], { languageName: 'javascript' });
hljs.registerAliases(['sh', 'shell'], { languageName: 'bash' });
hljs.registerAliases(['ps', 'ps1'], { languageName: 'powershell' });
hljs.registerAliases(['html'], { languageName: 'xml' });
hljs.registerAliases(['text', 'txt'], { languageName: 'plaintext' });

const escapeHtml = (s) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function highlight(code, lang) {
  const language = lang && hljs.getLanguage(lang) ? lang : null;
  return language ? hljs.highlight(code, { language, ignoreIllegals: true }).value : escapeHtml(code);
}

const md = new MarkdownIt({
  // Innholdet skrives av læreren, og noen tabeller bruker <br>.
  html: true,
  linkify: true,
  highlight: (code, lang) => {
    const language = (lang || '').trim().split(/\s+/)[0].toLowerCase();
    const known = language && hljs.getLanguage(language);
    const cls = known ? `hljs language-${language}` : 'hljs';
    const label = known ? `<span class="code-lang" aria-hidden="true">${escapeHtml(language.toUpperCase())}</span>` : '';
    return `<pre class="code-block">${label}<code class="${cls}">${highlight(code, language)}</code></pre>`;
  },
});

export function stripFrontmatter(raw) {
  return raw.replace(/^\uFEFF/, '').replace(/^---\r?\n[\s\S]*?\r?\n---[ \t]*(\r?\n|$)/, '');
}

export function renderMarkdown(raw) {
  return md.render(stripFrontmatter(raw));
}

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

const HEADING = /^H[1-6]$/;
const startsWithStrong = (el, pattern) => {
  if (el?.tagName !== 'P') return false;
  const first = [...el.childNodes].find((n) => n.nodeType !== 3 || n.textContent.trim());
  return first?.nodeName === 'STRONG' && pattern.test(first.textContent.trim());
};
const FASIT = /^fasit\b/i;
const TEACHER_NOTE = /^lærernotat\b/i;
// Et nytt spørsmål («**2. (F, 1 p)**»), en ny fasit eller et lærernotat avslutter en fasitblokk.
const BLOCK_START = /^(\d+[.)]|fasit\b|lærernotat\b|oppgave\b)/i;
const TEACHER_HEADING = /(hurtigreferanse for læreren|^lærernotat|^fasit\b|^løsningsforslag\b)/i;
// Et sitat som starter med f.eks. «**Lærernotat:**» avslutter også en fasitblokk.
const startsNewBlock = (el) =>
  startsWithStrong(el, BLOCK_START) || (el.tagName === 'BLOCKQUOTE' && startsWithStrong(el.firstElementChild, BLOCK_START));

function makeDetails(doc, className, summaryContent) {
  const details = doc.createElement('details');
  details.className = className;
  const summary = doc.createElement('summary');
  if (typeof summaryContent === 'string') summary.textContent = summaryContent;
  else summary.append(summaryContent);
  details.append(summary);
  return details;
}

/** Legger fasit og lærerstoff bak sammenleggbare <details>-elementer. */
export function collapseAnswers(root) {
  const doc = root.ownerDocument;

  for (const heading of [...root.querySelectorAll('h1, h2, h3, h4, h5, h6')]) {
    if (!TEACHER_HEADING.test(heading.textContent.trim()) || heading.closest('details')) continue;
    const level = Number(heading.tagName[1]);
    const details = makeDetails(doc, 'collapsible collapsible--teacher', '');
    heading.replaceWith(details);
    details.querySelector('summary').append(heading);
    let next = details.nextElementSibling;
    while (next && !(HEADING.test(next.tagName) && Number(next.tagName[1]) <= level)) {
      const current = next;
      next = next.nextElementSibling;
      details.append(current);
    }
  }

  for (const p of [...root.querySelectorAll('p')]) {
    if (p.closest('details')) continue;
    if (startsWithStrong(p, FASIT)) {
      const label = p.querySelector('strong').textContent.trim().replace(/:$/, '');
      const details = makeDetails(doc, 'collapsible collapsible--answer', `Vis ${label.charAt(0).toLowerCase()}${label.slice(1)}`);
      p.before(details);
      let next = p;
      while (next && !HEADING.test(next.tagName) && next.tagName !== 'HR' && !(next !== p && startsNewBlock(next))) {
        const current = next;
        next = next.nextElementSibling;
        details.append(current);
      }
    } else if (startsWithStrong(p, TEACHER_NOTE)) {
      const target = p.parentElement?.tagName === 'BLOCKQUOTE' && p.parentElement !== root ? p.parentElement : p;
      const details = makeDetails(doc, 'collapsible collapsible--teacher', 'Lærernotat');
      target.before(details);
      details.append(target);
    }
  }
}

/** Gir overskrifter unike id-er og returnerer innholdsfortegnelse for h2. */
export function addHeadingIds(root) {
  const used = new Set();
  const toc = [];
  for (const h of root.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
    let id = slugify(h.textContent);
    for (let i = 2; used.has(id); i++) id = `${slugify(h.textContent)}-${i}`;
    used.add(id);
    h.id = id;
    if (h.tagName === 'H2') toc.push({ id, text: h.textContent.trim() });
  }
  return toc;
}

/**
 * Gjør lenker og filnavn i innholdet om til interne ruter.
 * resolve(target) returnerer en hash-rute eller null hvis målet ikke finnes.
 */
const VIDEO_HOST = /^(https?:)?\/\/(www\.|m\.)?(youtube\.com|youtu\.be|vimeo\.com)\//i;

export function rewriteLinks(root, { resolve, imageUrl, currentRoute }) {
  for (const a of root.querySelectorAll('a[href]')) {
    const href = a.getAttribute('href');
    if (/^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith('//')) {
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      const isVideo = VIDEO_HOST.test(href);
      if (isVideo) a.classList.add('video-link');
      const hint = a.ownerDocument.createElement('span');
      hint.className = 'visually-hidden';
      hint.textContent = isVideo ? ' (video, åpnes i ny fane)' : ' (åpnes i ny fane)';
      a.append(hint);
    } else if (href.startsWith('#/')) {
      // Allerede en intern rute, f.eks. en lenke til et annet emne.
    } else if (href.startsWith('#')) {
      a.setAttribute('href', `${currentRoute}/${slugify(decodeURIComponent(href.slice(1)))}`);
    } else {
      const [file, anchor] = href.split('#');
      const route = resolve(decodeURIComponent(file));
      if (route) a.setAttribute('href', anchor ? `${route}/${slugify(decodeURIComponent(anchor))}` : route);
    }
  }

  for (const img of root.querySelectorAll('img[src]')) {
    const url = imageUrl(img.getAttribute('src'));
    if (url) img.src = url;
    img.loading = 'lazy';
    if (!img.hasAttribute('alt')) img.alt = '';
  }

  for (const code of root.querySelectorAll('code')) {
    if (code.closest('pre, a')) continue;
    const text = code.textContent.trim();
    if (!/^[\w./-]+\.(md|sql)$/i.test(text)) continue;
    const route = resolve(text);
    if (!route) continue;
    const a = code.ownerDocument.createElement('a');
    a.href = route;
    code.replaceWith(a);
    a.append(code);
  }
}

/** Gjør brede tabeller rullbare og legger til kopieringsknapp på kodeblokker. */
export function decorateBlocks(root) {
  const doc = root.ownerDocument;
  for (const table of root.querySelectorAll('table')) {
    const wrap = doc.createElement('div');
    wrap.className = 'table-wrap';
    wrap.tabIndex = 0;
    wrap.setAttribute('role', 'region');
    wrap.setAttribute('aria-label', 'Tabell, kan rulles sideveis');
    table.replaceWith(wrap);
    wrap.append(table);
  }
  for (const pre of root.querySelectorAll('pre')) {
    const button = doc.createElement('button');
    button.type = 'button';
    button.className = 'copy-button';
    button.textContent = 'Kopier';
    button.setAttribute('aria-label', 'Kopier koden');
    pre.append(button);
  }
}
