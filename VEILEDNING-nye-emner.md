# Veiledning: Slik legger du til et nytt emne i kursportalen

Denne veiledningen viser steg for steg hvordan du legger til et nytt emne, for eksempel «Power BI for nybegynnere». Du trenger ikke kunne programmere. Alt gjøres ved å lage mapper og skrive tekstfiler i Markdown.

---

## Innhold

1. [Slik henger det sammen](#1-slik-henger-det-sammen)
2. [Før du begynner](#2-før-du-begynner)
3. [Steg 1: Lag en mappe for emnet](#3-steg-1-lag-en-mappe-for-emnet)
4. [Steg 2: Lag emne.json](#4-steg-2-lag-emnejson)
5. [Steg 3: Lag det første temaet](#5-steg-3-lag-det-første-temaet)
6. [Steg 4: Se resultatet lokalt](#6-steg-4-se-resultatet-lokalt)
7. [Steg 5: Legg til flere temaer](#7-steg-5-legg-til-flere-temaer)
8. [Steg 6: Oppdater forsideteksten](#8-steg-6-oppdater-forsideteksten)
9. [Steg 7: Publiser](#9-steg-7-publiser)
10. [Skriv godt innhold: Markdown-oppslag](#10-skriv-godt-innhold-markdown-oppslag)
11. [Fasit og lærerstoff](#11-fasit-og-lærerstoff)
12. [Bilder, SQL-filer og lenker](#12-bilder-sql-filer-og-lenker)
13. [Har du et ferdig, langt dokument?](#13-har-du-et-ferdig-langt-dokument)
14. [Endre, flytte eller fjerne et emne](#14-endre-flytte-eller-fjerne-et-emne)
15. [Feilsøking](#15-feilsøking)
16. [Sjekkliste](#16-sjekkliste)
17. [Komplett eksempel](#17-komplett-eksempel)

---

## 1. Slik henger det sammen

Portalen leser alt innhold fra mappen `content/` i prosjektet. Reglene er enkle:

| Det du lager | Det studentene ser |
|---|---|
| En **mappe** i `content/` | Et **emne** på forsiden og i menyen |
| En fil `emne.json` i mappen | Emnets **navn, beskrivelse og plassering** |
| En **`.md`-fil** i mappen | Et **tema** i emnet, med egen status og knappen «Marker som fullført» |
| En **`.sql`-fil** i mappen | En **case-fil** som kan leses, kopieres og lastes ned |

```text
undervisningsopplegg-nettside/
└── content/
    ├── forside.md                   ← teksten «Om kursportalen» på forsiden
    ├── datavarehus/                 ← emne
    │   ├── emne.json
    │   ├── 00-oversikt.md           ← tema
    │   ├── 01-samling-1.md          ← tema
    │   └── case/
    │       └── 00-oltp-skjema.sql   ← case-fil
    ├── sap-analytics-cloud/         ← emne
    ├── microsoft-fabric/            ← emne
    ├── agenter-og-skills/           ← emne
    ├── mcp-server/                  ← emne
    ├── rag-losninger/               ← emne
    │   └── bilder/
    │       └── rag-ingestering.jpg  ← bilde brukt i et tema
    ├── microsoft-foundry/           ← emne
    ├── git-og-github/               ← emne
    └── power-bi/                    ← DITT NYE EMNE
        ├── emne.json
        ├── 01-kom-i-gang.md
        └── 02-datamodell.md
```

**Du skal aldri endre kode** for å legge til et emne. Menyen, emnekortene, fremdriftsbaren og «Forrige»/«Neste» lages automatisk ut fra mappene og filene.

---

## 2. Før du begynner

Du trenger:

| Hva | Hvorfor | Sjekk at du har det |
|---|---|---|
| **Prosjektmappen** `undervisningsopplegg-nettside` | Her ligger portalen | Åpne mappen i Utforsker eller VS Code |
| **Node.js** (versjon 20 eller nyere) | For å se portalen lokalt | Kjør `node --version` i PowerShell |
| **En teksteditor**, helst **VS Code** | For å skrive filene | VS Code viser også en forhåndsvisning av Markdown (`Ctrl+Shift+V`) |
| **Git** (valgfritt) | For å publisere | Kjør `git --version` |

Har du ikke kjørt portalen på maskinen før, må du installere avhengighetene én gang:

```powershell
cd C:\Work\undervisningsopplegg-nettside
npm install
```

> 💡 **Tips:** Åpne hele prosjektmappen i VS Code med **File → Open Folder**. Da ser du `content/` i filutforskeren til venstre og kan lage mapper og filer der med høyreklikk.

---

## 3. Steg 1: Lag en mappe for emnet

Lag en ny mappe inne i `content/`.

**I VS Code:** Høyreklikk på `content` → **New Folder** → skriv `power-bi`.

**I PowerShell:**

```powershell
cd C:\Work\undervisningsopplegg-nettside
New-Item -ItemType Directory content\power-bi
```

### Regler for mappenavnet

Mappenavnet blir en del av nettadressen (`…/#/emne/power-bi`) og brukes til å lagre studentenes fremdrift. Derfor:

| Regel | ✅ Riktig | ❌ Feil |
|---|---|---|
| Bare små bokstaver, tall og bindestrek | `power-bi` | `Power BI` |
| Ikke æ, ø, å | `sporringer` | `spørringer` |
| Ikke mellomrom | `sql-grunnkurs` | `sql grunnkurs` |
| Ikke start med `_` eller `.` | `python` | `_python` (blir skjult) |
| Velg et navn du ikke trenger å endre | `power-bi` | `power-bi-utkast-v2` |

> ⚠️ **Viktig:** Endrer du mappenavnet senere, mister studentene fremdriften sin i emnet. Velg navnet med omhu.

> 💡 **Kladd:** Vil du jobbe med et emne uten at studentene ser det, kan du kalle mappen `_power-bi`. Mapper som starter med understrek vises ikke. Når emnet er klart, fjerner du understreken.

---

## 4. Steg 2: Lag emne.json

Lag filen `content/power-bi/emne.json` med dette innholdet:

```json
{
  "title": "Power BI for nybegynnere",
  "description": "Fra Excel-ark til interaktiv rapport: datamodell, DAX og visualisering.",
  "order": 9
}
```

### Hva feltene betyr

| Felt | Påkrevd | Hva det gjør | Hvor det vises |
|---|---|---|---|
| `title` | Nei, men anbefalt | Emnets navn. Mangler det, brukes mappenavnet (`power-bi`). | Emnekortet på forsiden, menyen, emnesiden og fremdriftsbaren |
| `description` | Nei | Én eller to setninger om hva emnet handler om | Emnekortet og toppen av emnesiden |
| `order` | Nei | Rekkefølgen blant emnene. Lavest tall kommer først. Emner uten `order` havner sist. | Forsiden og menyen |

Dagens emner har `order` 1–8, så et nytt emne som skal ligge sist, får 9:

| order | Mappe | Emne |
|---|---|---|
| 1 | `datavarehus/` | Datavarehus og dataintegrasjon |
| 2 | `sap-analytics-cloud/` | SAP Analytics Cloud og SAP BTP |
| 3 | `microsoft-fabric/` | Microsoft Fabric |
| 4 | `agenter-og-skills/` | AI-agenter og skills i GitHub Copilot |
| 5 | `mcp-server/` | MCP-server (Model Context Protocol) |
| 6 | `rag-losninger/` | RAG-løsninger (Retrieval-Augmented Generation) |
| 7 | `microsoft-foundry/` | Microsoft Foundry (tidligere Azure AI Foundry) |
| 8 | `git-og-github/` | GitHub og versjonskontroll |

Vil du ha det nye emnet først, gir du det `"order": 0`. Vil du ha det mellom to emner, kan du bruke desimaltall, for eksempel `"order": 2.5`.

### Vanlige JSON-feil

JSON er strengt. Én feil gjør at portalen ikke bygges, og feilmeldingen sier hvilken fil det gjelder.

```json
{
  "title": "Power BI",          ✅ anførselstegn rundt både navn og verdi
  "order": 9                    ✅ tall uten anførselstegn, og INGEN komma etter siste linje
}
```

| ❌ Feil | Hvorfor |
|---|---|
| `title: "Power BI"` | Feltnavnet mangler anførselstegn |
| `'title': 'Power BI'` | Enkle anførselstegn er ikke lov |
| `"order": 9,` på siste linje | Komma etter siste felt er ikke lov |
| `"description": "Han sa "hei""` | Anførselstegn inni tekst må skrives som `\"` eller byttes med «» |

> 💡 Bruk gjerne norske anførselstegn «slik» inne i tekstene. Da slipper du problemet.

---

## 5. Steg 3: Lag det første temaet

Et tema er én `.md`-fil i emnemappen. Lag `content/power-bi/01-kom-i-gang.md`:

```markdown
---
title: "Kom i gang med Power BI"
description: "Installer Power BI Desktop, last inn data og lag din første visualisering."
order: 1
---

# Kom i gang med Power BI

**Mål:** Etter dette temaet kan du laste inn en Excel-fil i Power BI og lage et søylediagram.

## 1. Installer Power BI Desktop

1. Åpne Microsoft Store.
2. Søk etter **Power BI Desktop**.
3. Klikk **Installer**.

## 2. Last inn data

Velg **Hjem → Hent data → Excel-arbeidsbok** og velg filen `salg.xlsx`.

## 3. Lag et søylediagram

| Felt | Hva du drar inn |
|---|---|
| X-akse | `Kategori` |
| Y-akse | `Omsetning` |

## Oppgave

Lag et linjediagram som viser omsetning per måned.

**Fasit:** Dra `Dato` til X-aksen og velg hierarkinivå **Måned**. Dra `Omsetning` til Y-aksen.
```

### Delen mellom `---`-linjene (frontmatter)

Øverst i hver temafil står det en blokk mellom to linjer med `---`. Den heter *frontmatter* og styrer hvordan temaet vises i menyen. Den vises ikke som tekst for studentene.

| Felt | Påkrevd | Hva det gjør |
|---|---|---|
| `title` | Nei, men anbefalt | Navnet i menyen og på temakortet. Mangler det, brukes første `#`-overskrift i filen, og deretter filnavnet. |
| `description` | Nei | Kort tekst på temakortet på emnesiden |
| `order` | Nei | Rekkefølgen i emnet. Styrer også «Forrige» og «Neste». Temaer uten `order` havner sist, sortert på filnavn. |

**Regler for frontmatter:**

- De to `---`-linjene må stå **helt øverst** i filen, uten tomme linjer før.
- Bruk **anførselstegn rundt tekst** som inneholder kolon (`:`), for eksempel `title: "SAC: modell og story"`. Uten anførselstegn tolkes kolonet feil.
- `order` er et tall uten anførselstegn.

### Filnavnet

Filnavnet blir temaets ID i nettadressen og i fremdriften (`power-bi/01-kom-i-gang`). Bruk samme regler som for mappenavn: små bokstaver, tall og bindestrek, uten æøå og mellomrom. Filen må slutte på `.md`.

> 💡 **Tips:** Start filnavnet med et tall (`01-`, `02-` …). Da står filene i riktig rekkefølge i filutforskeren også.

> ⚠️ Et emne **uten** temafiler vises ikke i portalen. Det må ha minst én `.md`-fil.

---

## 6. Steg 4: Se resultatet lokalt

Start portalen i utviklingsmodus:

```powershell
cd C:\Work\undervisningsopplegg-nettside
npm run dev
```

Åpne **http://localhost:5173** i nettleseren. Du skal nå se:

- emnekortet **«Power BI for nybegynnere»** på forsiden, med «0 av 1 fullført – 0 %»
- emnet i menyen til venstre
- temaet «Kom i gang med Power BI» når du klikker deg inn

**La serveren stå på mens du skriver.** Hver gang du lagrer en fil i `content/`, laster siden seg automatisk på nytt, slik at du ser endringen med en gang. Det gjelder også når du legger til nye filer eller mapper.

Du stopper serveren med **Ctrl + C** i terminalen.

---

## 7. Steg 5: Legg til flere temaer

Lag én `.md`-fil per tema. Gi dem stigende `order`:

```text
content/power-bi/
├── emne.json
├── 01-kom-i-gang.md        order: 1
├── 02-datamodell.md        order: 2
├── 03-dax.md               order: 3
├── 04-visualisering.md     order: 4
└── 05-oppgaver.md          order: 5
```

### Hvor stort bør et tema være?

Et tema er det studentene markerer som fullført. Det bør derfor være en avgrenset bit de kan bli ferdige med i én økt.

| For lite | Passe | For stort |
|---|---|---|
| Én overskrift og to avsnitt | 15–60 minutters arbeid, ett tydelig læringsmål | Et helt kurs i én fil |
| Fremdriften blir «hakkete» | Studentene får følelsen av fremgang | Studentene sitter på «Pågår» i ukevis |

**God struktur i hvert tema:**

1. Tittel (`# …`)
2. **Mål:** hva studenten kan etterpå
3. Forklaring med eksempler
4. Oppgaver, med fasit (se [kapittel 11](#11-fasit-og-lærerstoff))

### Sette inn et tema mellom to andre

Vil du sette inn et tema mellom `order: 2` og `order: 3`, gir du det `order: 2.5`. Du trenger ikke endre de andre filene eller gi dem nytt navn.

---

## 8. Steg 6: Oppdater forsideteksten

Emnekortet lages automatisk, men teksten **«Om kursportalen»** øverst på forsiden er skrevet for hånd. Åpne `content/forside.md` og legg det nye emnet til i listen under **Emnene**:

```markdown
## Emnene

- **Datavarehus og dataintegrasjon:** …
- **SAP Analytics Cloud og SAP BTP:** …
- **Microsoft Fabric:** …
- **AI-agenter og skills i GitHub Copilot:** …
- **Power BI for nybegynnere:** Fra Excel-ark til interaktiv rapport: datamodell, DAX og visualisering.
```

---

## 9. Steg 7: Publiser

Når emnet ser riktig ut lokalt, publiserer du det.

### Med Git og GitHub Pages (anbefalt)

```powershell
cd C:\Work\undervisningsopplegg-nettside
git add -A
git commit -m "Legg til emne: Power BI for nybegynnere"
git push
```

GitHub bygger og publiserer portalen automatisk. Etter 1–3 minutter er emnet synlig på nettsiden. Under **Actions** i GitHub-repoet ser du om publiseringen gikk bra (grønn hake) eller feilet (rødt kryss).

> GitHub Pages må være satt opp én gang først. Se `README.md`, avsnittet **Publisere**.

### Uten Git (for eksempel Netlify Drop)

```powershell
npm run build
```

Dra deretter mappen `dist/` inn på <https://app.netlify.com/drop>.

> ⚠️ `npm run build` må kjøres **hver gang** innholdet endres. Den ferdige nettsiden i `dist/` oppdateres ikke av seg selv.

---

## 10. Skriv godt innhold: Markdown-oppslag

Alle temafiler skrives i Markdown. Her er det du trenger mest:

| Du skriver | Studentene ser |
|---|---|
| `# Tittel` | Stor overskrift (bruk bare én per fil) |
| `## Kapittel` | Kapitteloverskrift, og vises i «Innhold på denne siden» |
| `### Underkapittel` | Mindre overskrift |
| `**fet**` | **fet** |
| `*kursiv*` | *kursiv* |
| `` `kode` `` | `kode` |
| `- punkt` | Punktliste |
| `1. punkt` | Nummerert liste |
| `> sitat` | Uthevet boks |
| `---` | Skillelinje |
| `[tekst](https://example.com)` | Lenke som åpnes i ny fane |

### Tabeller

```markdown
| Begrep | Forklaring |
|---|---|
| Fakta | Tall du summerer |
| Dimensjon | Noe du grupperer etter |
```

Brede tabeller kan rulles sideveis på mobil.

### Kodeblokker med syntaksutheving

Skriv tre backticks (` ``` `) og navnet på språket:

````markdown
```sql
SELECT Kategori, SUM(Omsetning) AS Total
FROM Salg
GROUP BY Kategori;
```
````

Studentene får fargekoding og en **Kopier**-knapp.

| Språk | Skriv |
|---|---|
| SQL (også T-SQL, PostgreSQL) | `sql` |
| Python | `python` |
| JavaScript | `javascript` eller `js` |
| PowerShell | `powershell` |
| Bash/terminal | `bash` |
| JSON | `json` |
| YAML | `yaml` |
| HTML/XML | `html` eller `xml` |
| C# | `csharp` |
| Ren tekst eller figurer | `text` |

Andre språk, som DAX og KQL, vises som vanlig kode uten fargekoding.

### Innholdsfortegnelse

Du trenger ikke skrive innholdsfortegnelse selv. Har temaet tre eller flere `##`-overskrifter, lager portalen automatisk en sammenleggbar **«Innhold på denne siden»**.

---

## 11. Fasit og lærerstoff

Portalen skjuler fasit og lærerstoff bak knapper, slik at studentene kan prøve selv først. Dette skjer automatisk når du følger disse reglene:

### Fasit

Start et avsnitt med `**Fasit:**` (eller `**Fasit 1:**`, `**Fasit G:**` osv.):

```markdown
**Oppgave 1:** Hvor mange rader har tabellen?

**Fasit:** 1 250 rader. Du finner tallet nederst i datavisningen.

Forklaring: Power BI viser antall rader for valgt tabell.
```

Studentene ser knappen **«Vis fasit»**. Alt etter `**Fasit:**` skjules **til og med** avsnittet før ett av disse:

- en ny overskrift (`#`, `##` …)
- en skillelinje (`---`)
- et nytt avsnitt som starter med `**1.**`, `**Fasit**`, `**Oppgave**` eller `**Lærernotat**`

Fasiten kan altså gå over flere avsnitt, tabeller og kodeblokker.

### Lærernotat

Start et avsnitt eller sitat med `**Lærernotat:**`:

```markdown
> **Lærernotat:** Mange studenter glemmer å sette datatypen. Gå rundt og sjekk.
```

Det vises som **«Lærernotat (lærerstoff)»** bak en knapp.

### Hele lærerseksjoner

En overskrift som inneholder **«hurtigreferanse for læreren»**, eller som starter med **«Fasit»** eller **«Løsningsforslag»**, legger hele seksjonen bak en knapp, frem til neste overskrift på samme nivå:

```markdown
## Løsningsforslag

Alt her blir skjult …

## Neste kapittel        ← herfra vises alt igjen
```

> ⚠️ **Fasit er skjult, ikke hemmelig.** Studentene kan åpne den selv. Skal noe være helt utilgjengelig, for eksempel en eksamensfasit, må det ikke ligge i portalen.

---

## 12. Bilder, SQL-filer og lenker

### Bilder

1. Lag en undermappe, for eksempel `content/power-bi/bilder/`.
2. Legg bildet der: `content/power-bi/bilder/rapport.png`.
3. Sett det inn i temaet med en **relativ sti** (fra emnemappen):

   ```markdown
   ![Ferdig rapport med søylediagram og filter](bilder/rapport.png)
   ```

Teksten i hakeparentesene er **alt-teksten**. Den leses opp for blinde og svaksynte, så beskriv hva bildet viser. Støttede formater er `png`, `jpg`, `jpeg`, `gif`, `svg`, `webp` og `avif`.

### SQL-filer (case-filer)

Har emnet SQL-skript studentene skal kjøre, legger du dem i emnemappen, gjerne i `case/`:

```text
content/power-bi/case/01-lag-tabeller.sql
```

Start filen med en kommentarblokk. Første linje blir tittel, og neste linje blir beskrivelse:

```sql
/* ===========================================
   Power BI-kurs – tabeller for salgsdata
   Fil: case/01-lag-tabeller.sql
   Kjøres før tema 2.
   =========================================== */

CREATE TABLE Salg (...);
```

Da skjer følgende automatisk:

- Emnet får **«Case-filer (SQL)»** i menyen.
- Filen kan leses med syntaksutheving, kopieres og lastes ned.
- Temaer som nevner filnavnet, for eksempel `` `case/01-lag-tabeller.sql` ``, får en klikkbar lenke og en boks nederst: «Case-filer brukt i dette temaet».

### Lenker

| Hva | Skriv | Merknad |
|---|---|---|
| Nettside | `[Microsoft Learn](https://learn.microsoft.com)` | Åpnes i ny fane |
| Annet tema i **samme** emne | `[Datamodell](02-datamodell.md)` | Bruk filnavnet |
| Overskrift i et annet tema | `[DAX-mål](03-dax.md#dax-mal)` | Se om ankere under |
| Overskrift i **samme** tema | `[Se oppgaven](#oppgave)` | |
| Tema i et **annet** emne | `[Lakehouse](#/emne/microsoft-fabric/tema/02-lakehouse)` | Formen er `#/emne/<mappe>/tema/<filnavn uten .md>` |
| Case-fil | `` `case/01-lag-tabeller.sql` `` | Blir klikkbar automatisk |

**Ankere (lenker til overskrifter):** Lag ankeret av overskriftsteksten med små bokstaver, der æ blir ae, ø blir o og å blir a, og alt som ikke er bokstav eller tall blir bindestrek. Eksempel: `## 3. DAX-mål` gir `#3-dax-mal`.

### Videolenker (YouTube, Vimeo og andre)

Hvert emne har et eget videotema som siste tema, for eksempel `content/microsoft-fabric/11-videoer.md`. Der samles videoene for emnet, gruppert etter tema, med lenke tilbake til temaet de hører til.

**Slik ser én videolenke ut for studentene:** Lenker til `youtube.com`, `youtu.be` og `vimeo.com` får automatisk et rødt ▶-merke foran, og åpnes i ny fane. Skjermlesere får også beskjed om at det er en video.

**Mal for en videoseksjon** (kopier og fyll inn):

```markdown
## Navnet på temaet

Se [Navnet på temaet](02-filnavn.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [Videotittel nøyaktig som på YouTube](https://www.youtube.com/watch?v=VIDEO-ID) | YouTube – Kanalnavn · 12:34 | Én–to setninger: hva videoen viser, og hvorfor den er nyttig for akkurat dette temaet. |
```

**Mal for et nytt videotema** i et emne som ikke har ett ennå:

```markdown
---
title: "Videoer: Navn på emnet"
description: "Utvalgte videoer som forklarer temaene i emnet."
order: 99
---

# Videoer: Navn på emnet

> Lenkene er kontrollert, og videoene var offentlig tilgjengelige i <måned og år>.

## Tema 1 …
```

**Regler for videolenker:**

| Regel | Hvorfor |
|---|---|
| Bruk den vanlige lenken `https://www.youtube.com/watch?v=…`, ikke lenker med `&list=` eller `&t=` | Kortere, og den virker selv om spillelisten endres |
| Kopier tittelen nøyaktig | Studentene skal kjenne igjen videoen |
| Skriv kanal og lengde | Studentene ser hvem som står bak, og hvor lang tid det tar |
| Åpne lenken og se på videoen før du legger den inn | Videoer blir slettet eller gjort private. **Dikt aldri opp lenker**, og ikke stol blindt på lenker fra AI. |
| Foretrekk offisielle kanaler (Microsoft, SAP, Visual Studio Code, GitHub) og kjente fagfolk | Mer korrekt og oftere oppdatert |
| Si fra når en video er gammel eller viser et utdatert grensesnitt | Studentene blir ikke forvirret |
| Bygg ikke inn videoen i siden, bruk vanlig lenke | Raskere side, og ingen sporing fra YouTube før studenten selv klikker |

> 💡 **Rask sjekk av at en YouTube-lenke virker:** Åpne `https://www.youtube.com/oembed?url=` etterfulgt av video-lenken i nettleseren. Får du tilbake tittel og kanal, er videoen offentlig. Får du «Not Found» eller «Unauthorized», er den slettet eller privat.

---

## 13. Har du et ferdig, langt dokument?

Har du allerede et langt undervisningsdokument, for eksempel 1 000 linjer, bør du **dele det opp** i flere temaer. Da kan studentene markere hver del som fullført, og fremdriften blir meningsfull.

### Slik deler du opp

1. **Finn de naturlige delene.** Ofte er det `##`-kapitlene. Slå sammen korte kapitler som hører sammen.

   ```text
   ## 1. Hva er Power BI?           ┐
   ## 2. Installasjon              ├→ 01-kom-i-gang.md
   ## 3. Grensesnittet             ┘
   ## 4. Datamodell                 → 02-datamodell.md
   ## 5. DAX-grunnlag              ┐
   ## 6. Tidsintelligens           ┘→ 03-dax.md
   ## 7. Øvingsoppgaver             → 04-oppgaver.md
   ```

2. **Lag én fil per del** og kopier inn kapitlene.
3. **Legg frontmatter øverst** i hver fil (`title`, `description`, `order`).
4. **Legg til en `#`-tittel** under frontmatter i hver fil.
5. **Fjern innholdsfortegnelsen** fra originalen. Portalen lager menyen og «Innhold på denne siden» selv.
6. **Sjekk lenker** som pekte til andre kapitler (`#5-dax-grunnlag`). Ligger kapitlet nå i en annen fil, må lenken bli `03-dax.md#5-dax-grunnlag`.
7. **Gjør lærertips om til lærernotat:** `> **Lærernotat:** …`

> 💡 Emnene SAP Analytics Cloud, Microsoft Fabric og Agenter og skills er laget nettopp slik. Se på filene deres i `content/` som eksempler.

---

## 14. Endre, flytte eller fjerne et emne

| Hva du vil | Slik gjør du det | Påvirker studentenes fremdrift? |
|---|---|---|
| Endre emnets navn eller beskrivelse | Rediger `title`/`description` i `emne.json` | Nei |
| Endre rekkefølgen på emnene | Endre `order` i `emne.json` | Nei |
| Endre tittel eller rekkefølge på et tema | Rediger frontmatter i temafilen | Nei |
| Rette skrivefeil eller utvide innhold | Rediger temafilen | Nei |
| Legge til et tema | Lag ny `.md`-fil | Nei, men prosenten synker fordi det er flere temaer |
| Gi et tema nytt **filnavn** | Endre filnavnet | **Ja.** «Fullført» for det temaet forsvinner. |
| Gi emnemappen nytt **navn** | Endre mappenavnet | **Ja.** All fremdrift i emnet forsvinner. |
| Skjule et emne midlertidig | Gi mappen navnet `_power-bi` | Nei. Fremdriften er tilbake når understreken fjernes. |
| Skjule ett tema midlertidig | Gi filen navnet `_03-dax.md` | Nei, så lenge filnavnet ellers er likt |
| Slette et emne | Slett mappen | Fremdriften telles ikke lenger |

---

## 15. Feilsøking

| Problem | Sannsynlig årsak | Løsning |
|---|---|---|
| Emnet vises ikke | Mappen har ingen `.md`-filer | Legg til minst én temafil |
| Emnet vises ikke | Mappenavnet starter med `_` eller `.` | Gi mappen nytt navn |
| Emnet heter `power-bi` i stedet for det fine navnet | `emne.json` mangler eller heter noe annet | Sjekk at filen heter nøyaktig `emne.json` |
| `npm run dev` eller `npm run build` stopper med «Ugyldig JSON i …emne.json» | Syntaksfeil i `emne.json` | Se [vanlige JSON-feil](#vanlige-json-feil). Lim inn filen på <https://jsonlint.com> for å finne feilen. |
| `npm run dev` eller `npm run build` stopper med «Ugyldig frontmatter i …» | Feil i frontmatter-blokken i den filen som nevnes, ofte en manglende avsluttende `---` | Sjekk at det står `---` både før og etter feltene, og at tekst med kolon står i anførselstegn |
| Usikker på om alt er riktig satt opp | – | Kjør kontrollen `node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs` |
| Temaet heter det samme som filnavnet | Frontmatter mangler eller er feil | Sjekk at `---` står helt øverst, og at det er to `---`-linjer |
| Teksten `title: …` vises øverst på siden | Det er tom linje eller mellomrom før første `---` | Fjern alt før første `---` |
| Tittelen blir avkuttet ved kolon | Kolon uten anførselstegn | Skriv `title: "SAC: modell"` |
| Temaene står i feil rekkefølge | `order` mangler eller er lik | Gi hvert tema et unikt `order`-tall |
| Bildet vises ikke | Feil sti, eller stor/liten bokstav stemmer ikke | Stien er relativ til emnemappen. `Rapport.PNG` er ikke det samme som `rapport.png`. |
| Fasiten vises ikke bak knapp | Avsnittet starter ikke med `**Fasit` | Avsnittet må starte med `**Fasit` i fet skrift |
| For mye blir skjult bak «Vis fasit» | Det kommer ingen overskrift eller ny oppgave etter fasiten | Legg inn `---` eller en overskrift der fasiten skal slutte |
| Ingen fargekoding i koden | Språket mangler eller støttes ikke | Skriv ` ```sql ` osv. Se tabellen i kapittel 10. |
| Endringen vises ikke på den publiserte siden | Siden er ikke bygd på nytt | Kjør `git push` (GitHub Pages), eller `npm run build` og last opp `dist/` |
| Endringen vises ikke lokalt | Serveren kjører ikke, eller fanen er gammel | Sjekk at `npm run dev` kjører, og last siden på nytt med `Ctrl+F5` |
| Æ, ø og å vises som rare tegn | Filen er ikke lagret som UTF-8 | I VS Code: klikk på kodingen nederst til høyre → **Save with Encoding** → **UTF-8** |

---

## 16. Sjekkliste

Gå gjennom denne før du publiserer:

**Emnet**
- [ ] Mappenavnet bruker bare små bokstaver, tall og bindestrek
- [ ] `emne.json` har `title`, `description` og `order`
- [ ] `emne.json` er gyldig JSON (portalen starter uten feil)
- [ ] Emnet er lagt til i listen i `content/forside.md`

**Hvert tema**
- [ ] Filen slutter på `.md`, og filnavnet bruker bare små bokstaver, tall og bindestrek
- [ ] Frontmatter står helt øverst, med `title`, `description` og `order`
- [ ] Tekst med kolon står i anførselstegn
- [ ] Filen har én `#`-tittel
- [ ] Temaet har et tydelig mål og passer til én arbeidsøkt
- [ ] Kodeblokker har språknavn (` ```sql `)
- [ ] Bilder har beskrivende alt-tekst
- [ ] Fasit starter med `**Fasit:**`

**Til slutt**
- [ ] Sjekket i nettleseren med `npm run dev`: forside, emneside, alle temaer, «Forrige»/«Neste», «Vis fasit» og mobilvisning (smal nettleser)
- [ ] Publisert med `git push` eller `npm run build`

---

## 17. Komplett eksempel

Her er et lite, komplett emne du kan kopiere og bruke som mal.

### `content/power-bi/emne.json`

```json
{
  "title": "Power BI for nybegynnere",
  "description": "Fra Excel-ark til interaktiv rapport: datamodell, DAX og visualisering.",
  "order": 9
}
```

### `content/power-bi/01-kom-i-gang.md`

```markdown
---
title: "Kom i gang med Power BI"
description: "Installer Power BI Desktop, last inn data og lag din første visualisering."
order: 1
---

# Kom i gang med Power BI

**Mål:** Etter dette temaet kan du laste inn en Excel-fil og lage et søylediagram.

## 1. Installer

Installer **Power BI Desktop** fra Microsoft Store.

## 2. Last inn data

Velg **Hjem → Hent data → Excel-arbeidsbok**.

## 3. Første diagram

Dra `Kategori` til X-aksen og `Omsetning` til Y-aksen.

---

## Oppgaver

**Oppgave 1:** Hvilken kategori har høyest omsetning?

**Fasit:** Ski, med 13 895 kr.

**Oppgave 2:** Lag et linjediagram over tid.

**Fasit:** Dra `Dato` til X-aksen og velg nivået **Måned**.

> **Lærernotat:** Sjekk at alle har riktig datatype på `Dato` før oppgave 2.
```

### `content/power-bi/02-datamodell.md`

````markdown
---
title: "Datamodell og relasjoner"
description: "Koble tabeller sammen i et stjerneskjema."
order: 2
---

# Datamodell og relasjoner

**Mål:** Du kan forklare hva et stjerneskjema er og lage relasjoner i Power BI.

Les gjerne [Dimensjonsmodellering](#/emne/datavarehus/tema/02-samling-2) i Datavarehus-emnet først.

## Stjerneskjema

```text
          ┌────────────┐
          │ DimKunde   │
          └─────┬──────┘
┌──────────┐    │    ┌────────────┐
│DimProdukt├────┼────┤ DimDato    │
└──────────┘    │    └────────────┘
          ┌─────┴──────┐
          │ FaktSalg   │
          └────────────┘
```

## DAX-mål

DAX har ikke fargekoding i portalen, men vises fint som kode:

```dax
Total omsetning = SUM ( FaktSalg[Omsetning] )
```

Se [forrige tema](01-kom-i-gang.md) hvis du vil repetere.
````

Lagre filene, start `npm run dev`, og emnet med to temaer dukker opp på forsiden.
