---
title: "Grunnleggende virkemåte: Git og GitHub"
description: "Hva versjonskontroll er, forskjellen på Git og GitHub, og de fire stedene en endring går gjennom."
order: 1
---

# Grunnleggende virkemåte: Git og GitHub

**Mål:** Etter dette temaet kan du forklare hva versjonskontroll er, hva som er forskjellen på Git og GitHub, og hvilken vei en endring går fra du lagrer en fil til den ligger på GitHub.

**Forkunnskaper:** Ingen. Du trenger bare å kunne lagre filer på en PC.

---

## 1. Hva er versjonskontroll?

Kjenner du igjen dette?

```text
rapport.docx
rapport_v2.docx
rapport_v2_endelig.docx
rapport_v2_endelig_ENDELIG_rettet_av_Kari.docx
```

Det er versjonskontroll gjort for hånd, og det fungerer dårlig. Du vet ikke hva som ble endret, hvem som endret det, eller hvorfor. Og når to personer endrer samme fil samtidig, blir det kaos.

Et **versjonskontrollsystem** gjør dette automatisk og ryddig. Det tar **øyeblikksbilder** (*snapshots*) av prosjektet ditt når du ber om det, og husker:

| Det husker | Eksempel |
|---|---|
| **Hva** som ble endret | Linje 12 i `index.html` ble endret fra «Velkommen» til «Hei» |
| **Hvem** som endret det | Kari Nordmann |
| **Når** | 23. november kl. 14:02 |
| **Hvorfor** | «Gjør velkomstteksten mer uformell» |

Med versjonskontroll kan du:

- **gå tilbake** til en tidligere versjon hvis noe går galt,
- **se historikken** og forstå hvorfor koden ser ut som den gjør,
- **jobbe parallelt** med andre uten å overskrive hverandres arbeid,
- **prøve ut ideer** i en egen gren (*branch*) uten å ødelegge det som virker.

---

## 2. Git og GitHub er ikke det samme

Dette er den vanligste misforståelsen. Git og GitHub henger sammen, men er to forskjellige ting.

| | **Git** | **GitHub** |
|---|---|---|
| Hva er det? | Et **program** for versjonskontroll | En **nettjeneste** (sky) som lagrer Git-repoer |
| Hvor kjører det? | **Lokalt** på din egen PC | **På internett**, på github.com |
| Trenger internett? | Nei | Ja |
| Laget av | Linus Torvalds i 2005, gratis og åpen kildekode | GitHub (eid av Microsoft) |
| Hva gjør det? | Tar øyeblikksbilder, holder historikk, lager branches | Deler kode, samarbeid med pull requests, code review, issues og automatisering (Actions) |
| Alternativer | (Git er helt dominerende) | GitLab, Bitbucket, Azure DevOps |

> **Sammenligning:** Git er som **kameraet** som tar bildene. GitHub er som et **delt fotoalbum i skyen** der hele gruppen kan se, kommentere og legge til bilder.

Du kan bruke Git helt uten GitHub. Men for å samarbeide trenger dere et felles sted å dele endringene, og det er der GitHub kommer inn.

### Lokalt og eksternt repository

Et **repository** (ofte forkortet **repo**) er en prosjektmappe som Git holder øye med, inkludert hele historikken.

- **Lokalt repository:** Ligger på din PC. Historikken lagres i en skjult mappe som heter `.git` inne i prosjektmappen.
- **Eksternt repository** (*remote*): En kopi av det samme repoet på GitHub. Standardnavnet på det eksterne repoet er `origin`.

Alle i gruppen har hver sin **fullstendige** lokale kopi, med hele historikken. GitHub er det felles møtepunktet der dere utveksler endringer.

```text
        Kari sin PC                GitHub (origin)               Ola sin PC
   ┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
   │ lokalt repo      │ push ─▶│ eksternt repo    │◀─ push │ lokalt repo      │
   │ (hele historikk) │◀─ pull │ (felles kopi)    │ pull ─▶│ (hele historikk) │
   └──────────────────┘        └──────────────────┘        └──────────────────┘
```

---

## 3. De fire stedene en endring går gjennom

Dette er det viktigste du lærer i hele emnet. Forstår du denne figuren, forstår du Git.

```text
  ┌─────────────────┐  git add   ┌─────────────────┐ git commit ┌─────────────────┐  git push  ┌─────────────────┐
  │ ① Working       │──────────▶ │ ② Staging Area  │──────────▶ │ ③ Local         │──────────▶ │ ④ Remote        │
  │    Directory    │            │   (indeks)      │            │    Repository   │            │    Repository   │
  │ Filene du ser   │            │ «Handlekurven»: │            │ Lagrede         │            │ GitHub          │
  │ og redigerer    │            │ det som skal    │            │ øyeblikksbilder │            │ (origin)        │
  │                 │            │ med i neste     │            │ i .git-mappen   │            │                 │
  │                 │            │ commit          │            │                 │            │                 │
  └─────────────────┘            └─────────────────┘            └─────────────────┘            └────────┬────────┘
          ▲                                                                                             │
          └─────────────────────────────────────── git pull ────────────────────────────────────────────┘
```

| Sted | Norsk forklaring | Hvordan kommer endringen hit? |
|---|---|---|
| ① **Working Directory** (arbeidsmappen) | Filene slik du ser dem i VS Code eller Utforsker. Her redigerer du. | Du lagrer en fil (Ctrl+S) |
| ② **Staging Area** (indeksen) | En «handlekurv» der du legger det som skal være med i neste øyeblikksbilde | `git add` |
| ③ **Local Repository** (lokalt repo) | Historikken på din PC. Hver commit er et øyeblikksbilde med melding, navn og tidspunkt. | `git commit` |
| ④ **Remote Repository** (GitHub) | Den felles kopien som resten av gruppen henter fra | `git push` |

Veien tilbake fra GitHub til din PC går med `git pull`. Den henter andres commits og fletter dem inn i arbeidsmappen din.

### Hvorfor finnes staging area?

Fordi du sjelden vil lagre *alt* du har endret i ett og samme øyeblikksbilde. Tenk deg at du har:

1. rettet en skrivefeil i `README.md`, og
2. halvveis begynt på en ny funksjon i `app.js`.

Med staging area kan du lagre skrivefeilrettingen som én ryddig commit, og vente med `app.js` til funksjonen er ferdig:

```bash
git add README.md
git commit -m "Rett skrivefeil i installasjonsveiledningen"
# app.js er fortsatt endret, men ikke med i commiten
```

### Hva er en commit, egentlig?

En **commit** er et øyeblikksbilde av *hele* prosjektet slik det var i staging area. Hver commit har:

- en unik **ID** (en *hash*), for eksempel `fa2b13a`, som regnes ut fra innholdet,
- en **melding** som forklarer endringen,
- **forfatter** og **tidspunkt**,
- en peker til **forrige commit** (forelderen).

Siden hver commit peker på den forrige, blir historikken en kjede:

```text
  a1b2c3d ◀── e4f5a6b ◀── 9c8d7e6   ◀── main   ◀── HEAD
  «Første      «Legg til    «Rett
   versjon»     forside»     lenke»
```

`main` er navnet på hovedgrenen. **HEAD** er en peker som viser hvor du står akkurat nå.

---

## 4. Kom i gang: installer og sett opp Git

### Installer

| System | Slik gjør du |
|---|---|
| **Windows** | Last ned fra [git-scm.com/downloads](https://git-scm.com/downloads), eller kjør `winget install --id Git.Git -e` i PowerShell |
| **macOS** | Kjør `git --version` i Terminal. Har du ikke Git, får du tilbud om å installere det. |
| **Linux** | `sudo apt install git` (Ubuntu og Debian) |

Sjekk at det virker:

```bash
git --version
# git version 2.47.1.windows.1   (versjonen din kan være en annen)
```

### Fortell Git hvem du er

Dette gjør du **én gang** per PC. Navnet og e-posten blir stemplet på alle commitene dine.

```bash
git config --global user.name "Kari Nordmann"
git config --global user.email "kari.nordmann@student.no"

# Kall hovedgrenen main i nye repoer (samme som GitHub)
git config --global init.defaultBranch main

# Bestem hva git pull gjør når du og andre har jobbet samtidig (merge er tryggest for nybegynnere)
git config --global pull.rebase false

# Se innstillingene dine
git config --global --list
```

> **Tips:** Vil du holde e-postadressen privat på GitHub, kan du bruke adressen GitHub lager for deg under **Settings → Emails** (den slutter på `@users.noreply.github.com`).

### Lag en GitHub-konto

Gå til [github.com](https://github.com) og registrer deg. Som student kan du søke om **GitHub Education** og få gratis tilgang til blant annet GitHub Copilot og GitHub Pro.

---

## Oppgaver

**Oppgave 1:** Forklar med egne ord forskjellen på Git og GitHub. Kan du bruke Git uten internett?

**Fasit:** Git er et program på din PC som tar øyeblikksbilder (commits) og holder historikken. GitHub er en nettjeneste der repoer lagres og deles, og der man samarbeider med pull requests. Ja, alt i Git unntatt `push`, `pull`, `fetch` og `clone` virker uten internett.

**Oppgave 2:** Du har endret tre filer, men bare to av dem skal med i neste commit. Hvilket av de fire stedene bruker du for å velge ut de to?

**Fasit:** Staging area (② i figuren). Du kjører `git add` på de to filene du vil ha med, og så `git commit`. Den tredje filen blir liggende som endret i arbeidsmappen.

**Oppgave 3:** Kari har committet en endring, men Ola ser den ikke når han kjører `git pull`. Hva har Kari mest sannsynlig glemt?

**Fasit:** `git push`. En commit ligger bare i Karis lokale repo til den er pushet til GitHub.

**Oppgave 4:** Installer Git, sett navn og e-post med `git config`, og kjør `git config --global --list`. Står navnet ditt der?

**Fasit:** Du skal se linjene `user.name=…` og `user.email=…` med dine verdier. Får du «git is not recognized», er ikke Git installert, eller så må du åpne terminalen på nytt etter installasjonen.

> **Lærernotat:** Tegn de fire boksene i avsnitt 3 på tavla, og la én student «være» hver boks. Send en lapp (endringen) gjennom kjeden mens klassen sier kommandoen høyt. Det sitter bedre enn en forklaring. Bruk sammenligningen med kamera og fotoalbum når noen blander Git og GitHub.
