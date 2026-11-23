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
import { slugify as sharedSlugify, createSlugger, parseVideoUrl } from './slug.js';

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
  return sharedSlugify(text);
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
  const slug = createSlugger();
  const toc = [];
  for (const h of root.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
    const id = slug(h.textContent);
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

// ---------- Videoer ----------

const EMBED_URL = {
  // youtube-nocookie.com setter ikke sporingscookies før videoen spilles av.
  youtube: (id) => `https://www.youtube-nocookie.com/embed/${id}?autoplay=1&rel=0`,
  vimeo: (id) => `https://player.vimeo.com/video/${id}?autoplay=1&dnt=1`,
};
const THUMBNAIL_URL = {
  youtube: (id) => `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
};

/** Lager en «spill av»-flate. Selve spilleren lastes først når brukeren klikker (se embedVideo). */
export function videoPlayer(doc, url, title) {
  const video = parseVideoUrl(url);
  if (!video) return null;
  const wrap = doc.createElement('div');
  wrap.className = 'video-player';
  const button = doc.createElement('button');
  button.type = 'button';
  button.className = 'video-play';
  button.dataset.provider = video.provider;
  button.dataset.videoId = video.id;
  button.dataset.title = title;
  button.setAttribute('aria-label', `Spill av videoen «${title}» her på siden`);
  const thumb = THUMBNAIL_URL[video.provider];
  if (thumb) {
    const img = doc.createElement('img');
    img.src = thumb(video.id);
    img.alt = '';
    img.loading = 'lazy';
    img.decoding = 'async';
    button.append(img);
  }
  const icon = doc.createElement('span');
  icon.className = 'video-play-icon';
  icon.setAttribute('aria-hidden', 'true');
  const label = doc.createElement('span');
  label.className = 'video-play-label';
  label.setAttribute('aria-hidden', 'true');
  label.textContent = 'Spill av her';
  button.append(icon, label);
  wrap.append(button);
  return wrap;
}

/** Bytter «spill av»-knappen ut med den innebygde spilleren. */
export function embedVideo(button) {
  const { provider, videoId, title } = button.dataset;
  const src = EMBED_URL[provider]?.(videoId);
  if (!src) return null;
  const iframe = button.ownerDocument.createElement('iframe');
  iframe.src = src;
  iframe.title = title || 'Video';
  iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
  iframe.allowFullscreen = true;
  iframe.referrerPolicy = 'strict-origin-when-cross-origin';
  button.replaceWith(iframe);
  return iframe;
}

const DURATION = /(\d{1,2}:\d{2}(?::\d{2})?|ca\.\s*\d+\s*min)/i;

function chip(doc, text, modifier) {
  const span = doc.createElement('span');
  span.className = `chip${modifier ? ` chip--${modifier}` : ''}`;
  span.textContent = text;
  return span;
}

function fieldValue(li) {
  return li ? li.textContent.replace(/^[^:]*:\s*/, '').trim() : '';
}

/**
 * Gjør videolister om til videokort med innebygd spiller. Støtter to formater:
 *  - «### Tittel» etterfulgt av en punktliste med «**Lenke:** https://youtube…» (og gjerne Kanal/kilde og Nivå)
 *  - tabeller der første kolonne i hver rad er en lenke til en video
 * Må kjøres etter rewriteLinks, som merker videolenkene.
 */
export function enhanceVideos(root) {
  const doc = root.ownerDocument;

  for (const h3 of [...root.querySelectorAll('h3')]) {
    const list = h3.nextElementSibling;
    if (list?.tagName !== 'UL' || h3.closest('details')) continue;
    const items = [...list.children];
    const find = (pattern) => items.find((li) => pattern.test(li.querySelector('strong')?.textContent ?? ''));
    const link = find(/^lenke/i)?.querySelector('a.video-link');
    if (!link) continue;

    const player = videoPlayer(doc, link.getAttribute('href'), h3.textContent.trim());
    if (!player) continue;
    const card = doc.createElement('section');
    card.className = 'video-card';
    if (h3.id) card.setAttribute('aria-labelledby', h3.id);
    const body = doc.createElement('div');
    body.className = 'video-card-body';
    const chips = doc.createElement('p');
    chips.className = 'chips';
    const duration = fieldValue(find(/^kanal/i)).match(DURATION)?.[1];
    const level = fieldValue(find(/^nivå/i));
    if (duration) chips.append(chip(doc, `⏱ ${duration}`));
    if (level) chips.append(chip(doc, level, 'level'));
    h3.before(card);
    list.classList.add('video-details');
    body.append(h3, ...(chips.childNodes.length ? [chips] : []), list);
    card.append(player, body);
  }

  for (const table of [...root.querySelectorAll('table')]) {
    const rows = [...table.querySelectorAll('tbody tr')];
    const firstLink = (tr) => {
      const cell = tr.cells[0];
      const a = cell?.querySelector('a.video-link');
      return a && cell.textContent.trim() === a.textContent.trim() ? a : null;
    };
    if (!rows.length || !rows.every(firstLink)) continue;

    const grid = doc.createElement('ul');
    grid.className = 'video-grid';
    for (const tr of rows) {
      const a = firstLink(tr);
      const url = a.getAttribute('href');
      const title = a.textContent.trim();
      const tile = doc.createElement('li');
      tile.className = 'video-tile';
      const body = doc.createElement('div');
      body.className = 'video-tile-body';
      const heading = doc.createElement('p');
      heading.className = 'video-tile-title';
      heading.append(a);
      const urlLine = doc.createElement('p');
      urlLine.className = 'video-url';
      urlLine.textContent = url;
      body.append(heading, urlLine);
      const [, metaCell, ...rest] = tr.cells;
      if (metaCell) {
        const meta = doc.createElement('p');
        meta.className = 'chips';
        const text = metaCell.textContent.trim();
        const duration = text.match(DURATION)?.[1];
        meta.append(chip(doc, text.replace(/\s*·\s*\d{1,2}:\d{2}(?::\d{2})?\s*$/, '')));
        if (duration) meta.append(chip(doc, `⏱ ${duration}`));
        body.append(meta);
      }
      for (const cell of rest) {
        const p = doc.createElement('p');
        p.className = 'video-tile-desc';
        p.append(...cell.childNodes);
        body.append(p);
      }
      tile.append(videoPlayer(doc, url, title), body);
      grid.append(tile);
    }
    table.replaceWith(grid);
  }
}
