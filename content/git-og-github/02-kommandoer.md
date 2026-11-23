---
title: "De viktigste Git-kommandoene"
description: "init, clone, status, add, commit, pull, push, branch, switch/checkout og merge, med forklaring av hva som skjer under panseret og eksempler du kan kopiere."
order: 2
---

# De viktigste Git-kommandoene

**Mål:** Etter dette temaet kan du bruke de ti kommandoene du trenger i nesten alt daglig arbeid, og du vet hva hver av dem faktisk gjør inne i Git.

**Forkunnskaper:** [Grunnleggende virkemåte](01-grunnleggende.md), særlig de fire stedene en endring går gjennom.

> **Slik leser du eksemplene:** Linjer som starter med `#` er kommentarer, og linjer som starter med `$` er det du skriver. Resten er det Git svarer. Du skriver kommandoene i en terminal: **PowerShell** eller **Git Bash** på Windows, **Terminal** på Mac. I VS Code åpner du terminalen med **Ctrl+ø** (norsk tastatur) eller via menyen **Terminal → New Terminal**.

---

## Oversikt

| Gruppe | Kommando | Kort sagt |
|---|---|---|
| Oppsett og kloning | [`git init`](#git-init) | Gjør en mappe til et Git-repo |
| | [`git clone`](#git-clone) | Lager en lokal kopi av et repo fra GitHub |
| Lagre endringer | [`git status`](#git-status) | Viser hva som er endret og hva som er klart til commit |
| | [`git add`](#git-add) | Legger endringer i staging area |
| | [`git commit`](#git-commit) | Lagrer et øyeblikksbilde i det lokale repoet |
| Synkronisering | [`git pull`](#git-pull) | Henter og fletter inn andres endringer fra GitHub |
| | [`git push`](#git-push) | Sender dine commits til GitHub |
| Forgrening og samarbeid | [`git branch`](#git-branch) | Lister, lager og sletter grener |
| | [`git switch` / `git checkout`](#git-switch-og-git-checkout) | Bytter til en annen gren |
| | [`git merge`](#git-merge) | Fletter en gren inn i den du står på |

---

## Oppsett og kloning

### `git init`

**Hva den gjør:** Gjør en vanlig mappe om til et Git-repository, slik at Git begynner å holde øye med den.

**Under panseret:** Git lager en skjult undermappe `.git`. Der ligger hele «databasen»:

- `.git/objects/` – alt innhold og alle commits, lagret som komprimerte objekter med en hash som navn,
- `.git/refs/heads/` – grenene, der hver gren bare er en liten fil med ID-en til siste commit,
- `.git/HEAD` – hvilken gren du står på nå,
- `.git/config` – innstillinger for dette repoet, for eksempel adressen til GitHub.

Filene dine blir **ikke** endret eller flyttet. Sletter du `.git`-mappen, er historikken borte, men filene er der fortsatt.

**Eksempel:** Start et nytt prosjekt fra bunnen av.

```bash
$ mkdir handleliste-app
$ cd handleliste-app
$ git init
Initialized empty Git repository in C:/Work/handleliste-app/.git/

# Lag en første fil og ta det første øyeblikksbildet
$ echo "# Handleliste-app" > README.md
$ git add README.md
$ git commit -m "Første versjon med README"
```

> Bruk `git init` når du **starter** et prosjekt selv. Finnes prosjektet allerede på GitHub, bruker du `git clone` i stedet.

---

### `git clone`

**Hva den gjør:** Laster ned en fullstendig kopi av et repo fra GitHub (eller et annet sted) til PC-en din.

**Under panseret:** `git clone` gjør fire ting i én operasjon:

1. lager en ny mappe og kjører `git init` i den,
2. legger til GitHub-adressen som et eksternt repo med navnet `origin`,
3. laster ned **alle** commits og hele historikken (ikke bare siste versjon),
4. sjekker ut standardgrenen (vanligvis `main`) i arbeidsmappen og kobler den til `origin/main`, slik at `git pull` og `git push` vet hvor de skal.

**Eksempel:** Hent gruppeprosjektet.

```bash
# Gå til mappen der du vil ha prosjektet
$ cd C:\Work

# Kopier adressen fra den grønne «Code»-knappen på GitHub
$ git clone https://github.com/gruppe7/handleliste-app.git
Cloning into 'handleliste-app'...
remote: Enumerating objects: 48, done.
Receiving objects: 100% (48/48), done.

$ cd handleliste-app
$ git remote -v
origin  https://github.com/gruppe7/handleliste-app.git (fetch)
origin  https://github.com/gruppe7/handleliste-app.git (push)
```

> Er repoet privat, blir du bedt om å logge inn. På Windows åpnes et innloggingsvindu fra GitHub (Git Credential Manager). Du trenger ikke lage passord eller nøkler selv.

---

## Lagre endringer

### `git status`

**Hva den gjør:** Viser hvilken gren du står på, hvilke filer som er endret, hvilke som ligger i staging area, og om du ligger foran eller bak GitHub.

**Under panseret:** Git sammenligner tre ting: siste commit (HEAD), staging area (indeksen) og arbeidsmappen. Forskjellen mellom HEAD og indeksen er «klart til commit». Forskjellen mellom indeksen og arbeidsmappen er «endret, men ikke lagt til». Kommandoen **endrer ingenting**, så du kan kjøre den så ofte du vil.

**Eksempel:**

```bash
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes to be committed:                       ← ligger i staging area (grønt)
  (use "git restore --staged <file>..." to unstage)
        modified:   README.md

Changes not staged for commit:                 ← endret, men ikke lagt til (rødt)
  (use "git add <file>..." to update what will be committed)
        modified:   app.js

Untracked files:                               ← nye filer Git ikke følger ennå
  (use "git add <file>..." to include in what will be committed)
        handleliste.css

# Kortversjon: M = endret, A = lagt til, ?? = ny fil
$ git status -s
M  README.md
 M app.js
?? handleliste.css
```

> **Vane:** Kjør `git status` før `git add`, før `git commit` og før `git push`. Den forteller deg nesten alltid hva neste steg er.

---

### `git add`

**Hva den gjør:** Legger endringer i staging area, altså «handlekurven» for neste commit.

**Under panseret:** For hver fil regner Git ut en hash av innholdet, lagrer innholdet som et **blob-objekt** i `.git/objects/`, og oppdaterer indeksen så den peker på den nye versjonen. Det er innholdet *slik det var da du kjørte `git add`* som blir med. Endrer du filen etterpå, må du kjøre `git add` på nytt.

**Eksempel:**

```bash
# Legg til én bestemt fil
$ git add app.js

# Legg til flere filer
$ git add app.js handleliste.css

# Legg til alt som er endret og nytt i denne mappen og undermapper
$ git add .

# Angre: ta en fil ut av staging area (endringen i filen beholdes)
$ git restore --staged app.js
```

> **Pass på:** `git add .` tar med *alt*, også filer du kanskje ikke vil dele, som passord i `.env` eller mappen `node_modules`. Lag en fil som heter `.gitignore`, og skriv inn det Git skal overse:
>
> ```text
> node_modules/
> .env
> dist/
> ```

---

### `git commit`

**Hva den gjør:** Lagrer innholdet i staging area som et nytt øyeblikksbilde i det lokale repoet, med en melding som forklarer endringen.

**Under panseret:** Git lager et **tree-objekt** som beskriver mappestrukturen ut fra indeksen, og et **commit-objekt** som peker på treet, på forrige commit (forelderen), og som inneholder forfatter, tidspunkt og melding. Deretter flyttes grenen du står på (for eksempel `main`) til å peke på den nye commiten. Commiten får en unik ID, en hash som er regnet ut fra alt dette. Endrer du noe i en gammel commit, endres ID-en, og derfor er historikken svært vanskelig å forfalske.

**Eksempel:**

```bash
$ git commit -m "Legg til knapp for å slette varer fra listen"
[main 3f9c2a1] Legg til knapp for å slette varer fra listen
 2 files changed, 24 insertions(+), 3 deletions(-)

# Se historikken (én linje per commit)
$ git log --oneline
3f9c2a1 (HEAD -> main) Legg til knapp for å slette varer fra listen
a1b2c3d (origin/main) Første versjon med README

# Glemte du en fil, eller skrev feil i meldingen? Rett siste commit
# (bare før du har pushet!)
$ git add glemt-fil.js
$ git commit --amend -m "Legg til knapp for å slette varer fra listen"
```

**Gode og dårlige commit-meldinger:**

| ✅ God | ❌ Dårlig | Hvorfor |
|---|---|---|
| `Legg til knapp for å slette varer` | `endringer` | Sier *hva* som ble gjort |
| `Rett feil i totalsum når listen er tom` | `fix` | Den som leser historikken om et halvt år, forstår det |
| `Oppdater README med installasjonssteg` | `asdf` | |

> **Tommelfingerregel:** Skriv meldingen slik at den fullfører setningen «Denne commiten vil …». Én commit bør handle om én ting.

---

## Synkronisering

### `git pull`

**Hva den gjør:** Henter nye commits fra GitHub og fletter dem inn i grenen du står på.

**Under panseret:** `git pull` er to kommandoer i én:

1. `git fetch` – laster ned nye commits fra `origin` og oppdaterer `origin/main` lokalt. Arbeidsmappen din røres ikke.
2. `git merge origin/main` – fletter disse commitene inn i din `main`.

Har bare de andre gjort endringer, flyttes `main` rett frem (*fast-forward*). Har både du og de andre committet, lager Git en **merge-commit** som binder historikkene sammen. Har dere endret de samme linjene, får du en **merge-konflikt** (se [Samarbeid](03-samarbeid.md#4-merge-konflikter)).

**Eksempel:**

```bash
# Start ALLTID dagen med å hente det de andre har gjort
$ git pull
Updating a1b2c3d..7e8f9a0
Fast-forward
 app.js | 12 ++++++++----
 1 file changed, 8 insertions(+), 4 deletions(-)

# Vil du bare se hva som er nytt uten å flette det inn?
$ git fetch
$ git log --oneline main..origin/main
```

> **Får du «fatal: Need to specify how to reconcile divergent branches»?** Da har både du og andre committet, og Git vil vite om den skal flette (*merge*) eller legge commitene dine oppå (*rebase*). Kjør `git config --global pull.rebase false` én gang, og så `git pull` på nytt.

---

### `git push`

**Hva den gjør:** Sender commitene dine fra det lokale repoet til GitHub, slik at andre kan hente dem.

**Under panseret:** Git finner ut hvilke commits og objekter GitHub mangler, sender bare dem, og ber GitHub flytte grenen (for eksempel `main`) til din nyeste commit. GitHub sier **nei** hvis grenen der har commits som *du* ikke har. Det hindrer at du overskriver andres arbeid. Løsningen er da å kjøre `git pull` først.

**Eksempel:**

```bash
$ git push
Enumerating objects: 7, done.
Writing objects: 100% (4/4), 612 bytes | 612.00 KiB/s, done.
To https://github.com/gruppe7/handleliste-app.git
   a1b2c3d..3f9c2a1  main -> main

# Første gang du pusher en NY gren, må du si hvor den skal
$ git push -u origin legg-til-sletteknapp
# -u (--set-upstream) kobler grenen til GitHub, så neste gang holder det med «git push»
```

Slik ser det ut når noen andre har pushet før deg:

```bash
$ git push
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'https://github.com/gruppe7/handleliste-app.git'
hint: Updates were rejected because the remote contains work that you do not have locally.

# Løsning: hent først, så push
$ git pull
$ git push
```

> **Aldri** bruk `git push --force` på en gren andre jobber på. Det sletter commitene deres på GitHub.

---

## Forgrening og samarbeid

### `git branch`

**Hva den gjør:** Lister, lager, endrer navn på og sletter **grener** (*branches*). En gren er en egen utviklingslinje der du kan jobbe uten å påvirke `main`.

**Under panseret:** En gren er bare en **peker** til en commit, lagret som en liten fil i `.git/refs/heads/` med commitens ID. Derfor er det lynraskt og gratis å lage en gren, uansett hvor stort prosjektet er. Når du committer, flytter pekeren til grenen du står på seg fremover.

```text
                       ┌── c4 ◀── legg-til-sletteknapp
  c1 ◀── c2 ◀── c3 ◀───┤
                       └── c5 ◀── main
```

**Eksempel:**

```bash
# List lokale grener (* viser hvor du står)
$ git branch
* main
  legg-til-sletteknapp

# List også grener som finnes på GitHub
$ git branch -a

# Lag en ny gren (du blir stående der du er)
$ git branch rett-totalsum

# Slett en gren som er ferdig og flettet inn
$ git branch -d rett-totalsum
```

> **Navn på grener:** Bruk korte, beskrivende navn med bindestrek, for eksempel `legg-til-sletteknapp` eller `rett-innlogging`. Mange grupper bruker også ditt navn eller saksnummeret: `kari/12-sletteknapp`.

---

### `git switch` og `git checkout`

**Hva de gjør:** Bytter hvilken gren du står på, slik at arbeidsmappen viser filene slik de er i den grenen.

**Under panseret:** Git oppdaterer `HEAD` til å peke på den nye grenen, og skriver om filene i arbeidsmappen og indeksen så de stemmer med grenens siste commit. Har du endringer som ikke er committet og som ville blitt overskrevet, nekter Git å bytte. Da må du committe dem først (eller legge dem til side med `git stash`).

`git checkout` er den gamle kommandoen, og den gjør mange ting: bytter gren, henter gamle versjoner av filer og mer. Derfor kom Git 2.23 (2019) med to nye og tydeligere kommandoer: **`git switch`** for å bytte gren, og **`git restore`** for å hente tilbake filer. Begge fungerer. Du vil se `checkout` i mange veiledninger.

**Eksempel:**

```bash
# Lag en ny gren OG bytt til den (vanligst)
$ git switch -c legg-til-sletteknapp
Switched to a new branch 'legg-til-sletteknapp'

# Samme med den gamle kommandoen
$ git checkout -b legg-til-sletteknapp

# Bytt tilbake til main
$ git switch main          # eller: git checkout main

# Hent en gren som en annen i gruppen har pushet
$ git fetch
$ git switch karis-gren     # Git kobler den automatisk til origin/karis-gren

# Forkast endringer i én fil (gå tilbake til siste commit). Kan ikke angres!
$ git restore app.js        # eller: git checkout -- app.js
```

---

### `git merge`

**Hva den gjør:** Fletter endringene fra en annen gren inn i grenen du står på.

**Under panseret:** Git finner den siste commiten de to grenene har felles (*merge base*), og det kan skje på to måter:

- **Fast-forward:** Har `main` ikke fått nye commits siden grenen ble laget, flytter Git bare `main`-pekeren frem. Det blir ingen ny commit.
- **Treveis-fletting:** Har begge grenene nye commits, sammenligner Git felles utgangspunkt, din versjon og den andre versjonen. Endringer i ulike deler av filene flettes automatisk, og Git lager en **merge-commit** med to foreldre. Har begge endret de samme linjene, stopper Git med en **merge-konflikt** som du må løse.

```text
  Før:                                     Etter git merge legg-til-sletteknapp:
           ┌── c4 ◀── legg-til-sletteknapp            ┌── c4 ──┐
  c1 ◀── c3┤                                 c1 ◀── c3┤        ├── m1 ◀── main
           └── c5 ◀── main                            └── c5 ──┘   (merge-commit)
```

**Eksempel:**

```bash
# 1. Gå til grenen som skal TA IMOT endringene
$ git switch main

# 2. Sørg for at den er oppdatert
$ git pull

# 3. Flett inn grenen din
$ git merge legg-til-sletteknapp
Merge made by the 'ort' strategy.
 app.js | 18 ++++++++++++++++++
 1 file changed, 18 insertions(+)

# 4. Del resultatet og rydd opp
$ git push
$ git branch -d legg-til-sletteknapp
```

> I gruppearbeid fletter man som regel **ikke** inn i `main` lokalt. Man pusher grenen og lager en **pull request** på GitHub i stedet, slik at noen kan se over koden først. Se [Samarbeid og arbeidsflyt](03-samarbeid.md).

---

## Jukselapp: en vanlig arbeidsdag

```bash
git pull                                  # 1. Hent det de andre har gjort
git switch -c min-nye-funksjon            # 2. Lag en egen gren for oppgaven
# ... rediger filer og lagre ...
git status                                # 3. Se hva du har endret
git add .                                 # 4. Legg endringene i staging area
git commit -m "Legg til min nye funksjon" # 5. Lagre et øyeblikksbilde
git push -u origin min-nye-funksjon       # 6. Send grenen til GitHub
# 7. Lag en pull request på GitHub
```

| Jeg vil … | Kommando |
|---|---|
| se hva jeg har endret | `git status` og `git diff` |
| se historikken | `git log --oneline --graph` |
| angre `git add` | `git restore --staged <fil>` |
| forkaste endringer i en fil | `git restore <fil>` |
| rette siste commit (før push) | `git commit --amend` |
| angre en commit som er pushet | `git revert <commit-id>` (lager en ny commit som opphever den gamle) |
| legge endringer midlertidig til side | `git stash`, og senere `git stash pop` |

---

## Oppgaver

**Oppgave 1:** Lag en mappe `git-ovelse`, gjør den til et repo, lag filen `notater.txt` med én linje, og commit den. Kjør så `git log --oneline`. Hvilke kommandoer brukte du?

**Fasit:**

```bash
mkdir git-ovelse
cd git-ovelse
git init
echo "Min første linje" > notater.txt
git add notater.txt
git commit -m "Legg til notater"
git log --oneline
```

Du skal se én linje med en kort ID og meldingen «Legg til notater».

**Oppgave 2:** Endre `notater.txt` igjen. Kjør `git status` før og etter `git add`. Hva er forskjellen?

**Fasit:** Før `git add` står filen under «Changes not staged for commit» (rødt). Etter står den under «Changes to be committed» (grønt). Filen er flyttet fra arbeidsmappen til staging area.

**Oppgave 3:** Lag grenen `ny-ide`, bytt til den, legg til en linje i `notater.txt` og commit. Bytt tilbake til `main`. Hvorfor er linjen borte, og hvordan får du den inn i `main`?

**Fasit:** Linjen finnes bare i commiten på `ny-ide`. Når du bytter til `main`, viser arbeidsmappen filene slik de er i `main`. Du får den inn med `git switch main` og så `git merge ny-ide`. Det blir en fast-forward, fordi `main` ikke har fått nye commits.

```bash
git switch -c ny-ide
echo "En god idé" >> notater.txt
git commit -am "Legg til ny idé"
git switch main
git merge ny-ide
```

**Oppgave 4:** `git push` blir avvist med «Updates were rejected because the remote contains work that you do not have locally». Hva betyr det, og hva gjør du?

**Fasit:** Noen andre har pushet commits til samme gren etter at du sist hentet. Kjør `git pull` for å hente og flette dem inn (løs eventuelle konflikter), og så `git push` på nytt. Ikke bruk `--force`.

> **Lærernotat:** La studentene kjøre `git log --oneline --graph --all` etter oppgave 3. Da ser de at en gren bare er en etikett på en commit. Vil du vise at `.git` er «hele databasen», kan du la dem kopiere prosjektmappen, slette `.git` i kopien og kjøre `git status` der.
