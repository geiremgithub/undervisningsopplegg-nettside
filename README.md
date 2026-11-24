<img width="3776" height="1831" alt="kursportal" src="https://github.com/user-attachments/assets/001a75a3-1ef2-40df-b0ba-4b0443493184" />
# Kursportal – nettside for undervisningsopplegg

En enkel, statisk nettside med åtte emner: Datavarehus, SAP Analytics Cloud, Microsoft Fabric, AI-agenter, MCP-server, RAG-løsninger, Microsoft Foundry og GitHub og versjonskontroll. Studentene velger et emne, leser temaene i det og ser hvor langt de har kommet i hvert emne.

- **Innhold:** Hvert emne er en mappe i [`content/`](content/) med Markdown-filer. Menyen lages automatisk av mappene og filene.
- **Case-filer:** SQL-skript i et emne (for eksempel [`content/datavarehus/case/`](content/datavarehus/case/)) vises med syntaksutheving og kan lastes ned.
- **Progresjon:** Lagres i nettleseren (localStorage), per navn og per emne. Ingen innlogging, database eller server.
- **Design:** Forside med hero-seksjon og nøkkeltall, emnekort med ikon, kategorifilter og fremdrift, lyst og mørkt tema (følger operativsystemet til du velger selv), og fungerer på mobil, nettbrett og PC.
- **Søk:** Søkefeltet øverst (snarvei: `/`) søker i emner, temaer, overskrifter og videoer, og hopper rett til riktig sted.
- **Videoer:** Videolenker blir videokort med innebygd spiller som lastes først ved klikk. Alle videoene samles på siden **Videoer** (`#/videoer`) med filter per emne.
- **Teknologi:** [Vite](https://vite.dev) med vanlig JavaScript, [markdown-it](https://github.com/markdown-it/markdown-it), [highlight.js](https://highlightjs.org) og [gray-matter](https://github.com/jonschlinkert/gray-matter). Ingen rammeverk eller CDN.

## Veiledninger

| Veiledning | For deg som vil … |
|---|---|
| 📗 [VEILEDNING-git-og-publisering.md](VEILEDNING-git-og-publisering.md) | komme i gang med Git og GitHub, lagre nye versjoner og publisere endringer. Skrevet for nybegynnere, med feilsøking og jukselapp. |
| 📘 [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md) | lage nye emner og temaer, skrive Markdown, legge inn fasit, bilder og SQL-filer |

**Kort versjon av arbeidsflyten:** `git pull` → rediger i `content/` → se resultatet med `npm run dev` → `git add .` → `git commit -m "..."` → `git push`. Etter 1–3 minutter er nettsiden oppdatert.

## AI-agenter for portalen

Prosjektet har ferdige GitHub Copilot-agenter og skills i [`.github/`](.github/) som hjelper deg å skrive, kontrollere og publisere innhold:

| Navn | Type | Gjør |
|---|---|---|
| **Kursforfatter** | Agent | Lager nye emner og temaer etter portalens regler |
| **Innholdsgjennomgåer** | Agent | Korrekturleser innhold før publisering, uten å endre noe |
| **SQL-veileder** | Agent | Hjelper studenter med SQL-oppgavene i Datavarehus, uten å gi fasit |
| `/nytt-tema` | Skill | Oppskrift og mal for et nytt tema |
| `/sjekk-innhold` | Skill med skript | Automatisk kontroll av `content/`. Kan også kjøres uten AI: `node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs` |
| `/lag-quiz` | Skill | Lager quiz med fasit fra et tema |
| `/publiser-endringer` | Skill | Fører deg gjennom `git pull` → kontroll → `commit` → `push`. Kjøres bare når du ber om det. |

Felles regler for alle agentene står i [`.github/copilot-instructions.md`](.github/copilot-instructions.md). Hvordan de brukes og hvordan du lager egne, forklares i emnet **AI-agenter og skills** i portalen (tema 2 og 6).

## Kjøre lokalt

Krever [Node.js](https://nodejs.org) 20 eller nyere.

```bash
npm install      # første gang
npm run dev      # starter utviklingsserver på http://localhost:5173
```

Utviklingsserveren oppdaterer siden automatisk når du legger til, endrer eller sletter filer i `content/`.

Andre kommandoer:

| Kommando | Hva den gjør |
|---|---|
| `npm run build` | Bygger den ferdige nettsiden til mappen `dist/` |
| `npm run preview` | Viser det ferdige bygget lokalt, slik det blir når det publiseres |
| `npm test` | Kjører de automatiske testene |

> Åpner du `index.html` direkte i nettleseren (dobbeltklikk), fungerer ikke siden. Bruk `npm run dev` eller `npm run preview`.

## Slik er innholdet organisert

```text
content/
├── datavarehus/              ← ett emne = én mappe
│   ├── emne.json             ← navn, beskrivelse og rekkefølge for emnet
│   ├── 00-oversikt.md        ← ett tema = én .md-fil
│   ├── 01-samling-1.md
│   └── case/                 ← SQL-filer (valgfritt)
├── sap-analytics-cloud/
│   ├── emne.json
│   ├── 01-oversikt.md
│   └── …
├── microsoft-fabric/
├── agenter-og-skills/
├── mcp-server/
├── rag-losninger/
│   ├── emne.json
│   ├── 01-rag-kjeden.md
│   ├── …
│   └── bilder/               ← bilder til temaene (valgfritt)
├── microsoft-foundry/
└── git-og-github/
```

| order | Mappe | Emne | Temaer |
|---|---|---|---|
| 1 | `datavarehus/` | Datavarehus og dataintegrasjon | 9 |
| 2 | `sap-analytics-cloud/` | SAP Analytics Cloud og SAP BTP | 11 |
| 3 | `microsoft-fabric/` | Microsoft Fabric | 11 |
| 4 | `agenter-og-skills/` | AI-agenter og skills i GitHub Copilot | 9 |
| 5 | `mcp-server/` | MCP-server (Model Context Protocol) | 3 |
| 6 | `rag-losninger/` | RAG-løsninger (Retrieval-Augmented Generation) | 3 |
| 7 | `microsoft-foundry/` | Microsoft Foundry (tidligere Azure AI Foundry) | 3 |
| 8 | `git-og-github/` | GitHub og versjonskontroll | 5 |

## Legge til et nytt emne

> 📘 En detaljert veiledning med forklaringer, regler, feilsøking, sjekkliste og et komplett eksempel finnes i [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md).

For eksempel «Power BI for nybegynnere»:

1. Lag en ny mappe i `content/`. Mappenavnet blir en del av nettadressen, så bruk små bokstaver og bindestrek uten æ, ø og å: `content/power-bi/`.
2. Lag filen `content/power-bi/emne.json`:

   ```json
   {
     "title": "Power BI for nybegynnere",
     "description": "Fra Excel-ark til interaktiv rapport.",
     "order": 9
   }
   ```

   `order` bestemmer rekkefølgen på forsiden og i menyen. Eksisterende emner bruker 1–8.

3. Legg minst én tema-fil i mappen (se neste avsnitt). Emner uten temaer vises ikke.

Emnet dukker opp på forsiden og i menyen med egen fremdrift. Ingen kode må endres.

## Legge til et nytt tema i et emne

1. Lag en ny `.md`-fil i emnets mappe, for eksempel `content/power-bi/01-kom-i-gang.md`.
2. Øverst i filen legger du inn *frontmatter* mellom to linjer med `---`:

   ```markdown
   ---
   title: "Kom i gang med Power BI"
   description: "Installer Power BI Desktop og last inn de første dataene."
   order: 1
   ---

   # Kom i gang med Power BI

   Vanlig Markdown her …
   ```

3. Ferdig. Temaet dukker opp under emnet. Ingen kode må endres.

### Feltene i frontmatter

| Felt | Påkrevd | Forklaring |
|---|---|---|
| `title` | Nei | Tittelen i menyen. Mangler den, brukes første `#`-overskrift, deretter filnavnet. |
| `description` | Nei | Kort tekst som vises på temakortet. |
| `order` | Nei | Rekkefølgen i emnet (lavest først). Temaer uten `order` havner sist, sortert på filnavn. |

Bruk anførselstegn rundt tekst som inneholder kolon (`:`), slik som i eksemplene.

### Har du ett langt dokument?

Del det opp i flere `.md`-filer, for eksempel én per hovedkapittel. Da kan studentene markere hver del som fullført, og fremdriften blir mer nyttig. Dokumentene om SAP, Fabric og agenter er delt opp slik.

### Gode å vite

- **Kladd:** Filer og mapper som starter med understrek (for eksempel `_utkast.md` eller `_nytt-emne/`) vises ikke.
- **Mappe- og filnavn er ID-er.** Progresjonen lagres på `emne/filnavn`. Gir du en mappe eller fil nytt navn, mister studentene markeringen «fullført» for det temaet.
- **Bilder:** Legg bildet i emnets mappe (gjerne i `bilder/`) og lenk relativt: `![Stjerneskjema](bilder/stjerneskjema.png)`. Skriv alltid en beskrivende alt-tekst.
- **Lenker mellom temaer i samme emne:** `[Samling 2](02-samling-2.md)` blir en lenke til temaet. Filnavn i kode, som `` `case/03-etl.sql` `` eller `` `00-oversikt.md` ``, blir automatisk klikkbare hvis filen finnes i emnet.
- **Kodeblokker:** Angi språk for syntaksutheving, for eksempel ```` ```sql ````. Støttet: `sql`, `python`, `javascript`, `bash`, `powershell`, `json`, `yaml`, `xml`/`html` og `csharp`.
- **Videoer:** Hvert emne har et videotema til slutt (for eksempel `content/microsoft-fabric/11-videoer.md`). Lenker til YouTube og Vimeo får automatisk et ▶-merke. Mal og regler står i [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md), kapittel 12.

### Fasit og lærerstoff

Nettsiden legger automatisk dette bak en knapp man må klikke for å vise:

| Hva du skriver i Markdown | Vises som |
|---|---|
| Et avsnitt som starter med `**Fasit …:**` | «Vis fasit …». Blokken varer til neste overskrift, horisontale linje (`---`) eller neste avsnitt som starter med `**1.**`, `**Fasit**`, `**Oppgave**` eller `**Lærernotat**`. |
| Et avsnitt eller sitat som starter med `**Lærernotat:**` | «Lærernotat (lærerstoff)» |
| En overskrift med «hurtigreferanse for læreren», «Fasit» eller «Løsningsforslag» | Hele seksjonen frem til neste overskrift på samme nivå |

Studentene kan fortsatt åpne fasiten selv. Skal den være helt utilgjengelig, må den fjernes fra filene før publisering.

## Legge til case-filer

Legg `.sql`-filer hvor som helst inne i et emnes mappe, for eksempel i `content/datavarehus/case/`. De vises under **Case-filer (SQL)** i menyen for det emnet. Tittel og beskrivelse hentes fra kommentaren øverst i filen:

```sql
/* ==========================================
   Nordhandel AS – kildesystem (OLTP)
   Fil: case/00-oltp-skjema.sql
   Kjøres én gang før samling 1.
   ========================================== */
```

Første linje blir tittelen og neste blir beskrivelsen (linjer som starter med `Fil:` hoppes over). Temaer som nevner filnavnet får automatisk en lenke til filen.

## Endre navn og beskrivelse på nettstedet

Teksten «Om kursportalen» på forsiden står i [`content/forside.md`](content/forside.md). Den er vanlig Markdown du kan redigere fritt. Husk å oppdatere listen over emner der når du legger til et nytt emne. Sletter du filen, vises ingen slik tekst.

Navnet og den korte beskrivelsen under tittelen endrer du i [`site.config.json`](site.config.json):

```json
{
  "title": "Kursportal",
  "description": "Teksten øverst på forsiden.",
  "storageKey": "kursportal"
}
```

`storageKey` skiller progresjonen fra andre nettsteder på samme domene. Ikke endre den etter at studentene har begynt, siden progresjonen ellers forsvinner.

`tidligereLagring` henter automatisk inn fremdrift fra den første versjonen av nettstedet, der Datavarehus var eneste emne (lagringsnøkkel `datavarehus-kurs`). Det gjelder også progresjonsfiler som ble eksportert fra den versjonen. Feltet kan fjernes når ingen lenger har slik fremdrift.

## Progresjon og brukere

- Ved første besøk skriver studenten inn navnet sitt, eller fortsetter som gjest.
- Hvert navn har sin egen progresjon, så flere kan bruke samme maskin. Navn skiller ikke mellom store og små bokstaver.
- Et tema får status **Pågår** når det åpnes og **Fullført** når studenten klikker «Marker som fullført». Det kan angres.
- Fremdriftsbaren øverst viser fremdriften i emnet studenten er i, eller totalt for alle emner på forsiden. Hvert emne viser også egen fremdrift på forsiden og i menyen.
- Forsiden har knappen «Fortsett der du slapp», som går til sist besøkte tema, eller neste uferdige tema. Hvert emnekort har også en lenke til neste tema i emnet.
- På forsiden under **Din progresjon** kan studenten bytte bruker, nullstille egen progresjon og eksportere eller importere progresjonen som JSON-fil, for eksempel for å flytte den til en annen maskin. Import slår sammen med eksisterende progresjon og sletter ingenting.
- Alt lagres bare i nettleseren. Sletter studenten nettleserdata, forsvinner progresjonen.

## Publisere

Siden er helt statisk. Kjør `npm run build` og publiser innholdet i `dist/` hvor som helst. Den bruker relative stier og hash-ruting (`#/emne/...`), så den fungerer også i en undermappe og trenger ingen omskrivingsregler på serveren.

Etter at du har lagt til eller endret temaer, må siden bygges på nytt. Med oppsettene under skjer det automatisk ved hver push.

### GitHub Pages

1. Legg prosjektet i et GitHub-repo.
2. Gå til **Settings → Pages** og velg **Source: GitHub Actions**.
3. Push til `main`. Arbeidsflyten i [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) kjører testene, bygger og publiserer. Se [VEILEDNING-git-og-publisering.md](VEILEDNING-git-og-publisering.md) for hvordan du sjekker at det gikk bra.

### Netlify

Koble repoet til Netlify. Innstillingene leses fra [`netlify.toml`](netlify.toml) (byggkommando `npm run build`, mappe `dist`). Du kan også dra `dist/`-mappen rett inn på <https://app.netlify.com/drop>.

## Prosjektstruktur

```text
├── content/                  Ett emne per mappe, med temaer (.md), emne.json og case-filer (.sql)
│   ├── forside.md            Teksten «Om kursportalen» på forsiden
│   ├── datavarehus/
│   ├── sap-analytics-cloud/
│   ├── microsoft-fabric/
│   ├── agenter-og-skills/
│   ├── mcp-server/
│   ├── rag-losninger/
│   ├── microsoft-foundry/
│   └── git-og-github/
├── VEILEDNING-*.md           Veiledninger for studenter og lærere
├── scripts/content-plugin.js Leser content/ og lager emner og menyer (Vite-tillegg)
├── src/
│   ├── main.js               Ruting, visninger, søk, hurtigmeny, tema og brukerdialog
│   ├── markdown.js           Markdown → HTML, fasit, lenker, videokort, syntaksutheving
│   ├── search.js             Søkeindeks og søk i emner, temaer, overskrifter og videoer
│   ├── slug.js               Ankere for overskrifter og gjenkjenning av videolenker
│   ├── icons.js              SVG-ikoner for emner og grensesnitt
│   ├── illustration.js       SVG-illustrasjonen på forsiden
│   ├── progress.js           Lagring av progresjon per bruker
│   └── styles.css            Farger (øverst), oppsett og komponenter
├── tests/                    Automatiske tester (Vitest)
├── index.html
├── site.config.json          Navn, beskrivelse og lagringsnøkkel
└── vite.config.js
```

## Universell utforming

- Semantisk HTML med landemerker (`header`, `nav`, `main`) og lenken «Hopp til innholdet».
- Alt kan brukes med tastatur. Synlig fokusmarkering, og Escape lukker menyen og dialogen.
- Status vises med både symbol og tekst, ikke bare farge. Skjermlesere får beskjed når status endres.
- Kontrast etter WCAG AA i både lys og mørk modus (følger systeminnstillingen), og redusert animasjon respekteres.
