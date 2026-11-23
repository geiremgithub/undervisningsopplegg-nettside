// Kontrollerer innholdet i content/ mot reglene i VEILEDNING-nye-emner.md.
// Bruk: node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs [emne]
import fs from 'node:fs';
import path from 'node:path';
import { buildContentIndex } from '../../../../scripts/content-plugin.js';

const root = process.cwd();
const contentDir = path.join(root, 'content');
const only = process.argv[2];
const funn = [];
const meld = (type, fil, melding) => funn.push({ type, fil, melding });

if (!fs.existsSync(contentDir)) {
  console.error('Fant ikke content/. Kjør skriptet fra roten av prosjektet.');
  process.exit(2);
}

let courses;
try {
  courses = buildContentIndex(root).courses;
} catch (error) {
  console.error(`FEIL  ${error.message}`);
  process.exit(1);
}

const NAVN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const folders = fs
  .readdirSync(contentDir, { withFileTypes: true })
  .filter((e) => e.isDirectory() && !/^[_.]/.test(e.name) && (!only || e.name === only));

if (only && folders.length === 0) {
  console.error(`Fant ikke emnet content/${only}/`);
  process.exit(2);
}

const forside = fs.existsSync(path.join(contentDir, 'forside.md')) ? fs.readFileSync(path.join(contentDir, 'forside.md'), 'utf8') : null;

for (const folder of folders) {
  const rel = `content/${folder.name}`;
  const course = courses.find((c) => c.slug === folder.name);
  const hasMeta = fs.existsSync(path.join(contentDir, folder.name, 'emne.json'));
  if (!NAVN.test(folder.name)) meld('FEIL', rel, 'Mappenavnet skal bare ha små bokstaver, tall og bindestrek.');
  if (!hasMeta) meld('ADVARSEL', rel, 'Mangler emne.json. Mappenavnet brukes som tittel, og emnet havner sist.');
  if (!course) {
    meld('FEIL', rel, 'Emnet har ingen temafiler (.md) og vises ikke.');
    continue;
  }
  if (hasMeta && course.title === course.slug) meld('ADVARSEL', `${rel}/emne.json`, 'Mangler "title".');
  if (hasMeta && !course.description) meld('ADVARSEL', `${rel}/emne.json`, 'Mangler "description".');
  if (hasMeta && course.order === null) meld('ADVARSEL', `${rel}/emne.json`, 'Mangler "order". Emnet havner sist.');
  if (forside && !forside.includes(course.title)) meld('ADVARSEL', 'content/forside.md', `Emnet «${course.title}» står ikke i listen på forsiden.`);

  const seen = new Map();
  for (const topic of course.topics) {
    const fil = `${rel}/${topic.file}`;
    const raw = fs.readFileSync(path.join(contentDir, folder.name, topic.file), 'utf8').replace(/^\uFEFF/, '');
    if (!NAVN.test(topic.slug)) meld('FEIL', fil, 'Filnavnet skal bare ha små bokstaver, tall og bindestrek.');
    const frontmatter = raw.match(/^---\r?\n([\s\S]*?)\r?\n---[ \t]*(\r?\n|$)/);
    if (!raw.startsWith('---')) meld('ADVARSEL', fil, 'Mangler frontmatter øverst (title, description, order).');
    else if (!frontmatter) meld('FEIL', fil, 'Frontmatter mangler avsluttende ---. Innstillingene vises da som tekst på siden.');
    else {
      if (!/^title:/m.test(frontmatter[1])) meld('ADVARSEL', fil, 'Mangler "title" i frontmatter.');
      if (!topic.description) meld('ADVARSEL', fil, 'Mangler "description" i frontmatter.');
    }
    if (topic.order === null) meld('ADVARSEL', fil, 'Mangler "order". Temaet havner sist.');
    else if (seen.has(topic.order)) meld('ADVARSEL', fil, `Samme order (${topic.order}) som ${seen.get(topic.order)}.`);
    else seen.set(topic.order, topic.file);

    raw.split(/\r?\n/).forEach((line, i) => {
      for (const m of line.matchAll(/!\[([^\]]*)\]\(([^)\s]+)/g)) {
        if (!m[1].trim()) meld('ADVARSEL', `${fil}:${i + 1}`, `Bildet ${m[2]} mangler alt-tekst.`);
        if (!/^([a-z][a-z0-9+.-]*:|\/\/)/i.test(m[2])) {
          const bilde = path.join(contentDir, folder.name, m[2]);
          if (!fs.existsSync(bilde)) meld('FEIL', `${fil}:${i + 1}`, `Fant ikke bildet ${m[2]}.`);
        }
      }
    });
  }
}

const feil = funn.filter((f) => f.type === 'FEIL').length;
for (const f of funn) console.log(`${f.type.padEnd(8)} ${f.fil}  ${f.melding}`);
console.log(`\n${folders.length} emne(r) sjekket: ${feil} feil, ${funn.length - feil} advarsler.`);
process.exit(feil ? 1 : 0);
