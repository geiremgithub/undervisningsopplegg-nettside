import fs from 'node:fs';
import path from 'node:path';
import matter from 'gray-matter';
import { createSlugger, parseVideoUrl } from '../src/slug.js';

const VIRTUAL_ID = 'virtual:innhold';
const RESOLVED_ID = '\0' + VIRTUAL_ID;
const FILE_EXTENSIONS = ['.sql'];

function walk(dir, base = dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full, base);
    return [path.relative(base, full).split(path.sep).join('/')];
  });
}

function firstHeading(markdown) {
  const match = markdown.match(/^#\s+(.+?)\s*#*\s*$/m);
  return match ? match[1].trim() : null;
}

/** En fil regnes som brukt hvis temaet nevner hele stien, eller filnavnet når det er unikt i emnet. */
function referencedFiles(content, fileNames) {
  const count = (name) => fileNames.filter((f) => path.posix.basename(f) === name).length;
  return fileNames.filter((f) => content.includes(f) || (count(path.posix.basename(f)) === 1 && content.includes(path.posix.basename(f))));
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0' };

/** Gjør inline-Markdown om til ren tekst, slik overskriften blir seende ut på siden (textContent). */
function plainText(markdown) {
  return markdown
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/<[^>]+>/g, '')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/(\*\*|__)(.+?)\1/g, '$2')
    .replace(/(^|[^\w*])\*(?!\s)([^*]+?)\*(?!\w)/g, '$1$2')
    .replace(/\\([\\`*_{}[\]()#+\-.!|>~])/g, '$1')
    .replace(/&(#x[\da-f]+|#\d+|[a-z]+);/gi, (entity, code) => {
      if (code[0] === '#') return String.fromCodePoint(code[1].toLowerCase() === 'x' ? parseInt(code.slice(2), 16) : Number(code.slice(1)));
      return ENTITIES[code.toLowerCase()] ?? entity;
    })
    .trim();
}

/**
 * Henter overskrifter (nivå 2 og 3) og videoer fra et tema til søket. ID-ene lages likt som på siden.
 * Videoer gjenkjennes i to formater:
 *   - tabellrad:   | [Tittel](https://youtube…) | Kilde · lengde | Beskrivelse |
 *   - videokort:   ### Tittel  etterfulgt av  - **Lenke:** https://youtube…
 */
export function outlineTopic(markdown, fallbackTitle = '') {
  const slug = createSlugger();
  const headings = [];
  const videos = [];
  const lines = markdown.split(/\r?\n/);
  let inFence = false;
  let h2 = null;
  let h3 = null;
  let card = {};

  if (!lines.some((l) => /^#\s/.test(l)) && fallbackTitle) slug(fallbackTitle);

  // Et videokort kan ha feltene i vilkårlig rekkefølge, så videoen lagres først når kortet er lest ferdig.
  const flushCard = () => {
    if (card.url && h3) videos.push({ title: h3.text, url: card.url, meta: card.meta ?? '', level: card.level ?? null, anchor: h3.id });
    card = {};
  };

  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    // Overskrifter kan ha inntil tre mellomrom foran, og kan stå i et sitat («> ## …»), akkurat som i Markdown.
    const heading = line.replace(/^ {0,3}(> ?)+/, '').match(/^ {0,3}(#{1,6})\s+(.+?)(?:\s+#+)?\s*$/);
    if (heading) {
      flushCard();
      const level = heading[1].length;
      const text = plainText(heading[2]);
      const id = slug(text);
      if (level === 2 || level === 3) headings.push({ level, text, id });
      if (level <= 2) h2 = { text, id };
      h3 = level === 3 ? { text, id } : level < 3 ? null : h3;
      continue;
    }

    const row = line.match(/^\|\s*\[([^\]]+)\]\(([^)\s]+)\)\s*\|([^|]*)\|/);
    if (row && parseVideoUrl(row[2])) {
      videos.push({ title: plainText(row[1]), url: row[2], meta: plainText(row[3]), level: null, anchor: h2?.id ?? null });
      continue;
    }

    const field = line.match(/^\s*[-*]\s+\*\*([^*:]+):\*\*\s*(.+)$/);
    if (field && h3) {
      const name = field[1].trim().toLowerCase();
      if (name.startsWith('kanal')) card.meta = plainText(field[2]);
      if (name.startsWith('nivå')) card.level = plainText(field[2]);
      const url = name === 'lenke' ? field[2].match(/https?:\/\/\S+/)?.[0] : null;
      if (url && parseVideoUrl(url)) card.url = url;
    }
  }
  flushCard();
  return { headings, videos };
}

/** Leser alle .md-filer direkte i emnemappen. Filer som starter med _ hoppes over (kladd). */
export function scanTopics(contentDir, fileNames = []) {
  if (!fs.existsSync(contentDir)) return [];
  return fs
    .readdirSync(contentDir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.toLowerCase().endsWith('.md') && !e.name.startsWith('_'))
    .map((e) => {
      const raw = fs.readFileSync(path.join(contentDir, e.name), 'utf8').replace(/^\uFEFF/, '');
      let parsed;
      try {
        parsed = matter(raw);
      } catch (error) {
        const hint = /^---\r?\n(?![\s\S]*?\r?\n---[ \t]*(\r?\n|$))/.test(raw) ? ' Mangler den avsluttende ----linjen?' : '';
        throw new Error(`Ugyldig frontmatter i ${path.join(contentDir, e.name)}:${hint} ${error.reason ?? error.message}`);
      }
      const { data, content } = parsed;
      const slug = e.name.replace(/\.md$/i, '');
      const order = Number(data.order);
      const title = String(data.title ?? firstHeading(content) ?? slug);
      return {
        slug,
        file: e.name,
        title,
        description: data.description ? String(data.description) : '',
        order: Number.isFinite(order) ? order : null,
        files: referencedFiles(content, fileNames),
        ...outlineTopic(content, title),
      };
    })
    .sort((a, b) => (a.order ?? Infinity) - (b.order ?? Infinity) || a.slug.localeCompare(b.slug, 'nb'));
}

/** Henter tittel og beskrivelse fra kommentarblokken øverst i en SQL-fil. */
export function describeSqlFile(text) {
  const lines = [];
  const block = text.replace(/^\uFEFF/, '').match(/^\s*\/\*([\s\S]*?)\*\//);
  if (block) lines.push(...block[1].split(/\r?\n/));
  else for (const line of text.split(/\r?\n/)) {
    if (!line.trim().startsWith('--')) break;
    lines.push(line.replace(/^\s*--/, ''));
  }
  const meaningful = lines
    .map((l) => l.trim())
    .filter((l) => l && !/^[=\-*#~_]+$/.test(l) && !/^fil\s*:/i.test(l));
  return { title: meaningful[0] ?? '', description: meaningful[1] ?? '' };
}

export function scanFiles(contentDir) {
  return walk(contentDir)
    .filter((f) => FILE_EXTENSIONS.includes(path.extname(f).toLowerCase()))
    .sort((a, b) => a.localeCompare(b, 'nb'))
    .map((f) => ({ path: f, name: path.posix.basename(f), ...describeSqlFile(fs.readFileSync(path.join(contentDir, f), 'utf8')) }));
}

function readJson(file) {
  if (!fs.existsSync(file)) return {};
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  } catch (error) {
    throw new Error(`Ugyldig JSON i ${file}: ${error.message}`);
  }
}

export function readSiteConfig(rootDir) {
  const defaults = { title: 'Undervisningsopplegg', description: '', storageKey: 'undervisningsopplegg' };
  return { ...defaults, ...readJson(path.join(rootDir, 'site.config.json')) };
}

/** Hver undermappe i content/ er et emne. Mapper som starter med _ eller . hoppes over. */
export function scanCourses(contentDir) {
  if (!fs.existsSync(contentDir)) return [];
  return fs
    .readdirSync(contentDir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !/^[_.]/.test(e.name))
    .map((e) => {
      const dir = path.join(contentDir, e.name);
      const meta = readJson(path.join(dir, 'emne.json'));
      const files = scanFiles(dir);
      const order = Number(meta.order);
      return {
        slug: e.name,
        title: String(meta.title ?? e.name),
        description: meta.description ? String(meta.description) : '',
        order: Number.isFinite(order) ? order : null,
        // Valgfritt: ikon (se src/icons.js) og kategori (brukes til filtrering på forsiden).
        icon: meta.ikon ? String(meta.ikon) : null,
        category: meta.kategori ? String(meta.kategori) : null,
        topics: scanTopics(dir, files.map((f) => f.path)),
        files,
      };
    })
    .filter((c) => c.topics.length > 0)
    .sort((a, b) => (a.order ?? Infinity) - (b.order ?? Infinity) || a.slug.localeCompare(b.slug, 'nb'));
}

export function buildContentIndex(rootDir) {
  return { site: readSiteConfig(rootDir), courses: scanCourses(path.join(rootDir, 'content')) };
}

/** Vite-tillegg: eksponerer innholdsoversikten som `virtual:innhold` og laster siden på nytt når content/ endres. */
export function contentPlugin() {
  let rootDir;
  return {
    name: 'undervisningsopplegg-innhold',
    configResolved(config) {
      rootDir = config.root;
    },
    resolveId(id) {
      return id === VIRTUAL_ID ? RESOLVED_ID : null;
    },
    load(id) {
      if (id !== RESOLVED_ID) return null;
      this.addWatchFile(path.join(rootDir, 'site.config.json'));
      return `export default ${JSON.stringify(buildContentIndex(rootDir))};`;
    },
    configureServer(server) {
      const contentDir = path.join(rootDir, 'content');
      server.watcher.add([contentDir, path.join(rootDir, 'site.config.json')]);
      const onChange = (file) => {
        const rel = path.relative(rootDir, file);
        if (!rel.startsWith('content') && rel !== 'site.config.json') return;
        const mod = server.moduleGraph.getModuleById(RESOLVED_ID);
        if (mod) server.moduleGraph.invalidateModule(mod);
        server.ws.send({ type: 'full-reload' });
      };
      server.watcher.on('add', onChange);
      server.watcher.on('unlink', onChange);
      server.watcher.on('change', onChange);
    },
  };
}
