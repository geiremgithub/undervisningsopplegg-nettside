# Veiledning: Slik jobber du med kursportalen i Git og GitHub

Denne veiledningen er for deg som skal **oppdatere kursportalen**, for eksempel legge til et nytt tema, rette en skrivefeil eller lage et helt nytt emne, og så **publisere** endringen så alle kan se den.

Du trenger **ingen** forkunnskaper om Git, GitHub eller terminal. Vi tar det steg for steg, og alle kommandoene kan du kopiere rett inn.

> 💡 **Ta det med ro.** Git kan virke skummelt i starten, men du bruker de samme 5–6 kommandoene hver gang. Etter et par runder sitter det. Og det fine med Git er at nesten alt kan rettes opp igjen.

---

## Innhold

1. [Hvordan kursportalen fungerer](#1-hvordan-kursportalen-fungerer)
2. [Ordliste: Git på vanlig norsk](#2-ordliste-git-på-vanlig-norsk)
3. [Oppsett første gang](#3-oppsett-første-gang)
4. [Daglig arbeidsflyt: lagre og publisere en ny versjon](#4-daglig-arbeidsflyt-lagre-og-publisere-en-ny-versjon)
5. [Hva skjer etter `git push`?](#5-hva-skjer-etter-git-push)
6. [Versjoner og historikk](#6-versjoner-og-historikk)
7. [Feilsøking: typiske problemer og løsninger](#7-feilsøking-typiske-problemer-og-løsninger)
8. [Hurtigreferanse (jukselapp)](#8-hurtigreferanse-jukselapp)

---

## 1. Hvordan kursportalen fungerer

### 1.1 Det store bildet

Kursportalen er en nettside som lages **automatisk** fra vanlige tekstfiler. Du skriver innholdet i **Markdown** (`.md`-filer), og et lite program gjør tekstfilene om til ferdige nettsider med meny, fremdriftsbar og knappene «Marker som fullført».

```text
   Du skriver tekst            Programmet bygger              Studentene ser
┌─────────────────────┐      ┌───────────────────┐      ┌──────────────────────────┐
│ content/            │      │                   │      │  Kursportal              │
│  power-bi/          │ ───▶ │  npm run build    │ ───▶ │  ▸ Power BI              │
│   emne.json         │      │  (Vite)           │      │     ○ Kom i gang         │
│   01-kom-i-gang.md  │      │                   │      │     ○ Datamodell         │
└─────────────────────┘      └───────────────────┘      └──────────────────────────┘
```

Du trenger aldri å endre selve programkoden for å legge til innhold. **Alt innhold ligger i mappen `content/`.**

### 1.2 Mappestrukturen

Dette er filene og mappene du møter i prosjektet:

```text
undervisningsopplegg-nettside/
├── content/                    ← 📝 HER JOBBER DU. Alt innhold ligger her.
│   ├── forside.md              ← Teksten «Om kursportalen» på forsiden
│   ├── datavarehus/            ← Ett emne = én mappe
│   │   ├── emne.json           ← Emnets navn, beskrivelse og rekkefølge
│   │   ├── 00-oversikt.md      ← Ett tema = én .md-fil
│   │   ├── 01-samling-1.md
│   │   └── case/               ← SQL-filer studentene kan laste ned
│   ├── sap-analytics-cloud/
│   ├── microsoft-fabric/
│   ├── agenter-og-skills/
│   ├── mcp-server/
│   ├── rag-losninger/
│   │   └── bilder/             ← Bilder som brukes i temaene
│   ├── microsoft-foundry/
│   └── git-og-github/
│
├── README.md                   ← Kort teknisk oversikt
├── VEILEDNING-nye-emner.md     ← Detaljert veiledning om å lage emner og temaer
├── VEILEDNING-git-og-publisering.md  ← Denne filen
├── site.config.json            ← Navnet på nettstedet
│
├── src/, scripts/, tests/      ← ⚙️ Programkoden. Trenger du ikke røre.
├── index.html, vite.config.js  ← ⚙️ Oppsett. Trenger du ikke røre.
├── package.json                ← ⚙️ Liste over hjelpeprogrammer prosjektet bruker
├── .github/workflows/deploy.yml← ⚙️ Oppskriften GitHub følger når siden publiseres
│
├── node_modules/               ← 🚫 Lages av `npm install`. Lastes ikke opp til GitHub.
└── dist/                       ← 🚫 Lages av `npm run build`. Lastes ikke opp til GitHub.
```

> Mappene `node_modules/` og `dist/` lages automatisk på din maskin. Filen `.gitignore` sørger for at Git ignorerer dem, så du trenger ikke tenke på dem.

Hvordan du skriver emner og temaer, står i [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md). Denne veiledningen handler om **hvordan du lagrer og publiserer** endringene.

### 1.3 Se portalen på din egen maskin

Før du publiserer, bør du alltid se på endringene **lokalt**, altså på din egen maskin:

```powershell
npm run dev
```

Åpne **http://localhost:5173** i nettleseren. Siden oppdateres automatisk hver gang du lagrer en fil i `content/`. Du stopper med **Ctrl + C** i terminalen.

> «Lokalt» betyr at det bare er du som ser det. Ingen andre ser endringene dine før du har publisert dem med Git.

### 1.4 Arbeidsflyten fra idé til publisert nettside

```text
  DIN MASKIN                                          GITHUB (på nettet)
 ─────────────────────────────────────────────        ──────────────────────────────────
  ① git pull         Hent det andre har gjort   ◀───  Repository (felles kopi)
  ② Rediger filer    i content/ med VS Code
  ③ npm run dev      Se resultatet lokalt
  ④ git add .        Velg hva som skal lagres
  ⑤ git commit       Lagre en versjon lokalt
  ⑥ git push         Last opp                    ───▶ Repository oppdateres
                                                        │
                                                        ▼
                                                      GitHub Actions bygger og tester
                                                        │
                                                        ▼
                                                      🌐 Nettsiden er oppdatert (1–3 min)
```

Hele kapittel 4 handler om disse seks stegene.

---

## 2. Ordliste: Git på vanlig norsk

| Ord | Hva det betyr | Hverdagslig sammenligning |
|---|---|---|
| **Git** | Et program som holder styr på alle versjoner av filene dine | «Versjonshistorikk» i Word eller Google Docs, men for hele mapper |
| **GitHub** | En nettside der Git-prosjekter lagres og deles | Som OneDrive eller Google Drive, laget for Git |
| **Repository** (repo) | Prosjektmappen med hele historikken | Prosjektmappen pluss alle tidligere versjoner |
| **Klone** (`clone`) | Laste ned en kopi av repoet til din maskin, første gang | Å laste ned hele mappen |
| **Commit** | En lagret versjon med en kort beskrivelse | Et øyeblikksbilde: «slik så det ut nå» |
| **Push** | Laste opp dine commits til GitHub | Å synkronisere opp til skyen |
| **Pull** | Hente andres commits fra GitHub til din maskin | Å synkronisere ned fra skyen |
| **Branch** (gren) | En egen arbeidslinje der du kan jobbe uten å påvirke hovedversjonen | En kladdekopi |
| **`main`** | Hovedgrenen. Det som ligger her, publiseres på nettsiden. | Den offisielle versjonen |
| **Merge** | Slå sammen endringer fra to steder | Å flette to dokumenter |
| **Konflikt** | To personer har endret samme linje, og Git vet ikke hvem som har rett | Når to har redigert samme setning |
| **Terminal** | Et vindu der du skriver kommandoer | «Ledetekst» eller PowerShell i Windows |

---

## 3. Oppsett første gang

Dette gjør du **bare én gang per maskin**.

### 3.1 Installer programmene

| Program | Hva det er til | Last ned |
|---|---|---|
| **Git** | Versjonskontroll | <https://git-scm.com/download/win>. Velg standardvalgene under installasjonen. |
| **Node.js** (versjon 20 eller nyere) | Trengs for å kjøre portalen lokalt | <https://nodejs.org>. Velg «LTS». |
| **VS Code** | Editor for å skrive filene | <https://code.visualstudio.com> |
| **GitHub-konto** | For å laste opp endringer | <https://github.com/signup> |

Sjekk at alt er installert. Åpne **PowerShell** (trykk Windows-tasten og skriv «PowerShell») og kjør:

```powershell
git --version
node --version
npm --version
```

Du skal få et versjonsnummer på hver linje, for eksempel `git version 2.47.0` og `v22.11.0`. Får du «ikke gjenkjent som en kommando», er programmet ikke installert, eller du må lukke og åpne PowerShell på nytt.

### 3.2 Fortell Git hvem du er

Hver versjon du lagrer, merkes med navnet og e-posten din. Kjør dette én gang, med ditt eget navn og den e-postadressen du bruker på GitHub:

```powershell
git config --global user.name "Kari Nordmann"
git config --global user.email "kari.nordmann@example.no"
git config --global pull.rebase false
```

Den siste linjen bestemmer hvordan `git pull` slår sammen endringer. Uten den kan Git stoppe med en forvirrende melding første gang du henter endringer.

### 3.3 Få tilgang til repoet

Be læreren om å legge deg til som **collaborator** (samarbeidspartner) på GitHub-repoet. Du får en e-post med en invitasjon som du må **godta**. Uten tilgang kan du laste ned prosjektet, men ikke laste opp endringer.

Du trenger også **adressen til repoet**. Den finner du på GitHub ved å klikke den grønne knappen **«<> Code»** og kopiere HTTPS-adressen. Den ser omtrent slik ut:

```text
https://github.com/<brukernavn>/<repo-navn>.git
```

### 3.4 Klon repoet (last ned prosjektet)

Prosjektet skal ligge i mappen `C:\Work`. Kjør i PowerShell:

```powershell
mkdir C:\Work
cd C:\Work
git clone https://github.com/<brukernavn>/<repo-navn>.git undervisningsopplegg-nettside
```

Bytt ut adressen med den du kopierte. Git lager nå mappen `C:\Work\undervisningsopplegg-nettside` med alle filene og hele historikken. Navnet til slutt i kommandoen sørger for at mappen får dette navnet, uansett hva repoet heter på GitHub.

> `cd` betyr «change directory», altså å gå inn i en mappe. `mkdir` lager en ny mappe. Finnes mappen `C:\Work` fra før, får du en feilmelding på `mkdir`. Den kan du se bort fra.

### 3.5 Åpne prosjektet i VS Code

```powershell
cd C:\Work\undervisningsopplegg-nettside
code .
```

`code .` åpner mappen du står i, i VS Code. Punktumet betyr «denne mappen». Du kan også åpne VS Code og velge **File → Open Folder…**.

> 💡 **Bruk terminalen inne i VS Code.** Velg **Terminal → New Terminal** i menyen. Da står du automatisk i prosjektmappen, og alle kommandoene i denne veiledningen kan kjøres der.

### 3.6 Installer avhengighetene

Prosjektet bruker noen hjelpeprogrammer (som Vite og Markdown-verktøy). De installeres med:

```powershell
npm install
```

Dette tar et halvt til to minutter og lager mappen `node_modules/`. Du trenger bare gjøre det første gang, og senere hvis noen har endret `package.json`.

### 3.7 Test at alt virker

```powershell
npm run dev
```

Åpne **http://localhost:5173**. Ser du kursportalen, er du klar. 🎉 Stopp serveren med **Ctrl + C**.

---

## 4. Daglig arbeidsflyt: lagre og publisere en ny versjon

Dette er rutinen du følger **hver gang** du skal gjøre endringer. Åpne prosjektet i VS Code og terminalen (**Terminal → New Terminal**) først.

### Steg 1: Hent siste endringer (`git pull`)

```powershell
git pull
```

**Gjør alltid dette først!** Andre kan ha lagt til eller endret filer siden sist du jobbet. `git pull` henter endringene deres til din maskin.

**Hvorfor er det viktig?** Tenk deg at du og en medstudent begge redigerer `forside.md`. Hvis du jobber på en gammel versjon, prøver du å laste opp noe som ikke passer med det som allerede ligger på GitHub. Da blir opplastingen avvist, eller dere får en *konflikt*. Starter du alltid med `git pull`, jobber du på den nyeste versjonen og unngår det meste av trøbbelet.

Typisk svar når alt er i orden:

```text
Already up to date.
```

eller, hvis noen har gjort endringer:

```text
Updating 3f2a1c9..8b7d4e2
Fast-forward
 content/forside.md | 2 ++
 1 file changed, 2 insertions(+)
```

### Steg 2: Gjør endringene dine

Rediger eller lag filer i `content/`. Se [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md) for hvordan du skriver emner og temaer.

Sjekk resultatet lokalt mens du jobber:

```powershell
npm run dev
```

> 💾 **Husk å lagre filene i VS Code** (`Ctrl + S`). En hvit prikk på fanen øverst betyr at filen ikke er lagret. Git ser bare det som er lagret på disken. Tips: Slå på **File → Auto Save**.

Når du er fornøyd, stopper du serveren med **Ctrl + C**, så du kan skrive Git-kommandoer i samme terminal. Du kan også åpne en terminal til med **+**-knappen.

### Steg 3: Se hva du har endret (`git status`)

```powershell
git status
```

Git viser hvilke filer som er endret eller nye:

```text
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
        modified:   content/forside.md

Untracked files:
        content/power-bi/
```

| Det Git skriver | Betyr |
|---|---|
| `modified:` | En fil som fantes fra før, og som du har endret |
| `deleted:` | En fil du har slettet |
| `Untracked files:` | Nye filer eller mapper Git ikke har sett før |
| `nothing to commit, working tree clean` | Ingen endringer siden forrige versjon |

> 💡 Kjør `git status` ofte. Den gjør ingen endringer, den bare viser hvordan det står til. Den kan aldri ødelegge noe.

### Steg 4: Velg hva som skal være med (`git add`)

Før du lagrer en versjon, forteller du Git **hvilke endringer** som skal være med.

**Ta med alle endringene** (det vanligste):

```powershell
git add .
```

Punktumet betyr «alt i denne mappen og undermappene».

**Ta bare med bestemte filer:**

```powershell
git add content/forside.md
git add content/power-bi/
```

Kjør `git status` igjen. Nå står filene under `Changes to be committed:` i grønt, klare til å lagres.

> **Hvorfor dette ekstra steget?** Noen ganger har du endret flere ting, men vil lagre dem som separate versjoner, for eksempel «rettet skrivefeil i SAP» og «nytt emne Power BI». Da tar du `git add` på bare de filene som hører sammen.

### Steg 5: Lagre en versjon (`git commit`)

```powershell
git commit -m "Legg til emne: Power BI for nybegynnere"
```

`-m` betyr «message», altså en kort beskrivelse av hva du har gjort. Versjonen lagres nå **på din maskin**. Den er ikke lastet opp ennå.

#### Slik skriver du en god commit-melding

En god melding forteller **hva** som er endret, slik at du og andre kan finne frem i historikken senere.

**Tommelfingerregel:** Fullfør setningen *«Denne endringen vil …»*

| ✅ God melding | ❌ Dårlig melding | Hvorfor den er dårlig |
|---|---|---|
| `Legg til emne: Power BI for nybegynnere` | `oppdatering` | Sier ingenting om hva |
| `Rett skrivefeil i SAP tema 3` | `fix` | Hvilken feil? Hvor? |
| `Legg til fasit på oppgave 4 i Fabric` | `asdf` | Meningsløst |
| `Oppdater beskrivelse av Datavarehus på forsiden` | `endret filer` | Alle commits endrer filer |
| `Del SAP-dokumentet i tre temaer` | `Jeg har nå jobbet med SAP-greiene og gjort masse forskjellig i flere filer i dag` | For lang og uklar |

**Tips:**

- Hold meldingen kort, helst under ca. 70 tegn.
- Start med et verb: *Legg til*, *Rett*, *Oppdater*, *Fjern*, *Del opp*.
- Én commit bør handle om **én ting**. Gjør du to ulike ting, kan du lage to commits.

### Steg 6: Last opp til GitHub (`git push`)

```powershell
git push
```

Commitene dine lastes nå opp til GitHub, og **nettsiden oppdateres automatisk** etter noen minutter (se [kapittel 5](#5-hva-skjer-etter-git-push)).

**Første gang** du kjører `git push`, åpnes et vindu der du logger inn på GitHub. Velg **«Sign in with your browser»** og godkjenn. Windows husker innloggingen etterpå.

Typisk svar:

```text
To https://github.com/<brukernavn>/<repo-navn>.git
   8b7d4e2..c41f9a7  main -> main
```

### Hele rutinen samlet

```powershell
git pull                                        # 1. Hent det nyeste
#                                                 2. Rediger filer, sjekk med: npm run dev
git status                                      # 3. Se hva som er endret
git add .                                       # 4. Ta med alle endringene
git commit -m "Beskriv kort hva du har gjort"   # 5. Lagre en versjon
git push                                        # 6. Last opp og publiser
```

### Alternativ: knapper i VS Code i stedet for terminal

VS Code har innebygd Git. Klikk på ikonet **Source Control** i venstre kant (tre prikker med streker, eller `Ctrl + Shift + G`):

| Terminal | VS Code |
|---|---|
| `git status` | Listen **Changes** viser endrede filer |
| `git add .` | Klikk **+** ved **Changes** |
| `git commit -m "..."` | Skriv meldingen i feltet øverst og klikk **✓ Commit** |
| `git pull` / `git push` | Klikk **Sync Changes** (gjør begge deler) |

Det er helt greit å bruke knappene. Kommandoene i terminalen er likevel nyttige å kunne, fordi de viser tydelig hva som skjer, og fordi feilmeldingene der er lettere å søke opp.

---

## 5. Hva skjer etter `git push`?

### 5.1 Automatisk bygging og publisering

Når nye commits kommer inn på grenen `main` på GitHub, starter **GitHub Actions** automatisk. Det er en tjeneste som kjører en oppskrift på GitHubs maskiner. Oppskriften ligger i `.github/workflows/deploy.yml` og gjør dette:

```text
git push ──▶ GitHub Actions starter
              ├─ 1. Henter prosjektet
              ├─ 2. Installerer avhengigheter          (npm install)
              ├─ 3. Kjører de automatiske testene      (npm test)
              ├─ 4. Bygger nettsiden                   (npm run build)
              └─ 5. Publiserer til GitHub Pages
                                  │
                                  ▼
                🌐 https://<brukernavn>.github.io/<repo-navn>/
```

Det tar vanligvis **1–3 minutter**.

> ⚠️ Feiler testene eller byggingen i steg 3 eller 4, blir **ingenting** publisert. Den gamle versjonen av nettsiden ligger da fortsatt ute. Det er en sikkerhetsmekanisme, så en feil ikke ødelegger siden for alle.

### 5.2 Slik sjekker du at publiseringen gikk bra

1. Gå til repoet på GitHub.
2. Klikk fanen **Actions** øverst.
3. Øverst i listen ser du kjøringen for din commit (den har commit-meldingen din som navn):

| Symbol | Betyr |
|---|---|
| 🟡 Gul sirkel | Kjører fortsatt. Vent litt. |
| ✅ Grønn hake | Ferdig. Nettsiden er oppdatert. |
| ❌ Rødt kryss | Noe feilet. Nettsiden er **ikke** oppdatert. |

4. Får du ❌, klikker du på kjøringen og deretter på jobben **build**. Åpne steget som har rødt kryss, så ser du feilmeldingen. Se også [kapittel 7](#7-feilsøking-typiske-problemer-og-løsninger).

Adressen til nettsiden finner du under **Settings → Pages** i repoet, eller ved å klikke kjøringen i **Actions** og deretter lenken under **deploy**.

### 5.3 Test før du pusher, så slipper du røde kryss

Du kan kjøre de samme kontrollene som GitHub på din egen maskin før du pusher:

```powershell
npm test
npm run build
```

Går begge gjennom uten feil, vil publiseringen nesten alltid gå bra.

---

## 6. Versjoner og historikk

Git husker **alle** versjoner som noen gang er lagret. Det betyr at du alltid kan se hva som er endret, av hvem og når.

### 6.1 Se historikken i terminalen

```powershell
git log --oneline
```

```text
c41f9a7 (HEAD -> main, origin/main) Legg til emne: Power BI for nybegynnere
8b7d4e2 Rett skrivefeil i SAP tema 3
3f2a1c9 Oppdater beskrivelse av Datavarehus på forsiden
```

Hver linje er én commit. Koden først (for eksempel `c41f9a7`) er commitens ID.

| Kommando | Viser |
|---|---|
| `git log --oneline` | Kort liste over alle versjoner |
| `git log --oneline -10` | Bare de 10 siste |
| `git log --oneline -- content/forside.md` | Bare versjoner der en bestemt fil er endret |
| `git show c41f9a7` | Nøyaktig hva som ble endret i en bestemt commit |

Trykk **q** for å avslutte hvis listen blir lang og terminalen «henger».

### 6.2 Se historikken på GitHub

- **Hele prosjektet:** Klikk **Commits** (klokkeikonet med et tall) på forsiden av repoet.
- **Én fil:** Åpne filen på GitHub og klikk **History**.
- Klikk på en commit for å se hva som ble endret. Grønne linjer er lagt til, og røde linjer er fjernet.

### 6.3 Jobbe på en egen gren (branch)

Det som ligger på `main`, publiseres med én gang. Skal du gjøre en **større endring**, for eksempel lage et helt nytt emne over flere dager, kan det være lurt å jobbe på en egen **gren**. Da kan du lagre og laste opp så mye du vil uten at nettsiden endres før du er ferdig.

**1. Lag en ny gren og bytt til den:**

```powershell
git pull
git checkout -b nytt-emne-power-bi
```

`-b` betyr «lag ny gren». Gi grenen et beskrivende navn med små bokstaver og bindestrek. (Nyere Git har også kommandoen `git switch -c nytt-emne-power-bi`, som gjør det samme.)

**2. Jobb som vanlig** med `git add` og `git commit`.

**3. Last opp grenen første gang:**

```powershell
git push -u origin nytt-emne-power-bi
```

`-u` kobler grenen din til grenen på GitHub. Senere holder det med `git push`.

> Commits på en egen gren blir **ikke** publisert på nettsiden. Bare `main` publiseres.

**4. Når du er ferdig, lager du en Pull Request på GitHub:**

1. Gå til repoet på GitHub. Du ser en gul boks: **«nytt-emne-power-bi had recent pushes»**. Klikk **Compare & pull request**.
2. Skriv en kort beskrivelse av hva du har laget, og klikk **Create pull request**.
3. Læreren eller en medstudent kan se gjennom endringene og kommentere.
4. Når alt er klart, klikker noen **Merge pull request**. Endringene havner da på `main` og publiseres automatisk.

**5. Gå tilbake til `main` på din maskin:**

```powershell
git checkout main
git pull
```

| Kommando | Gjør |
|---|---|
| `git branch` | Viser alle grenene. Den du står på, er merket med `*`. |
| `git checkout main` | Bytter til grenen `main` |
| `git checkout -b <navn>` | Lager en ny gren og bytter til den |

### 6.4 Merke en versjon med tag og release

Skal du markere at kursportalen er klar for et nytt semester, kan du lage en **tag**: et navn på en bestemt versjon, for eksempel `v2026-host`.

```powershell
git tag -a v2026-host -m "Kursopplegg høsten 2026"
git push origin v2026-host
```

Vil du lage en **release** med beskrivelse på GitHub:

1. Klikk **Releases** på forsiden av repoet, og deretter **Draft a new release**.
2. Velg taggen du nettopp lastet opp.
3. Skriv hva som er nytt, for eksempel «Nytt emne: Power BI. Oppdaterte oppgaver i SAP.».
4. Klikk **Publish release**.

Senere kan alle se nøyaktig hvordan opplegget så ut i den versjonen, og laste det ned som ZIP.

---

## 7. Feilsøking: typiske problemer og løsninger

> 💡 **Første regel:** Les feilmeldingen. Git forteller ofte selv hva du bør gjøre, i linjer som starter med `hint:`.

### 7.1 `git push` blir avvist: «rejected … fetch first»

```text
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'https://github.com/...'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. ...
```

**Hva betyr det?** Noen andre har lastet opp endringer etter at du kjørte `git pull`. GitHub nekter å ta imot din versjon før du har hentet deres.

**Løsning:**

```powershell
git pull
git push
```

`git pull` slår sammen endringene deres med dine. Har dere endret **forskjellige** filer eller linjer, skjer det automatisk. Da kan det åpnes en editor med en ferdig melding som «Merge branch 'main' of …». Lagre og lukk den. I VS Code lukker du fanen. Deretter kjører du `git push`.

Har dere endret **samme linje**, får du en konflikt. Se neste avsnitt.

### 7.2 Merge-konflikt: «CONFLICT (content)»

```text
Auto-merging content/forside.md
CONFLICT (content): Merge conflict in content/forside.md
Automatic merge failed; fix conflicts and then commit the result.
```

**Hva betyr det?** Du og noen andre har endret **den samme linjen** i den samme filen. Git vet ikke hvilken versjon som er riktig, så du må velge.

**Løsning steg for steg:**

1. **Ikke få panikk.** Ingenting er ødelagt. Git venter bare på at du skal bestemme.
2. Åpne filen i VS Code. Konflikten ser slik ut:

   ```text
   <<<<<<< HEAD
   - **Power BI:** Fra Excel til rapport.
   =======
   - **Power BI:** Lær datamodellering og DAX.
   >>>>>>> 8b7d4e2...
   ```

   | Del | Betyr |
   |---|---|
   | Mellom `<<<<<<< HEAD` og `=======` | **Din** versjon |
   | Mellom `=======` og `>>>>>>>` | Den **andre** sin versjon |

3. VS Code viser knapper rett over konflikten:
   - **Accept Current Change** beholder din versjon.
   - **Accept Incoming Change** beholder den andre sin versjon.
   - **Accept Both Changes** beholder begge.

   Du kan også redigere teksten for hånd. Det viktigste er at alle linjene med `<<<<<<<`, `=======` og `>>>>>>>` er **borte** når du er ferdig.
4. Lagre filen (`Ctrl + S`).
5. Fortell Git at konflikten er løst, og fullfør:

   ```powershell
   git add .
   git commit -m "Løs konflikt i forside.md"
   git push
   ```

**Vil du heller avbryte og starte på nytt?**

```powershell
git merge --abort
```

Da er alt som før du kjørte `git pull`. Be gjerne læreren om hjelp.

> 🛡️ **Slik unngår du konflikter:** Kjør `git pull` **før** du begynner å jobbe, og push ofte, gjerne etter hver ferdige bit. Avtal med de andre hvem som jobber i hvilke filer.

### 7.3 Jeg har glemt å lagre eller ta med filer

| Problem | Slik merker du det | Løsning |
|---|---|---|
| Glemt å lagre i VS Code | Hvit prikk på fanen. `git status` viser ikke endringen. | Trykk `Ctrl + S`, og kjør `git add .` og `git commit` på nytt |
| Glemt `git add` før commit | `git status` viser fortsatt filer under «Changes not staged» eller «Untracked» | `git add .`, deretter `git commit -m "Legg til manglende filer"` |
| Glemt `git push` | Endringen er ikke på GitHub. `git status` sier *«Your branch is ahead of 'origin/main' by 1 commit»*. | `git push` |
| Skrev feil commit-melding (ikke pushet ennå) | Du ser feilen i `git log --oneline` | `git commit --amend -m "Riktig melding"` |
| Vil angre endringer i en fil som **ikke** er committet | Du har rotet til en fil og vil tilbake til forrige lagrede versjon | `git restore content/forside.md` ⚠️ Endringene i filen forsvinner for godt. |

> ⚠️ Bruk **ikke** `git commit --amend` på en commit du allerede har pushet. Da får du problemer med `git push`. Lag heller en ny commit som retter feilen.

### 7.4 Endringene vises ikke på nettsiden

Gå gjennom listen ovenfra og ned:

| Mulig årsak | Sjekk | Løsning |
|---|---|---|
| Du har ikke pushet | `git status` sier «ahead of 'origin/main'» | `git push` |
| Publiseringen pågår fortsatt | **Actions** på GitHub viser 🟡 | Vent 1–3 minutter |
| Publiseringen feilet | **Actions** viser ❌ | Se 7.5 |
| Du pushet til en annen gren enn `main` | `git branch` viser at du står på en annen gren | Lag en Pull Request til `main` (se 6.3) |
| Nettleseren viser en gammel kopi (cache) | Siden ser ut som før | Last siden på nytt med **Ctrl + F5**, eller åpne den i et privat vindu |
| Filen ble ikke med | Filen mangler på GitHub | `git add` og `git commit` filen, og så `git push` |
| Emnet har ingen temaer, eller mappen starter med `_` | Emnet vises heller ikke lokalt | Se [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md), kapittel 15 |

### 7.5 Publiseringen feilet (❌ i Actions)

1. Åpne kjøringen i **Actions**, og klikk **build**.
2. Finn steget med rødt kryss:

| Steg som feilet | Vanlig årsak | Løsning |
|---|---|---|
| **Run npm install** | `package-lock.json` passer ikke med `package.json` | Kjør `npm install` lokalt, og commit og push `package-lock.json` |
| **Run npm test** | En test feiler | Kjør `npm test` lokalt og les feilmeldingen |
| **Run npm run build** | For eksempel «Ugyldig JSON i …emne.json» | Rett filen. Se [VEILEDNING-nye-emner.md](VEILEDNING-nye-emner.md), kapittel 4. Test med `npm run build` lokalt. |
| **deploy** | GitHub Pages er ikke slått på | **Settings → Pages → Source: GitHub Actions** (må gjøres av den som eier repoet) |

3. Rett feilen lokalt, sjekk med `npm test` og `npm run build`, og gjør så `git add`, `git commit` og `git push`. En ny kjøring starter automatisk.

### 7.6 Andre vanlige meldinger

| Melding | Betyr | Løsning |
|---|---|---|
| `fatal: not a git repository` | Du står i feil mappe | `cd` til prosjektmappen, eller åpne terminalen fra VS Code |
| `'git' is not recognized` / `'npm' is not recognized` | Programmet er ikke installert, eller terminalen er åpnet før installasjonen | Installer (se 3.1), og lukk og åpne terminalen |
| `Permission denied` / `403` ved push | Du har ikke skrivetilgang til repoet | Be læreren legge deg til som collaborator, og godta invitasjonen |
| `hint: You have divergent branches …` | `git pull` vet ikke hvordan den skal slå sammen | Kjør `git config --global pull.rebase false` én gang, og så `git pull` igjen |
| `Your local changes … would be overwritten by merge` | Du har ulagrede endringer i en fil som også er endret på GitHub | Commit først (`git add .` og `git commit -m "..."`), og kjør så `git pull` |
| Terminalen viser `:` eller `(END)` og «henger» | Git viser en lang liste | Trykk **q** |
| Det åpnes en editor med tekst om «Merge branch …» | Git vil ha en melding for sammenslåingen | Lagre og lukk. I VS Code lukker du fanen. |
| `Port 5173 is in use` ved `npm run dev` | Portalen kjører allerede i en annen terminal | Bruk den som kjører, eller stopp den med **Ctrl + C** |

> 🙋 **Står du fast?** Kopier hele feilmeldingen og send den til læreren sammen med kommandoen du kjørte og resultatet av `git status`. Da er det mye lettere å hjelpe.

---

## 8. Hurtigreferanse (jukselapp)

### De viktigste kommandoene

| Kommando | Hva den gjør | Når du bruker den |
|---|---|---|
| `git pull` | Henter de nyeste endringene fra GitHub | **Alltid først**, før du begynner å jobbe |
| `git status` | Viser hvilke filer som er endret, nye eller klare til lagring | Når som helst. Den endrer ingenting. |
| `git add .` | Tar med alle endringer i neste versjon | Når du er ferdig med en bit og vil lagre |
| `git commit -m "melding"` | Lagrer en versjon lokalt med en beskrivelse | Rett etter `git add` |
| `git push` | Laster opp versjonene til GitHub, og publiserer hvis du er på `main` | Når du vil dele eller publisere |
| `git log --oneline` | Viser historikken (trykk **q** for å avslutte) | Når du vil se tidligere versjoner |

### Rutinen hver gang

```powershell
git pull
npm run dev                       # rediger og se resultatet, stopp med Ctrl + C
git status
git add .
git commit -m "Beskriv kort hva du har gjort"
git push
```

### Kommandoer for portalen

| Kommando | Hva den gjør |
|---|---|
| `npm install` | Installerer avhengigheter (første gang, og når `package.json` er endret) |
| `npm run dev` | Viser portalen lokalt på http://localhost:5173 med automatisk oppdatering |
| `npm test` | Kjører de automatiske testene |
| `npm run build` | Bygger den ferdige nettsiden, som en sjekk før push |

### Litt mer avansert

| Kommando | Hva den gjør |
|---|---|
| `git clone <adresse>` | Laster ned repoet første gang |
| `git checkout -b <navn>` | Lager en ny gren og bytter til den |
| `git checkout main` | Bytter tilbake til hovedgrenen |
| `git push -u origin <navn>` | Laster opp en ny gren første gang |
| `git restore <fil>` | Angrer ulagrede endringer i en fil ⚠️ |
| `git merge --abort` | Avbryter en sammenslåing med konflikt |
| `git tag -a <navn> -m "..."` og `git push origin <navn>` | Merker en versjon, for eksempel ved semesterstart |

---

*Lykke til! Husk: alle har kjørt `git push` på feil tidspunkt minst én gang. Det er sånn man lærer. 🚀*
