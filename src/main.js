import index from 'virtual:innhold';
import { renderMarkdown, collapseAnswers, addHeadingIds, rewriteLinks, decorateBlocks, highlight, enhanceVideos, embedVideo, videoPlayer } from './markdown.js';
import { createProgressStore, safeStorage, normalizeName, GUEST_NAME, MAX_NAME_LENGTH } from './progress.js';
import { icon } from './icons.js';
import { buildSearchIndex, search, highlightParts } from './search.js';
import { HERO_ILLUSTRATION } from './illustration.js';

const { site, courses } = index;

const markdownLoaders = import.meta.glob('/content/*/*.md', { query: '?raw', import: 'default' });
// Valgfri forsidetekst i content/forside.md.
const frontPage = Object.values(import.meta.glob('/content/forside.md', { query: '?raw', import: 'default', eager: true }))[0] ?? '';
const fileLoaders = import.meta.glob('/content/**/*.sql', { query: '?raw', import: 'default' });
const images = import.meta.glob('/content/**/*.{png,jpg,jpeg,gif,svg,webp,avif}', { query: '?url', import: 'default', eager: true });

const { storage, persistent } = safeStorage();
const progress = createProgressStore(storage, site.storageKey, { legacy: site.tidligereLagring ?? [] });
progress.migrateLegacy();

const STATUS_LABEL = { 'ikke-startet': 'Ikke startet', pagar: 'Pågår', fullfort: 'Fullført' };
const STATUS_ICON = { 'ikke-startet': '○', pagar: '◐', fullfort: '✓' };

const $ = (sel) => document.querySelector(sel);
const main = $('#main');
const nav = $('#topic-nav');
let currentView = null;
let currentCourse = null;
let currentTopicSlug = null;

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === false || value == null) continue;
    if (key === 'class') node.className = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? '' : value);
  }
  node.append(...children.flat().filter((c) => c != null && c !== false));
  return node;
}

// ---------- Ruter og progresjon ----------

const enc = encodeURIComponent;
const courseRoute = (c) => `#/emne/${enc(c.slug)}`;
const topicRoute = (c, slug, anchor) => `${courseRoute(c)}/tema/${enc(slug)}${anchor ? `/${enc(anchor)}` : ''}`;
const filesRoute = (c) => `${courseRoute(c)}/filer`;
const fileRoute = (c, path) => `${courseRoute(c)}/fil/${path.split('/').map(enc).join('/')}`;

// Progresjon lagres per emne og tema, f.eks. «datavarehus/02-samling-2».
const topicId = (c, slug) => `${c.slug}/${slug}`;
const topicStatus = (c, slug) => progress.getStatus(topicId(c, slug));

function stats(list) {
  const { started, completed } = progress.getProgress();
  const ids = list.flatMap((c) => c.topics.map((t) => topicId(c, t.slug)));
  const done = ids.filter((id) => completed.has(id)).length;
  const total = ids.length;
  const status = total && done === total ? 'fullfort' : ids.some((id) => started.has(id) || completed.has(id)) ? 'pagar' : 'ikke-startet';
  return { done, total, percent: total ? Math.round((done / total) * 100) : 0, status };
}

function nextUnfinished(course) {
  const { completed } = progress.getProgress();
  return course.topics.find((t) => !completed.has(topicId(course, t.slug)));
}

/** Hvor studenten bør fortsette: sist besøkte tema, ellers neste uferdige tema i det emnet, ellers første uferdige totalt. */
function continuePoint() {
  const { completed } = progress.getProgress();
  const last = progress.getLastVisited();
  if (last) {
    const [courseSlug, ...rest] = last.split('/');
    const course = courses.find((c) => c.slug === courseSlug);
    const topic = course?.topics.find((t) => t.slug === rest.join('/'));
    if (topic && !completed.has(last)) return { course, topic, resume: true };
    const next = course && nextUnfinished(course);
    if (next) return { course, topic: next, resume: true };
  }
  for (const course of courses) {
    const topic = nextUnfinished(course);
    if (topic) return { course, topic, resume: false };
  }
  return null;
}

function statusBadge(status) {
  return el('span', { class: `status status--${status}` }, el('span', { 'aria-hidden': 'true' }, STATUS_ICON[status]), ' ', STATUS_LABEL[status]);
}

function progressMeter(s, label) {
  return el('progress', { class: 'mini-progress', value: s.done, max: Math.max(s.total, 1), 'aria-label': label, 'aria-valuetext': `${s.done} av ${s.total} temaer fullført` });
}

// ---------- Emneikoner, kategorier og videoer ----------

// Fargetone per kategori (brukes på ikonflisene). Ukjente kategorier får standardfargen.
const CATEGORY_TONE = { 'Data og analyse': 'data', 'KI og agenter': 'ki', Utviklerverktøy: 'dev' };
const courseTone = (c) => CATEGORY_TONE[c.category] ?? 'default';
const categories = [...new Set(courses.map((c) => c.category).filter(Boolean))];

function courseIcon(c, size = 'md') {
  return el('span', { class: `course-icon course-icon--${size} tone--${courseTone(c)}`, 'aria-hidden': 'true' }, icon(c.icon ?? 'book'));
}

/** Alle videoer i et emne (eller alle emner), med emne og tema de hører til. */
function videosIn(list) {
  return list.flatMap((c) => c.topics.flatMap((t) => (t.videos ?? []).map((v) => ({ ...v, course: c, topic: t }))));
}
const allVideos = videosIn(courses);

/** Videokort for oversiktssider. Spilleren lastes først når brukeren klikker. */
function videoTile(v, { showSource = true } = {}) {
  const duration = v.meta.match(/(\d{1,2}:\d{2}(?::\d{2})?|ca\.\s*\d+\s*min)/i)?.[1];
  const source = v.meta.replace(/\s*·\s*(\d{1,2}:\d{2}(?::\d{2})?|ca\.\s*\d+\s*min)/i, '');
  return el('li', { class: 'video-tile', 'data-course': v.course.slug },
    videoPlayer(document, v.url, v.title),
    el('div', { class: 'video-tile-body' },
      el('p', { class: 'video-tile-title' },
        el('a', { href: v.url, target: '_blank', rel: 'noopener noreferrer', class: 'video-link' }, v.title, el('span', { class: 'visually-hidden' }, ' (video, åpnes i ny fane)'))),
      el('p', { class: 'video-url' }, v.url),
      el('p', { class: 'chips' },
        source ? el('span', { class: 'chip' }, source) : null,
        duration ? el('span', { class: 'chip' }, `⏱ ${duration}`) : null,
        v.level ? el('span', { class: 'chip chip--level' }, v.level) : null),
      showSource
        ? el('p', { class: 'video-tile-source' }, 'Fra ', el('a', { href: topicRoute(v.course, v.topic.slug, v.anchor) }, `${v.course.title} › ${v.topic.title}`))
        : el('p', { class: 'video-tile-source' }, el('a', { href: topicRoute(v.course, v.topic.slug, v.anchor) }, 'Les beskrivelsen →')),
    ),
  );
}

// ---------- Lenker mellom filer i samme emne ----------

function resolveTarget(course, target) {
  const clean = target.replace(/^\.?\//, '').replace(/^content\//, '').replace(new RegExp(`^${course.slug}/`), '');
  const base = clean.split('/').pop();
  if (/\.md$/i.test(base)) {
    const topic = course.topics.find((t) => t.file.toLowerCase() === base.toLowerCase());
    return topic ? topicRoute(course, topic.slug) : null;
  }
  const file = course.files.find((f) => f.path === clean) ?? course.files.find((f) => f.name.toLowerCase() === base.toLowerCase());
  return file ? fileRoute(course, file.path) : null;
}

function resolveImage(course, src) {
  if (/^([a-z]+:|\/\/|data:)/i.test(src)) return null;
  const parts = [];
  for (const part of `content/${course.slug}/${src.replace(/^\.?\//, '')}`.split('/')) {
    if (part === '..') parts.pop();
    else if (part && part !== '.') parts.push(part);
  }
  return images[`/${parts.join('/')}`] ?? null;
}

// ---------- Topptekst og meny ----------

function updateProgressUi() {
  const s = currentCourse ? stats([currentCourse]) : stats(courses);
  const bar = $('#progress-bar');
  bar.value = s.done;
  bar.max = Math.max(s.total, 1);
  bar.setAttribute('aria-valuetext', `${s.done} av ${s.total} temaer fullført`);
  $('#progress-label').textContent = currentCourse ? `Fremdrift i ${currentCourse.title}` : 'Fremdrift i alle emner';
  $('#progress-text').textContent = currentCourse
    ? `${s.done} av ${s.total} temaer – ${s.percent} %`
    : `Totalt: ${s.done} av ${s.total} temaer – ${s.percent} %`;
  $('#user-name').textContent = progress.getCurrentUser() ?? GUEST_NAME;
  renderNav();
}

function renderNav() {
  const hash = location.hash || '#/';
  nav.replaceChildren(
    el('ul', { class: 'nav-list' },
      el('li', {}, el('a', { href: '#/', class: 'nav-link', 'aria-current': hash === '#/' ? 'page' : false },
        el('span', { class: 'nav-icon', 'aria-hidden': 'true' }, icon('grid', { size: 18 })), el('span', { class: 'nav-title' }, 'Alle emner'))),
      el('li', {}, el('a', { href: '#/videoer', class: 'nav-link', 'aria-current': hash === '#/videoer' ? 'page' : false },
        el('span', { class: 'nav-icon', 'aria-hidden': 'true' }, icon('play', { size: 18 })), el('span', { class: 'nav-title' }, 'Alle videoer'),
        el('span', { class: 'nav-count' }, String(allVideos.length)))),
    ),
    el('h2', { class: 'nav-heading', id: 'nav-courses-heading' }, 'Emner'),
    el('ul', { class: 'nav-list', 'aria-labelledby': 'nav-courses-heading' },
      courses.map((c) => {
        const s = stats([c]);
        const isCurrent = c === currentCourse;
        return el('li', {},
          el('a', {
            href: courseRoute(c),
            class: `nav-link nav-link--course nav-link--${s.status}`,
            'aria-current': hash === courseRoute(c) ? 'page' : false,
          },
            courseIcon(c, 'sm'),
            el('span', { class: 'nav-title' }, c.title),
            el('span', { class: 'nav-count' }, el('span', { 'aria-hidden': 'true' }, s.status === 'fullfort' ? '✓' : `${s.done}/${s.total}`), el('span', { class: 'visually-hidden' }, ` (${s.done} av ${s.total} fullført)`)),
          ),
          isCurrent ? renderCourseNav(c) : null,
        );
      }),
    ),
  );
}

function renderCourseNav(c) {
  return el('ol', { class: 'nav-sublist', 'aria-label': `Temaer i ${c.title}` },
    c.topics.map((t) => {
      const status = topicStatus(c, t.slug);
      return el('li', {},
        el('a', { href: topicRoute(c, t.slug), class: `nav-link nav-link--${status}`, 'aria-current': t.slug === currentTopicSlug ? 'page' : false },
          el('span', { class: 'nav-icon', 'aria-hidden': 'true' }, STATUS_ICON[status]),
          el('span', { class: 'nav-title' }, t.title),
          el('span', { class: 'visually-hidden' }, ` (${STATUS_LABEL[status]})`),
        ),
      );
    }),
    c.files.length
      ? el('li', {}, el('a', { href: filesRoute(c), class: 'nav-link nav-link--files', 'aria-current': (location.hash || '').startsWith(`${courseRoute(c)}/fil`) ? 'page' : false },
          el('span', { class: 'nav-icon', 'aria-hidden': 'true' }, '📄'), el('span', { class: 'nav-title' }, 'Case-filer (SQL)')))
      : null,
  );
}

// ---------- Visninger ----------

function setPage(title, ...content) {
  document.title = title ? `${title} – ${site.title}` : site.title;
  main.replaceChildren(...content.filter((c) => c != null && c !== false));
  // Myk overgang mellom sider (slås av hvis brukeren har bedt om redusert bevegelse).
  main.classList.remove('view-enter');
  void main.offsetWidth;
  main.classList.add('view-enter');
  closeMenu();
  closeOverlays();
  window.scrollTo(0, 0);
  const heading = main.querySelector('h1');
  if (heading) {
    heading.tabIndex = -1;
    heading.focus({ preventScroll: true });
  }
}

/** Sidetype på <body>, slik at f.eks. forsiden kan bruke hele bredden uten sidemeny. */
function setViewType(type) {
  document.body.dataset.view = type;
}

function breadcrumb(...items) {
  return el('nav', { class: 'breadcrumb', 'aria-label': 'Du er her' },
    el('ol', {},
      el('li', {}, el('a', { href: '#/' }, 'Alle emner')),
      items.map(([text, href]) => el('li', {}, href ? el('a', { href }, text) : el('span', { 'aria-current': 'page' }, text))),
    ),
  );
}

function renderFrontPageText() {
  if (!frontPage.trim()) return null;
  const section = el('section', { class: 'prose intro', 'aria-label': 'Om portalen' });
  section.innerHTML = renderMarkdown(frontPage);
  // Overskriftene flyttes ett nivå ned, siden sidens h1 allerede er nettstedets tittel.
  for (const h of [...section.querySelectorAll('h1, h2, h3, h4, h5')].reverse()) {
    const lower = el(`h${Number(h.tagName[1]) + 1}`, {}, ...h.childNodes);
    h.replaceWith(lower);
  }
  rewriteLinks(section, { resolve: () => null, imageUrl: () => null, currentRoute: '#/' });
  return section;
}

function heroStat(value, label) {
  return el('div', { class: 'hero-stat' }, el('dt', {}, label), el('dd', {}, value));
}

function courseCard(c) {
  const s = stats([c]);
  const nextInCourse = nextUnfinished(c);
  const videoCount = videosIn([c]).length;
  return el('li', { class: `course-card card--${s.status} tone--${courseTone(c)}`, 'data-category': c.category ?? '' },
    el('div', { class: 'course-card-top' },
      courseIcon(c, 'lg'),
      el('div', { class: 'course-card-labels' },
        c.category ? el('span', { class: 'course-category' }, c.category) : null,
        statusBadge(s.status)),
    ),
    el('h3', { class: 'card-title' }, el('a', { href: courseRoute(c) }, c.title)),
    c.description ? el('p', { class: 'card-desc' }, c.description) : null,
    el('p', { class: 'course-facts' },
      el('span', {}, icon('doc', { size: 16 }), `${c.topics.length} temaer`),
      videoCount ? el('span', {}, icon('play', { size: 16 }), `${videoCount} videoer`) : null),
    el('div', { class: 'course-progress' },
      progressMeter(s, `Fremdrift i ${c.title}`),
      el('span', { class: 'course-progress-text' }, `${s.percent} %`)),
    nextInCourse
      ? el('p', { class: 'card-next' }, el('a', { href: topicRoute(c, nextInCourse.slug) }, s.status === 'ikke-startet' ? 'Start: ' : 'Neste: ', nextInCourse.title, ' →'))
      : el('p', { class: 'card-next card-next--done' }, '✓ Fullført'),
  );
}

/** Knapper som filtrerer en liste. items: [{ value, label, count }]. onChange(value) kalles ved klikk. */
function filterBar(label, items, onChange, selected = '') {
  const bar = el('div', { class: 'filter-bar', role: 'group', 'aria-label': label });
  const buttons = items.map((item) =>
    el('button', {
      type: 'button',
      class: 'filter-chip',
      'aria-pressed': String(item.value === selected),
      onclick: () => {
        for (const b of buttons) b.setAttribute('aria-pressed', String(b === buttons[items.indexOf(item)]));
        onChange(item.value);
      },
    }, item.label, el('span', { class: 'filter-count' }, String(item.count))));
  bar.append(...buttons);
  return bar;
}

/** Viser bare elementene som passer, med en kort inn-animasjon på dem som blir synlige. */
function applyFilter(items, predicate) {
  let shown = 0;
  for (const item of items) {
    const visible = predicate(item);
    item.hidden = !visible;
    if (visible) {
      shown++;
      item.classList.remove('item-enter');
      void item.offsetWidth;
      item.classList.add('item-enter');
    }
  }
  return shown;
}

function renderHome() {
  setViewType('home');
  const next = continuePoint();
  const total = stats(courses);
  const topicCount = courses.reduce((n, c) => n + c.topics.length, 0);
  const grid = el('ul', { class: 'course-grid' }, courses.map(courseCard));
  const scrollToCourses = () => document.getElementById('courses-title')?.scrollIntoView({ behavior: 'smooth', block: 'start' });

  setPage(
    '',
    el('section', { class: 'hero-home', 'aria-labelledby': 'home-title' },
      el('div', { class: 'hero-bg', 'aria-hidden': 'true' }),
      el('div', { class: 'hero-inner' },
        el('div', { class: 'hero-text' },
          el('p', { class: 'eyebrow' }, el('span', { class: 'eyebrow-dot', 'aria-hidden': 'true' }), 'Opplæringsportal for studenter og utviklere'),
          el('h1', { id: 'home-title' }, site.title),
          site.description ? el('p', { class: 'lead' }, site.description) : null,
          el('div', { class: 'hero-actions' },
            next
              ? el('a', { class: 'button button--primary button--lg', href: topicRoute(next.course, next.topic.slug) },
                  next.resume ? 'Fortsett der du slapp' : 'Start læringen', icon('arrow-right', { size: 18 }))
              : null,
            el('button', { type: 'button', class: 'button button--ghost button--lg', onclick: scrollToCourses }, 'Se alle emner'),
            allVideos.length ? el('a', { class: 'button button--ghost button--lg', href: '#/videoer' }, icon('play', { size: 18 }), 'Videoer') : null,
          ),
          next
            ? el('p', { class: 'hero-next' }, next.resume ? 'Neste tema: ' : 'Første tema: ', el('strong', {}, next.topic.title), ` · ${next.course.title}`)
            : total.total ? el('p', { class: 'done-message' }, '🎉 Du har fullført alle temaene i alle emnene. Godt jobbet!') : null,
          el('dl', { class: 'hero-stats' },
            heroStat(String(courses.length), 'Emner'),
            heroStat(String(topicCount), 'Temaer'),
            heroStat(String(allVideos.length), 'Videoer'),
            heroStat(`${total.percent} %`, 'Din fremdrift')),
        ),
        (() => {
          const art = el('div', { class: 'hero-art' });
          art.innerHTML = HERO_ILLUSTRATION;
          return art;
        })(),
      ),
    ),
    el('section', { class: 'section', 'aria-labelledby': 'courses-title' },
      el('div', { class: 'section-head' },
        el('div', {},
          el('h2', { id: 'courses-title' }, 'Opplæringsmoduler'),
          el('p', { class: 'section-lead' }, 'Velg et emne for å se temaene. Fremdriften vises på hvert kort.')),
        categories.length > 1
          ? filterBar('Filtrer emner etter kategori',
              [{ value: '', label: 'Alle', count: courses.length },
               ...categories.map((cat) => ({ value: cat, label: cat, count: courses.filter((c) => c.category === cat).length }))],
              (cat) => {
                const shown = applyFilter([...grid.children], (li) => !cat || li.dataset.category === cat);
                announce(`${shown} emner vises.`);
              })
          : null,
      ),
      courses.length ? grid : el('p', {}, 'Ingen emner funnet. Lag en mappe i content/ med minst én .md-fil.'),
    ),
    frontPage.trim() ? el('div', { class: 'section about-card' }, renderFrontPageText()) : null,
    renderProgressPanel(),
  );
}

function renderCourse(course) {
  setViewType('course');
  const next = nextUnfinished(course);
  const { started } = progress.getProgress();
  const s = stats([course]);
  const videos = videosIn([course]);
  const videoTopic = course.topics.find((t) => t.videos?.length && /video/i.test(t.slug));

  setPage(
    course.title,
    breadcrumb([course.title]),
    el('section', { class: `course-hero tone--${courseTone(course)}`, 'aria-labelledby': 'course-title' },
      courseIcon(course, 'xl'),
      el('div', { class: 'course-hero-text' },
        course.category ? el('p', { class: 'eyebrow' }, course.category) : null,
        el('h1', { id: 'course-title' }, course.title),
        course.description ? el('p', { class: 'lead' }, course.description) : null,
        el('p', { class: 'chips' },
          el('span', { class: 'chip' }, `${course.topics.length} temaer`),
          videos.length ? el('span', { class: 'chip' }, `▶ ${videos.length} videoer`) : null,
          el('span', { class: 'chip' }, `${s.done} av ${s.total} fullført`)),
        el('div', { class: 'course-progress course-progress--wide' },
          progressMeter(s, `Fremdrift i ${course.title}`),
          el('span', { class: 'course-progress-text' }, `${s.percent} %`)),
        next
          ? el('a', { class: 'button button--primary', href: topicRoute(course, next.slug) }, started.has(topicId(course, next.slug)) ? 'Fortsett: ' : 'Start: ', next.title, icon('arrow-right', { size: 18 }))
          : el('p', { class: 'done-message' }, '🎉 Du har fullført alle temaene i dette emnet. Godt jobbet!'),
      ),
    ),
    el('section', { class: 'section', 'aria-labelledby': 'cards-title' },
      el('h2', { id: 'cards-title' }, 'Temaer'),
      el('ol', { class: 'topic-grid' },
        course.topics.map((t, i) => {
          const status = topicStatus(course, t.slug);
          const parts = (t.headings ?? []).filter((h) => h.level === 2).length;
          return el('li', { class: `topic-card card--${status}` },
            el('span', { class: 'topic-number', 'aria-hidden': 'true' }, status === 'fullfort' ? '✓' : String(i + 1)),
            el('div', { class: 'topic-card-body' },
              el('h3', { class: 'card-title' }, el('a', { href: topicRoute(course, t.slug) }, el('span', { class: 'visually-hidden' }, `Tema ${i + 1}: `), t.title)),
              t.description ? el('p', { class: 'card-desc' }, t.description) : null,
              el('p', { class: 'chips' },
                statusBadge(status),
                parts ? el('span', { class: 'chip' }, `${parts} deler`) : null,
                t.videos?.length ? el('span', { class: 'chip' }, `▶ ${t.videos.length} videoer`) : null),
            ),
          );
        })),
    ),
    videos.length
      ? el('section', { class: 'section', 'aria-labelledby': 'course-videos-title' },
          el('div', { class: 'section-head' },
            el('div', {},
              el('h2', { id: 'course-videos-title' }, 'Opplæringsvideoer'),
              el('p', { class: 'section-lead' }, 'Et utvalg. Klikk på bildet for å spille av her, eller på tittelen for å åpne videoen på YouTube.')),
            el('a', { class: 'button', href: `#/videoer/${enc(course.slug)}` }, `Alle ${videos.length} videoer`, icon('arrow-right', { size: 16 }))),
          el('ul', { class: 'video-grid' }, videos.slice(0, 3).map((v) => videoTile(v, { showSource: false }))),
          videoTopic ? el('p', {}, el('a', { href: topicRoute(course, videoTopic.slug) }, `Les beskrivelsene i «${videoTopic.title}» →`)) : null,
        )
      : null,
    course.files.length
      ? el('p', { class: 'panel' }, 'Dette emnet har ', el('a', { href: filesRoute(course) }, `${course.files.length} case-filer (SQL)`), ' du kan lese og laste ned.')
      : null,
  );
}

function renderVideos(selectedSlug = '') {
  setViewType('videos');
  const selected = courses.find((c) => c.slug === selectedSlug) ? selectedSlug : '';
  const grid = el('ul', { class: 'video-grid video-grid--all' }, allVideos.map((v) => videoTile(v)));
  const filterInput = el('input', { type: 'search', id: 'video-filter', class: 'text-input', placeholder: 'Filtrer på tittel, kanal eller tema …', autocomplete: 'off' });
  const counter = el('p', { class: 'result-count', 'aria-live': 'polite' });
  let course = selected;

  const update = () => {
    const words = filterInput.value.toLocaleLowerCase('nb').split(/\s+/).filter(Boolean);
    const shown = applyFilter([...grid.children], (li) => {
      if (course && li.dataset.course !== course) return false;
      const text = li.textContent.toLocaleLowerCase('nb');
      return words.every((w) => text.includes(w));
    });
    counter.textContent = `Viser ${shown} av ${allVideos.length} videoer`;
  };
  filterInput.addEventListener('input', update);

  setPage(
    'Videoer',
    breadcrumb(['Videoer']),
    el('section', { class: 'page-hero', 'aria-labelledby': 'videos-title' },
      el('p', { class: 'eyebrow' }, 'Opplæringsvideoer'),
      el('h1', { id: 'videos-title' }, 'Alle videoer'),
      el('p', { class: 'lead' }, `${allVideos.length} utvalgte videoer fra alle emnene. Alle lenker er kontrollert. Klikk på bildet for å spille av her på siden, eller på tittelen for å åpne videoen i en ny fane.`),
    ),
    el('div', { class: 'filter-panel' },
      el('label', { for: 'video-filter', class: 'visually-hidden' }, 'Filtrer videoene'),
      filterInput,
      filterBar('Filtrer videoer etter emne',
        [{ value: '', label: 'Alle emner', count: allVideos.length },
         ...courses.filter((c) => videosIn([c]).length).map((c) => ({ value: c.slug, label: c.title.replace(/\s*\(.*\)$/, ''), count: videosIn([c]).length }))],
        (value) => {
          course = value;
          history.replaceState(null, '', value ? `#/videoer/${enc(value)}` : '#/videoer');
          update();
        }, selected),
    ),
    counter,
    grid,
  );
  update();
}

function renderProgressPanel() {
  const fileInput = el('input', { type: 'file', accept: 'application/json,.json', class: 'visually-hidden', id: 'import-file', tabindex: '-1', 'aria-hidden': 'true', onchange: onImportFile });
  return el('section', { class: 'panel', 'aria-labelledby': 'panel-title' },
    el('h2', { id: 'panel-title' }, 'Din progresjon'),
    el('p', {}, 'Progresjonen lagres bare i denne nettleseren, per navn. Bytter du maskin, kan du eksportere den til en fil og importere den igjen.'),
    persistent ? null : el('p', { class: 'warning', role: 'note' }, 'Nettleseren tillater ikke lagring, så progresjonen forsvinner når du lukker siden.'),
    el('div', { class: 'button-row' },
      el('button', { type: 'button', class: 'button', onclick: () => openUserDialog(false) }, 'Bytt bruker'),
      el('button', { type: 'button', class: 'button', onclick: exportProgress }, 'Eksporter (JSON)'),
      el('button', { type: 'button', class: 'button', onclick: () => fileInput.click() }, 'Importer (JSON)'),
      el('button', { type: 'button', class: 'button button--danger', onclick: resetProgress }, 'Nullstill min progresjon'),
    ),
    fileInput,
  );
}

function completionButton(course, slug) {
  const done = topicStatus(course, slug) === 'fullfort';
  return el('button', {
    type: 'button',
    class: `button complete-button${done ? ' is-done' : ''}`,
    'aria-pressed': done ? 'true' : 'false',
    onclick: (event) => {
      const nowDone = topicStatus(course, slug) !== 'fullfort';
      progress.setCompleted(topicId(course, slug), nowDone);
      const clickedFooter = event.currentTarget.closest('.topic-footer') !== null;
      for (const b of main.querySelectorAll('.complete-button')) b.replaceWith(completionButton(course, slug));
      main.querySelector(clickedFooter ? '.topic-footer .complete-button' : '.topic-header .complete-button')?.focus();
      main.querySelector('.topic-header .status')?.replaceWith(statusBadge(topicStatus(course, slug)));
      updateProgressUi();
      announce(nowDone ? 'Temaet er markert som fullført.' : 'Temaet er ikke lenger markert som fullført.');
    },
  }, done ? '✓ Fullført – klikk for å angre' : 'Marker som fullført');
}

function scrollToSection(id) {
  const target = id ? document.getElementById(id) : null;
  if (!target) return;
  for (let d = target.closest('details'); d; d = d.parentElement?.closest('details')) d.open = true;
  target.scrollIntoView({ block: 'start' });
  target.tabIndex = -1;
  target.focus({ preventScroll: true });
}

async function renderTopic(course, slug, sectionId) {
  const index = course.topics.findIndex((t) => t.slug === slug);
  const topic = course.topics[index];
  const loader = topic && markdownLoaders[`/content/${course.slug}/${topic.file}`];
  if (!loader) return renderNotFound();

  const viewKey = `tema:${topicId(course, slug)}`;
  if (currentView === viewKey) return scrollToSection(sectionId);

  main.setAttribute('aria-busy', 'true');
  const raw = await loader();
  const article = el('div', { class: 'prose' });
  article.innerHTML = renderMarkdown(raw);
  if (!article.querySelector('h1')) article.prepend(el('h1', {}, topic.title));
  const toc = addHeadingIds(article);
  collapseAnswers(article);
  rewriteLinks(article, { resolve: (t) => resolveTarget(course, t), imageUrl: (s) => resolveImage(course, s), currentRoute: topicRoute(course, slug) });
  enhanceVideos(article);
  decorateBlocks(article);

  progress.markStarted(topicId(course, slug));
  const prev = course.topics[index - 1];
  const next = course.topics[index + 1];
  const relatedFiles = course.files.filter((f) => topic.files.includes(f.path));

  setViewType('topic');
  setPage(
    topic.title,
    breadcrumb([course.title, courseRoute(course)], [topic.title]),
    el('article', { class: 'topic', 'aria-labelledby': article.querySelector('h1').id || null },
      el('div', { class: 'topic-header' },
        el('p', { class: 'topic-meta' },
          courseIcon(course, 'sm'),
          el('span', {}, `Tema ${index + 1} av ${course.topics.length}`),
          statusBadge(topicStatus(course, slug))),
        completionButton(course, slug),
      ),
      toc.length > 2
        ? el('details', { class: 'toc' },
            el('summary', {}, 'Innhold på denne siden'),
            el('ol', {}, toc.map((h) => el('li', {}, el('a', { href: `${topicRoute(course, slug)}/${h.id}` }, h.text)))))
        : null,
      article,
      relatedFiles.length
        ? el('aside', { class: 'panel', 'aria-labelledby': 'related-title' },
            el('h2', { id: 'related-title' }, 'Case-filer brukt i dette temaet'),
            el('ul', {}, relatedFiles.map((f) => el('li', {}, el('a', { href: fileRoute(course, f.path) }, el('code', {}, f.path)), f.title ? ` – ${f.title}` : ''))))
        : null,
      el('div', { class: 'topic-footer' }, completionButton(course, slug)),
      el('nav', { class: 'pager', 'aria-label': 'Forrige og neste tema' },
        prev ? el('a', { class: 'pager-link pager-link--prev', href: topicRoute(course, prev.slug), rel: 'prev' }, el('span', { class: 'pager-label' }, '← Forrige'), el('span', {}, prev.title)) : el('span'),
        next ? el('a', { class: 'pager-link pager-link--next', href: topicRoute(course, next.slug), rel: 'next' }, el('span', { class: 'pager-label' }, 'Neste →'), el('span', {}, next.title))
             : el('a', { class: 'pager-link pager-link--next', href: courseRoute(course) }, el('span', { class: 'pager-label' }, 'Tilbake til'), el('span', {}, course.title)),
      ),
    ),
  );
  main.removeAttribute('aria-busy');
  currentView = viewKey;
  if (sectionId) scrollToSection(sectionId);
}

function renderFileList(course) {
  setViewType('course');
  setPage(
    `Case-filer – ${course.title}`,
    breadcrumb([course.title, courseRoute(course)], ['Case-filer']),
    el('h1', {}, 'Case-filer (SQL)'),
    el('p', { class: 'lead' }, 'Skriptene som brukes i emnet. Åpne en fil for å lese den med syntaksutheving, kopiere den eller laste den ned.'),
    el('ul', { class: 'file-list' },
      course.files.map((f) => {
        const usedIn = course.topics.filter((t) => t.files.includes(f.path));
        return el('li', { class: 'card' },
          el('h2', { class: 'card-title' }, el('a', { href: fileRoute(course, f.path) }, el('code', {}, f.path))),
          f.title ? el('p', { class: 'card-desc' }, el('strong', {}, f.title), f.description ? ` – ${f.description}` : '') : null,
          usedIn.length ? el('p', { class: 'card-meta' }, 'Brukes i: ', usedIn.map((t) => t.title).join(', ')) : null,
        );
      }),
    ),
  );
}

async function renderFile(course, path) {
  const file = course.files.find((f) => f.path === path);
  const loader = file && fileLoaders[`/content/${course.slug}/${file.path}`];
  if (!loader) return renderNotFound();
  const text = await loader();
  const usedIn = course.topics.filter((t) => t.files.includes(file.path));
  const code = el('code', { class: 'hljs language-sql' });
  code.innerHTML = highlight(text, 'sql');

  setViewType('course');
  setPage(
    file.name,
    breadcrumb([course.title, courseRoute(course)], ['Case-filer', filesRoute(course)], [file.name]),
    el('h1', {}, el('code', {}, file.path)),
    file.title ? el('p', { class: 'lead' }, file.title) : null,
    file.description ? el('p', {}, file.description) : null,
    usedIn.length ? el('p', {}, 'Brukes i: ', usedIn.flatMap((t, i) => [i ? ', ' : '', el('a', { href: topicRoute(course, t.slug) }, t.title)])) : null,
    el('div', { class: 'button-row' },
      el('button', { type: 'button', class: 'button button--primary', onclick: () => downloadText(file.name, text, 'application/sql') }, 'Last ned ', file.name),
      el('button', { type: 'button', class: 'button', onclick: () => copyText(text) }, 'Kopier alt'),
    ),
    el('pre', { class: 'code-block code-block--file', tabindex: '0', 'aria-label': `Innholdet i ${file.name}` }, code),
  );
}

function renderNotFound() {
  setViewType('other');
  setPage('Fant ikke siden', el('h1', {}, 'Fant ikke siden'), el('p', {}, 'Emnet, temaet eller filen finnes ikke lenger.'), el('p', {}, el('a', { href: '#/' }, 'Gå til forsiden')));
}

// ---------- Ruting ----------
// #/                                  alle emner
// #/videoer[/<emne>]                  alle videoer, eventuelt filtrert på emne
// #/emne/<emne>                       emnets forside
// #/emne/<emne>/tema/<tema>[/<anker>] et tema
// #/emne/<emne>/filer                 case-filer
// #/emne/<emne>/fil/<sti>             én fil

async function route() {
  let parts;
  try {
    parts = (location.hash || '#/').slice(2).split('/').map(decodeURIComponent);
  } catch {
    parts = ['ugyldig'];
  }
  const course = parts[0] === 'emne' ? courses.find((c) => c.slug === parts[1]) : null;
  const sub = parts[2];
  currentCourse = course ?? null;
  currentTopicSlug = sub === 'tema' ? parts[3] : null;
  if (sub !== 'tema') currentView = null;

  try {
    if (!parts[0]) renderHome();
    else if (parts[0] === 'videoer') renderVideos(parts[1]);
    else if (!course) renderNotFound();
    else if (!sub) renderCourse(course);
    else if (sub === 'tema') await renderTopic(course, parts[3], parts[4]);
    else if (sub === 'filer') renderFileList(course);
    else if (sub === 'fil') await renderFile(course, parts.slice(3).join('/'));
    else renderNotFound();
  } catch (error) {
    console.error(error);
    main.removeAttribute('aria-busy');
    setViewType('other');
    setPage('Feil', el('h1', {}, 'Noe gikk galt'), el('p', {}, 'Innholdet kunne ikke lastes. Prøv å laste siden på nytt.'));
  }
  updateProgressUi();
  updateQuickNav();
}

// ---------- Hjelpere ----------

function announce(message) {
  const region = $('#announcer');
  region.textContent = '';
  setTimeout(() => (region.textContent = message), 50);
}

async function copyText(text, button) {
  try {
    await navigator.clipboard.writeText(text);
    announce('Kopiert til utklippstavlen.');
    if (button) {
      button.textContent = 'Kopiert!';
      setTimeout(() => (button.textContent = 'Kopier'), 1500);
    }
  } catch {
    announce('Kunne ikke kopiere. Marker teksten og kopier manuelt.');
  }
}

function downloadText(name, text, type) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const a = el('a', { href: url, download: name });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function exportProgress() {
  const data = progress.exportData();
  const name = normalizeName(data.navn || GUEST_NAME).toLocaleLowerCase('nb').replace(/[^a-z0-9æøå]+/g, '-');
  downloadText(`progresjon-${name}.json`, JSON.stringify(data, null, 2), 'application/json');
  announce('Progresjonen er lastet ned.');
}

async function onImportFile(event) {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;
  try {
    const name = progress.importData(JSON.parse(await file.text()));
    currentView = null;
    await route();
    announce(`Progresjonen til ${name} er importert.`);
  } catch (error) {
    alert(error instanceof SyntaxError ? 'Filen er ikke gyldig JSON.' : error.message);
  }
}

function resetProgress() {
  const name = progress.getCurrentUser() ?? GUEST_NAME;
  if (!confirm(`Vil du nullstille all progresjon for ${name}, i alle emner? Dette kan ikke angres.`)) return;
  progress.reset();
  currentView = null;
  route();
  announce('Progresjonen er nullstilt.');
}

// ---------- Brukerdialog ----------

const dialog = $('#user-dialog');
const nameInput = $('#user-name-input');
nameInput.maxLength = MAX_NAME_LENGTH;
let dialogIsFirstVisit = false;

function openUserDialog(firstVisit) {
  dialogIsFirstVisit = firstVisit;
  $('#user-dialog-title').textContent = firstVisit ? 'Velkommen!' : 'Bytt bruker';
  $('#user-dialog-intro').textContent = firstVisit
    ? 'Skriv inn navnet ditt, så husker nettleseren hvilke temaer du har fullført. Ingen passord, og ingenting sendes noe sted.'
    : 'Velg en eksisterende bruker eller skriv inn et nytt navn.';
  $('#user-dialog-cancel').textContent = firstVisit ? `Fortsett som ${GUEST_NAME.toLowerCase()}` : 'Avbryt';
  nameInput.value = '';
  $('#user-dialog-error').textContent = '';
  const users = progress.listUsers();
  const list = $('#existing-users');
  list.replaceChildren(...users.map((u) => el('li', {}, el('button', { type: 'button', class: 'button button--small', onclick: () => chooseUser(u) }, u))));
  $('#existing-users-section').hidden = users.length === 0;
  dialog.showModal();
  nameInput.focus();
}

function chooseUser(name) {
  progress.setCurrentUser(name);
  dialog.close();
  currentView = null;
  route();
  announce(`Du er nå logget inn som ${progress.getCurrentUser()}.`);
}

$('#user-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const name = normalizeName(nameInput.value);
  if (!name) {
    $('#user-dialog-error').textContent = 'Skriv inn et navn, eller velg en bruker fra listen.';
    nameInput.focus();
    return;
  }
  chooseUser(name);
});

$('#user-dialog-cancel').addEventListener('click', () => dialog.close('avbrutt'));
dialog.addEventListener('close', () => {
  if (dialogIsFirstVisit && !progress.getCurrentUser()) chooseUser(GUEST_NAME);
});

// ---------- Mobilmeny ----------

const menuButton = $('#menu-button');
const sidebar = $('#sidebar');

function closeMenu() {
  if (!document.body.classList.contains('menu-open')) return;
  document.body.classList.remove('menu-open');
  menuButton.setAttribute('aria-expanded', 'false');
}

menuButton.addEventListener('click', () => {
  const open = !document.body.classList.contains('menu-open');
  document.body.classList.toggle('menu-open', open);
  menuButton.setAttribute('aria-expanded', String(open));
  if (open) sidebar.querySelector('a')?.focus();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && document.body.classList.contains('menu-open')) {
    closeMenu();
    menuButton.focus();
  }
});

$('#sidebar-backdrop').addEventListener('click', closeMenu);

// ---------- Søk ----------

const searchBox = $('.search');
const searchInput = $('#search-input');
const searchResults = $('#search-results');
const searchStatus = $('#search-status');
const searchEntries = buildSearchIndex(courses, { course: courseRoute, topic: topicRoute });
const SEARCH_ICON = { tema: 'doc', seksjon: 'hash', video: 'play' };
let searchTimer = null;

function markedText(text, query) {
  return highlightParts(text, query).map((p) => (p.match ? el('mark', {}, p.text) : p.text));
}

function hideSearch() {
  searchResults.hidden = true;
  searchInput.setAttribute('aria-expanded', 'false');
}

function renderSearch() {
  const query = searchInput.value.trim();
  if (!query) {
    hideSearch();
    searchStatus.textContent = '';
    return;
  }
  const groups = search(searchEntries, query);
  const count = groups.reduce((n, g) => n + g.total, 0);
  searchResults.replaceChildren(
    ...(groups.length
      ? groups.map((g) =>
          el('div', { class: 'search-group' },
            el('p', { class: 'search-group-title', id: `search-group-${g.type}` }, g.label,
              g.total > g.items.length ? el('span', { class: 'search-more' }, ` · viser ${g.items.length} av ${g.total}`) : null),
            el('ul', { 'aria-labelledby': `search-group-${g.type}` },
              g.items.map((item) =>
                el('li', {},
                  el('a', { href: item.href, class: 'search-hit' },
                    el('span', { class: `search-hit-icon type--${item.type}`, 'aria-hidden': 'true' }, icon(item.type === 'emne' ? item.icon ?? 'book' : SEARCH_ICON[item.type], { size: 18 })),
                    el('span', { class: 'search-hit-text' },
                      el('span', { class: 'search-hit-title' }, markedText(item.title, query)),
                      item.sub ? el('span', { class: 'search-hit-sub' }, item.sub) : null)))))))
      : [el('p', { class: 'search-empty' }, `Ingen treff på «${query}». Prøv et annet ord.`)]),
  );
  searchResults.hidden = false;
  searchInput.setAttribute('aria-expanded', 'true');
  searchStatus.textContent = count ? `${count} treff. Bruk pil ned for å gå til treffene.` : 'Ingen treff.';
}

function moveInResults(step) {
  const hits = [...searchResults.querySelectorAll('.search-hit')];
  if (!hits.length) return;
  const i = hits.indexOf(document.activeElement);
  const next = i === -1 ? (step > 0 ? 0 : hits.length - 1) : i + step;
  if (next < 0) searchInput.focus();
  else hits[Math.min(next, hits.length - 1)].focus();
}

searchInput.addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(renderSearch, 80);
});
searchInput.addEventListener('focus', () => {
  if (searchInput.value.trim()) renderSearch();
});
searchBox.addEventListener('keydown', (event) => {
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    moveInResults(1);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    moveInResults(-1);
  } else if (event.key === 'Escape') {
    if (searchResults.hidden) searchInput.value = '';
    hideSearch();
    searchInput.focus();
  } else if (event.key === 'Enter' && event.target === searchInput) {
    clearTimeout(searchTimer);
    renderSearch();
    const first = searchResults.querySelector('.search-hit');
    if (first) {
      event.preventDefault();
      first.click();
    }
  }
});
searchResults.addEventListener('click', (event) => {
  if (event.target.closest('.search-hit')) closeOverlays();
});
document.addEventListener('keydown', (event) => {
  // «/» hopper til søkefeltet, som på GitHub og mange dokumentasjonssider.
  if (event.key !== '/' || event.ctrlKey || event.metaKey || event.altKey) return;
  if (event.target.closest('input, textarea, select, [contenteditable="true"]') || document.querySelector('dialog[open]')) return;
  event.preventDefault();
  searchInput.focus();
  searchInput.select();
});

// ---------- Hurtigmeny «Emner» ----------

const coursesButton = $('#courses-button');
const coursesMenu = $('#courses-menu');

function renderCoursesMenu() {
  const groups = categories.length ? categories.map((cat) => [cat, courses.filter((c) => c.category === cat)]) : [['Emner', courses]];
  const uncategorized = courses.filter((c) => !c.category);
  if (categories.length && uncategorized.length) groups.push(['Andre emner', uncategorized]);
  coursesMenu.replaceChildren(
    ...groups.map(([label, list]) =>
      el('div', { class: 'dropdown-group' },
        el('p', { class: 'dropdown-group-title' }, label),
        el('ul', {}, list.map((c) => {
          const s = stats([c]);
          return el('li', {},
            el('a', { href: courseRoute(c), class: 'dropdown-link', 'aria-current': c === currentCourse ? 'page' : false },
              courseIcon(c, 'sm'),
              el('span', { class: 'dropdown-link-title' }, c.title),
              el('span', { class: 'dropdown-link-count' }, s.status === 'fullfort' ? '✓' : `${s.done}/${s.total}`)));
        })))),
    el('a', { href: '#/', class: 'dropdown-footer' }, 'Oversikt over alle emner →'),
  );
}

function setCoursesMenu(open) {
  if (open) renderCoursesMenu();
  coursesMenu.hidden = !open;
  coursesButton.setAttribute('aria-expanded', String(open));
}

coursesButton.addEventListener('click', () => setCoursesMenu(coursesMenu.hidden));
coursesMenu.addEventListener('click', (event) => {
  if (event.target.closest('a')) setCoursesMenu(false);
});
document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || coursesMenu.hidden) return;
  const focusInside = coursesMenu.contains(document.activeElement);
  setCoursesMenu(false);
  if (focusInside || document.activeElement === coursesButton) coursesButton.focus();
});

function updateQuickNav() {
  const onVideos = (location.hash || '').startsWith('#/videoer');
  const videosLink = $('#videos-link');
  if (onVideos) videosLink.setAttribute('aria-current', 'page');
  else videosLink.removeAttribute('aria-current');
  coursesButton.classList.toggle('is-active', Boolean(currentCourse));
}

/** Lukker søkeresultater og hurtigmeny, f.eks. ved navigering eller klikk utenfor. */
function closeOverlays() {
  hideSearch();
  searchInput.value = '';
  setCoursesMenu(false);
}

document.addEventListener('click', (event) => {
  if (!event.target.closest('.search')) hideSearch();
  if (!event.target.closest('.dropdown')) setCoursesMenu(false);
});

// ---------- Lyst og mørkt tema ----------

const THEME_KEY = 'kursportal-tema';
const themeToggle = $('#theme-toggle');
const darkQuery = matchMedia('(prefers-color-scheme: dark)');

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  const dark = theme === 'dark';
  themeToggle.setAttribute('aria-pressed', String(dark));
  themeToggle.title = dark ? 'Bytt til lyst tema' : 'Bytt til mørkt tema';
  themeToggle.replaceChildren(icon(dark ? 'sun' : 'moon', { size: 20 }));
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#0F172A' : '#F8FAFC');
}

themeToggle.addEventListener('click', () => {
  const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  try {
    localStorage.setItem(THEME_KEY, theme);
  } catch {
    // Lagring er ikke tillatt. Temaet gjelder da bare til siden lukkes.
  }
  applyTheme(theme);
  announce(theme === 'dark' ? 'Mørkt tema er slått på.' : 'Lyst tema er slått på.');
});

// Har brukeren ikke valgt selv, følger temaet innstillingen i operativsystemet.
darkQuery.addEventListener('change', (event) => {
  let saved = null;
  try {
    saved = localStorage.getItem(THEME_KEY);
  } catch {
    saved = null;
  }
  if (!saved) applyTheme(event.matches ? 'dark' : 'light');
});

// ---------- Oppstart ----------

const header = $('.site-header');
new ResizeObserver(() => document.documentElement.style.setProperty('--header-height', `${header.offsetHeight}px`)).observe(header);

main.addEventListener('click', (event) => {
  const button = event.target.closest('.copy-button');
  if (button) copyText(button.parentElement.querySelector('code').textContent, button);
  // Videoer: selve spilleren (iframe) lastes først ved klikk. Miniatyrbildet er et vanlig bilde fra i.ytimg.com.
  const play = event.target.closest('.video-play');
  if (play) embedVideo(play)?.focus();
});

// Ikoner i topptekst som ikke ligger i index.html.
$('#menu-button').append(icon('menu', { size: 22 }));
$('.search-icon').append(icon('search', { size: 18 }));
$('.user-chip-icon').append(icon('user', { size: 18 }));
$('.dropdown-caret').append(icon('chevron-down', { size: 16 }));
applyTheme(document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light');

$('#switch-user').addEventListener('click', () => openUserDialog(false));
$('#site-title').textContent = site.title;
$('#footer-title').textContent = site.title;
window.addEventListener('hashchange', route);
route();
if (!progress.getCurrentUser()) openUserDialog(true);
