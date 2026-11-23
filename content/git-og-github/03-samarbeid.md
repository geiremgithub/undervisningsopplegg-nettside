---
title: "Samarbeid og arbeidsflyt på GitHub"
description: "Hvordan en gruppe jobber sammen med branches, pull requests og code review, og hvordan merge-konflikter oppstår og løses."
order: 3
---

# Samarbeid og arbeidsflyt på GitHub

**Mål:** Etter dette temaet kan du jobbe i en gruppe på GitHub uten å overskrive hverandres arbeid. Du kan lage en pull request, gi og få code review, og løse en merge-konflikt.

**Forkunnskaper:** [De viktigste Git-kommandoene](02-kommandoer.md).

---

## 1. Arbeidsflyten: GitHub flow

De fleste grupper og mange bedrifter bruker en enkel arbeidsflyt som kalles **GitHub flow**. Den har én regel: **`main` skal alltid virke**. Alt nytt arbeid skjer i egne grener og kommer inn i `main` via en pull request.

```text
  main  ●───────────────────────────────────────●──────────▶
         \                                     ╱ ⑥ merge
          \ ① lag gren                        ╱
           ●──────●──────●  ③ push  ──▶  ④ Pull request ──▶ ⑤ review og tester
             ② commit  commit
```

| Steg | Hva du gjør | Kommando / sted |
|---|---|---|
| ① | Hent siste `main`, og lag en gren for oppgaven | `git switch main`, `git pull`, `git switch -c legg-til-sok` |
| ② | Jobb og commit i små steg | `git add .`, `git commit -m "…"` |
| ③ | Push grenen til GitHub | `git push -u origin legg-til-sok` |
| ④ | Lag en **pull request** | På github.com |
| ⑤ | Gruppen gir **code review**, og automatiske tester kjører | På github.com |
| ⑥ | **Merge** inn i `main`, og slett grenen | Knappen *Merge pull request* |
| ⑦ | Alle henter den nye `main` | `git switch main`, `git pull` |

> **Hvorfor ikke bare jobbe rett i `main`?** Fordi det blir kaos når fire personer pusher til samme gren hele tiden. Med egne grener kan hver person jobbe i fred, og ingen endring kommer inn i `main` uten at noen andre har sett på den.

---

## 2. Branches i gruppearbeid

En god regel er **én gren per oppgave**, ikke én gren per person. Er oppgavene i et prosjektstyringsverktøy eller i GitHub Issues, kan du ta med saksnummeret i navnet.

```bash
# Kari starter på sak #12
git switch main
git pull
git switch -c 12-sokefelt

# ... jobber og committer ...
git push -u origin 12-sokefelt
```

**Gode vaner:**

- **Små grener som lever kort.** En gren som lever i én til to dager er lett å flette. En gren som lever i tre uker gir nesten alltid konflikter.
- **Hent `main` ofte.** Jobber du lenge på en gren, kan du hente de andres endringer inn i den underveis:

  ```bash
  git switch 12-sokefelt
  git fetch
  git merge origin/main     # tar inn det nye fra main, og konfliktene kommer tidlig og er små
  ```

- **Beskytt `main`.** Eieren av repoet kan under **Settings → Branches** (eller *Rules → Rulesets*) kreve at alle endringer i `main` går via en pull request med minst én godkjenning.

---

## 3. Pull requests og code review

En **pull request** (PR) er en forespørsel om å flette en gren inn i `main`. Navnet betyr «vær så snill å *pull*-e (hente) endringene mine». En PR er også et **diskusjonsforum** for endringen.

### Slik lager du en pull request

1. Push grenen din (`git push -u origin 12-sokefelt`).
2. Gå til repoet på github.com. Du ser et gult banner: **«12-sokefelt had recent pushes»**. Klikk **Compare & pull request**.
3. Sjekk at **base** er `main` og **compare** er grenen din.
4. Skriv en god **tittel** og **beskrivelse**:

   ```markdown
   ## Hva
   Legger til et søkefelt over handlelisten som filtrerer varene mens du skriver.

   ## Hvorfor
   Lukker #12. Listene blir lange, og det er vanskelig å finne varer.

   ## Slik tester du
   1. Kjør `npm run dev`
   2. Legg til fem varer, og skriv «mel» i søkefeltet
   3. Bare «Hvetemel» skal vises
   ```

   Skriver du `Lukker #12` (eller `Closes #12`), lukkes saken automatisk når PR-en merges.

5. Velg en **Reviewer** til høyre, og klikk **Create pull request**.

> **Tips:** Er du ikke ferdig, men vil vise fram arbeidet? Velg **Create draft pull request**. Da kan ingen merge den før du markerer den som klar.

### Code review: å se over hverandres kode

Den som får en review-forespørsel, åpner fanen **Files changed** i PR-en. Der kan hun:

- klikke **+** ved en linje for å skrive en **kommentar**,
- foreslå en konkret endring med en **suggestion** som forfatteren kan godta med ett klikk,
- avslutte med **Review changes** og velge:

| Valg | Betyr |
|---|---|
| **Comment** | Generelle kommentarer, uten å godkjenne eller avvise |
| **Approve** | «Ser bra ut, kan merges» |
| **Request changes** | «Dette må rettes før merge» |

Forfatteren retter ved å gjøre nye commits på **samme gren** og pushe. PR-en oppdateres automatisk, så du trenger ikke lage en ny.

**Slik gir du god code review:**

- Vær **vennlig og konkret**: «Kan vi kalle variabelen `antallVarer` i stedet for `x`? Da er det lettere å lese.» er bedre enn «dårlig navn».
- **Still spørsmål** når du er usikker: «Hva skjer her hvis listen er tom?»
- **Ros** det som er bra. Det er også en del av review.
- Sjekk at koden faktisk **virker**: hent grenen og test den (`git fetch`, `git switch 12-sokefelt`).

### Merge pull request

Når PR-en er godkjent og eventuelle tester er grønne, klikker du **Merge pull request**. GitHub tilbyr tre varianter:

| Variant | Hva skjer | Når |
|---|---|---|
| **Create a merge commit** | Alle commitene beholdes, pluss en merge-commit | Når historikken i grenen er nyttig |
| **Squash and merge** | Alle commitene i PR-en slås sammen til én | Vanlig i studentprosjekter: gir en ryddig `main` |
| **Rebase and merge** | Commitene legges én og én oppå `main`, uten merge-commit | Når man vil ha helt rett historikk |

Klikk så **Delete branch**, og hent den nye `main` lokalt:

```bash
git switch main
git pull
git branch -d 12-sokefelt    # slett den lokale grenen også
```

---

## 4. Merge-konflikter

### Hvordan oppstår en konflikt?

En **merge-konflikt** oppstår når to grener har endret **de samme linjene** i samme fil, og Git ikke kan vite hvilken versjon som er riktig. Endringer i *ulike* linjer eller filer flettes automatisk.

Eksempel: Kari og Ola starter fra samme `main`, der `index.html` har denne linjen:

```html
<h1>Handleliste</h1>
```

- Kari endrer linjen til `<h1>Min handleliste</h1>` og får PR-en sin merget først.
- Ola endrer samme linje til `<h1>Handleliste 2.0</h1>`.

Når Ola henter `main` inn i grenen sin, stopper Git:

```bash
$ git merge origin/main
Auto-merging index.html
CONFLICT (content): Merge conflict in index.html
Automatic merge failed; fix conflicts and then commit the result.

$ git status
You have unmerged paths.
  (fix conflicts and run "git commit")
Unmerged paths:
  (use "git add <file>..." to mark resolution)
        both modified:   index.html
```

### Slik ser konflikten ut i filen

Git skriver **begge versjonene** inn i filen, med markører rundt:

```text
<<<<<<< HEAD
<h1>Handleliste 2.0</h1>
=======
<h1>Min handleliste</h1>
>>>>>>> origin/main
```

| Markør | Betyr |
|---|---|
| `<<<<<<< HEAD` | Starten på **din** versjon (grenen du står på) |
| `=======` | Skillet mellom de to versjonene |
| `>>>>>>> origin/main` | Slutten på **den andre** versjonen (det du fletter inn) |

### Slik løser du den

1. **Åpne filen**, og bestem hva som er riktig. Det kan være din versjon, den andre, eller en kombinasjon. Snakk med den andre personen hvis du er usikker!
2. **Fjern alle markørene** (`<<<<<<<`, `=======`, `>>>>>>>`), slik at bare den riktige koden står igjen:

   ```html
   <h1>Min handleliste 2.0</h1>
   ```

3. **Marker konflikten som løst, og fullfør flettingen:**

   ```bash
   git add index.html
   git commit -m "Slå sammen overskriftene fra Kari og Ola"
   git push
   ```

Ombestemmer du deg midt i, kan du avbryte og gå tilbake til slik det var før:

```bash
git merge --abort
```

> **Konflikt i en pull request?** Står det **«This branch has conflicts that must be resolved»** på GitHub, kan du løse enkle konflikter direkte i nettleseren med **Resolve conflicts**. Ellers gjør du som over: hent `main` inn i grenen lokalt, løs konflikten, og push. PR-en oppdateres automatisk.

### Slik unngår du de fleste konfliktene

- `git pull` **før** du begynner å jobbe, hver dag.
- Små grener og små PR-er som merges raskt.
- Fordel arbeidet så dere ikke endrer de samme filene samtidig.
- Ikke formater om hele filer (for eksempel bytte innrykk) i samme PR som en funksjon.

---

## Oppgaver

**Oppgave 1:** Sett stegene i GitHub flow i riktig rekkefølge: *merge*, *lag gren*, *push*, *code review*, *commit*, *lag pull request*, *pull main*.

**Fasit:** Pull main → lag gren → commit → push → lag pull request → code review → merge. Etter merge henter alle `main` på nytt.

**Oppgave 2:** Du har fått «Request changes» på PR-en din. Må du lage en ny pull request etter at du har rettet?

**Fasit:** Nei. Gjør nye commits på samme gren og push. PR-en oppdateres automatisk, og reviewer kan se på den igjen.

**Oppgave 3:** Ola får denne konflikten. Løs den slik at begge varene blir med.

```text
<ul>
<<<<<<< HEAD
  <li>Melk</li>
=======
  <li>Brød</li>
>>>>>>> 12-sokefelt
</ul>
```

**Fasit:**

```html
<ul>
  <li>Melk</li>
  <li>Brød</li>
</ul>
```

Så `git add index.html` og `git commit`. Alle tre markørlinjene skal være borte.

**Oppgave 4 (gruppeøvelse, 30 min):** Gå sammen tre og tre.

1. Én person lager et repo på GitHub med en `README.md` og inviterer de andre under **Settings → Collaborators**.
2. Alle kloner repoet.
3. Hver person lager sin egen gren og legger til en linje med navnet sitt **på samme sted** i `README.md`.
4. Alle pusher og lager en PR. Én PR merges først.
5. De to andre løser konflikten som oppstår, og merger sin PR.

**Fasit:** Etter øvelsen skal `README.md` i `main` ha tre linjer, én per person. `git log --oneline --graph` skal vise grenene og merge-commitene. Den andre og tredje personen fikk konflikt fordi de endret samme linje som en PR som allerede var merget.

> **Lærernotat:** Oppgave 4 er den viktigste i hele emnet. Studentene *skal* oppleve en konflikt mens læreren er i rommet, slik at det ikke er skummelt første gang det skjer i prosjektet. Sjekk at alle har logget inn i Git fra terminalen før timen, for innlogging tar ofte mest tid.
