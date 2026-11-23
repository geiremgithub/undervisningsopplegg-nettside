---
title: "Git i VS Code"
description: "De samme operasjonene uten terminal: klone, stage, commit, push og pull, branches, merge-konflikter og pull requests i Visual Studio Code."
order: 4
---

# Git i VS Code

**Mål:** Etter dette temaet kan du gjøre alt fra de forrige temaene med knapper i VS Code, og du vet hvilken Git-kommando hver knapp tilsvarer.

**Forkunnskaper:** [De viktigste Git-kommandoene](02-kommandoer.md). Git må være installert, for VS Code bruker Git-programmet på maskinen din.

> **Terminal eller knapper?** Begge deler er like riktig. VS Code kjører de samme Git-kommandoene for deg. Mange bruker knappene til daglig og terminalen når noe er uvanlig. Det er lurt å kunne begge: da forstår du hva knappene gjør.

---

## 1. Source Control-visningen

Klikk på ikonet med tre prikker og streker i venstre kant (**Source Control**), eller trykk **Ctrl+Shift+G**.

```text
┌─ SOURCE CONTROL ───────────────────────────┐
│ ┌────────────────────────────────────────┐ │
│ │ Message (Ctrl+Enter to commit)         │ │  ← commit-melding
│ └────────────────────────────────────────┘ │
│ [ ✓ Commit                            ▾ ] │  ← git commit
│                                            │
│ ▾ Staged Changes                       1   │  ← staging area
│     README.md                     −  M     │     (− = git restore --staged)
│ ▾ Changes                              2   │  ← arbeidsmappen
│     app.js                    ↶  +  M     │     (+ = git add, ↶ = git restore)
│     handleliste.css           ↶  +  U     │     (U = ny fil Git ikke følger)
└────────────────────────────────────────────┘
  ⎇ main*  ↓0 ↑1  ⟳                            ← statuslinjen nederst til venstre
```

| Bokstav ved filen | Betyr |
|---|---|
| **M** | *Modified* – endret |
| **U** | *Untracked* – ny fil |
| **A** | *Added* – ny fil som er lagt i staging area |
| **D** | *Deleted* – slettet |
| **C** | *Conflict* – merge-konflikt |

I selve editoren ser du også fargede streker i margen ved linjenumrene: **grønn** for nye linjer, **blå** for endrede linjer og en **rød trekant** der linjer er slettet. Klikk på streken for å se hva som er endret.

---

## 2. Fra kommando til knapp

| Git-kommando | Slik gjør du det i VS Code |
|---|---|
| `git clone <url>` | **Ctrl+Shift+P** → skriv **Git: Clone** → lim inn adressen, eller velg **Clone from GitHub** og logg inn → velg mappe → **Open** |
| `git init` | Åpne mappen (**File → Open Folder**) → Source Control → **Initialize Repository** |
| `git status` | Source Control-visningen viser status hele tiden |
| `git diff` | Klikk på en fil under **Changes** for å se gammel og ny versjon side om side |
| `git add <fil>` | Hold musen over filen → klikk **+** (*Stage Changes*) |
| `git add .` | Klikk **+** på linjen **Changes** (*Stage All Changes*) |
| `git restore --staged <fil>` | Klikk **−** ved filen under **Staged Changes** |
| `git restore <fil>` | Klikk **↶** (*Discard Changes*). Kan ikke angres! |
| `git commit -m "…"` | Skriv meldingen i feltet → **Commit** (eller **Ctrl+Enter**) |
| `git pull` + `git push` | Klikk **Sync Changes** (eller ⟳ i statuslinjen). VS Code henter først og sender etterpå. |
| `git push -u origin <gren>` | **Publish Branch** (vises når grenen ikke finnes på GitHub ennå) |
| Opprette repo på GitHub og pushe | **Publish to GitHub** i et repo som ikke har remote. Velg privat eller offentlig. |
| `git log` | Seksjonen **Graph** nederst i Source Control, eller **Timeline** i Explorer for én fil |

> **Tips:** Har du ikke lagt noe i staging area og klikker **Commit**, spør VS Code om du vil ta med alle endringene. Det tilsvarer `git commit -a`.

> **Copilot:** Har du GitHub Copilot, kan du klikke på gnistikonet ✨ i meldingsfeltet for å få et forslag til commit-melding. Les forslaget før du bruker det.

---

## 3. Branches i VS Code

Grenen du står på, vises **nederst til venstre** i statuslinjen (for eksempel `⎇ main`). Klikk på den for å:

- **bytte gren** (`git switch <gren>`): velg en gren fra listen,
- **lage ny gren** (`git switch -c <gren>`): velg **+ Create new branch…** og skriv navnet.

Grener som bare finnes på GitHub, står som `origin/…` i listen. Velger du en slik, lager VS Code en lokal gren som følger den.

**Merge** (`git merge <gren>`): **Ctrl+Shift+P** → skriv **Git: Merge** → velg grenen som skal flettes inn i den du står på.

---

## 4. Merge-konflikter i VS Code

Når det blir konflikt, får filen en **C** i Source Control, og VS Code farger de to versjonene i editoren:

```text
  Accept Current Change | Accept Incoming Change | Accept Both Changes | Compare Changes
  <<<<<<< HEAD (Current Change)
  <h1>Handleliste 2.0</h1>
  =======
  <h1>Min handleliste</h1>
  >>>>>>> origin/main (Incoming Change)
```

| Knapp | Betyr |
|---|---|
| **Accept Current Change** | Behold *din* versjon (HEAD) |
| **Accept Incoming Change** | Behold *den andre* versjonen |
| **Accept Both Changes** | Behold begge, den ene under den andre |
| **Compare Changes** | Vis versjonene side om side |

For større konflikter kan du klikke **Resolve in Merge Editor**. Da får du tre ruter: *Incoming* (den andre), *Current* (din) og *Result* (det som blir lagret) nederst. Kryss av for det du vil beholde, eller rediger resultatet direkte, og klikk **Complete Merge**.

Når alle konfliktene er løst: lagre filen, klikk **+** for å legge den i staging area (som `git add`), og så **Commit**.

---

## 5. Pull requests uten å forlate VS Code

Installer utvidelsen **GitHub Pull Requests** (fra GitHub) via Extensions-visningen (**Ctrl+Shift+X**). Da kan du:

- lage en pull request fra grenen du står på,
- se PR-er som venter på din review, og lese endringene i editoren,
- skrive kommentarer på linjer, godkjenne og be om endringer,
- sjekke ut en kollegas PR med ett klikk for å teste den.

---

## Oppgaver

**Oppgave 1:** Klon et repo fra GitHub med VS Code, endre `README.md`, og lag en commit **uten** å bruke terminalen. Hvilke knapper brukte du?

**Fasit:** **Ctrl+Shift+P** → **Git: Clone** → adresse → mappe → **Open**. Endre og lagre `README.md`. Source Control → **+** ved filen → skriv melding → **Commit** → **Sync Changes** (eller **Publish Branch** hvis grenen er ny).

**Oppgave 2:** Hvilken Git-kommando kjører VS Code når du klikker **Sync Changes**?

**Fasit:** `git pull` etterfulgt av `git push`. Først hentes andres endringer, så sendes dine.

**Oppgave 3:** Du ser en blå strek i margen ved linje 14. Hva betyr det, og hvordan ser du hva som var der før?

**Fasit:** Linjen er endret siden siste commit. Klikk på streken for å se den gamle versjonen, eller klikk på filen i Source Control for å se hele filen side om side.

**Oppgave 4:** Gjenta gruppeøvelsen fra [Samarbeid](03-samarbeid.md), men løs konflikten med knappene i VS Code. Prøv både **Accept Both Changes** og **Resolve in Merge Editor**.

**Fasit:** Etter løsningen er markørene borte, filen står under **Staged Changes** etter at du har klikket **+**, og commiten fullfører flettingen. Med Merge Editor ser du resultatet nederst før du klikker **Complete Merge**.

> **Lærernotat:** Vis gjerne de samme stegene både i terminalen og med knapper på storskjerm, side om side. Studenter som bare lærer knappene, står fast den dagen noe går galt. Studenter som bare lærer terminalen, bruker unødvendig lang tid på konflikter.
