---
title: "Skills"
description: "Hvordan en skill er bygd opp og lastes, med fem eksempler."
order: 3
---

# Skills

**Mål:** Du kan forklare hva en skill er, lage en skill i VS Code, og teste at den blir brukt.

## 3. Skills: teori

### 3.1 Hva er en skill?

En skill er en **mappe** som inneholder en fil som heter `SKILL.md`, og eventuelt andre filer som skript, maler eller dokumentasjon.

```text
min-skill/
├── SKILL.md          # Påkrevd: beskrivelse og instruksjoner
├── scripts/          # Valgfritt: skript agenten kan kjøre
├── references/       # Valgfritt: ekstra dokumentasjon som leses ved behov
└── assets/           # Valgfritt: maler, eksempelfiler osv.
```

### 3.2 Slik lastes skills (progressiv lasting)

Dette er det viktigste konseptet:

1. **Ved oppstart** ser agenten bare `name` og `description` for alle skills. Det koster svært lite.
2. **Når oppgaven matcher beskrivelsen**, leser agenten hele `SKILL.md`.
3. **Ved behov** leser agenten flere filer i mappen (`references/…`) eller kjører skript (`scripts/…`).

Derfor kan du ha mange skills uten at assistenten blir tregere eller «forvirret».

> ⚠️ **Konsekvens:** `description` er det **eneste** agenten ser når den velger skill. En dårlig beskrivelse betyr at skillen aldri blir brukt.

### 3.3 Oppbygningen av SKILL.md

```markdown
---
name: skill-navn
description: Hva skillen gjør. Bruk når <situasjon 1>, <situasjon 2> eller når brukeren nevner "<nøkkelord>".
---

# Tittel

Instruksjoner i vanlig Markdown, skrevet som en oppskrift til en kollega.
```

**Regler for frontmatter:**

| Felt | Påkrevd | Regler |
|---|---|---|
| `name` | ✅ | Små bokstaver, tall og bindestrek. **Skal være likt mappenavnet.** Maks 64 tegn. |
| `description` | ✅ | Hva skillen gjør **og når den skal brukes**. Maks ca. 1024 tegn. |
| `user-invocable` | ❌ | Sett til `false` hvis skillen ikke skal vises som `/kommando`, bare brukes automatisk. |
| `disable-model-invocation` | ❌ | Sett til `true` hvis skillen **bare** skal kjøres når du selv skriver `/skill-navn`. Nyttig for ting som publisering. |
| `license` | ❌ | For eksempel `MIT`, hvis skillen skal deles. |

### 3.4 To måter å bruke en skill på

| Slik | Hva skjer |
|---|---|
| **Automatisk** | Du skriver for eksempel «lag en commit-melding», og agenten ser at det passer med `description` og laster skillen. |
| **Som kommando** | Du skriver `/` i chatten, velger skillen og legger til tekst etter den: `/commit-melding for endringene i content/`. |

Den første måten avhenger av en god beskrivelse. Den andre virker alltid, så den er fin når du tester.

### 3.5 Lag en skill i VS Code, steg for steg

1. `Ctrl + Shift + P` → **Chat: Open Customizations** → fanen **Skills**.
2. Klikk **+** (New Skill) ved **Workspace**, og skriv navnet, for eksempel `commit-melding`.
3. VS Code lager `.github/skills/commit-melding/SKILL.md`. Fyll inn innholdet (se eksempel 4.1).
4. Lagre, og start en **ny chat**.
5. **Test som kommando:** Skriv `/` og sjekk at `commit-melding` står i listen. Kjør den.
6. **Test automatisk bruk:** I enda en ny chat skriver du noe som passer med beskrivelsen, uten skråstrek. Sjekk i chatten at skillen ble lastet. Blir den ikke det, gjør du beskrivelsen tydeligere.

> 📁 **Plassering:** Skills for prosjektet ligger i `.github/skills/<navn>/`. Personlige skills, som gjelder i alle prosjekter, ligger i `~/.copilot/skills/<navn>/`.

### 3.6 En god beskrivelse

| ❌ Dårlig | ✅ God |
|---|---|
| `Hjelper med git.` | `Skriver commit-meldinger etter Conventional Commits. Bruk når brukeren skal committe, skrive commit-melding eller lage PR-tittel.` |
| `Database-ting.` | `Lager og feilsøker EF Core-migreringer. Bruk når skjemaet i SQL Server endres, eller ved feilen "multiple cascade paths".` |

Formelen er: **Hva + «Bruk når …» + nøkkelord brukeren sannsynligvis skriver.**

> 🧩 **Ekte eksempler:** Denne kursportalen har fire ferdige skills i `.github/skills/`: `nytt-tema`, `sjekk-innhold` (med skript), `lag-quiz` og `publiser-endringer`. De gjennomgås i tema 6.

---

## 4. Skills: eksempler

### Eksempel 4.1: Enkel skill med bare instruksjoner (commit-meldinger)

📁 `.github/skills/commit-melding/SKILL.md`

```markdown
---
name: commit-melding
description: Skriver commit-meldinger og PR-titler etter Conventional Commits. Bruk når brukeren skal committe, ber om en commit-melding, eller skal navngi en pull request.
---

# Commit-meldinger

## Format

    <type>(<valgfritt scope>): <kort beskrivelse i imperativ>

## Tillatte typer

| Type | Brukes når |
|---|---|
| `feat` | Ny funksjonalitet |
| `fix` | Feilretting |
| `docs` | Bare dokumentasjon |
| `refactor` | Omskriving uten endret oppførsel |
| `test` | Nye eller endrede tester |
| `chore` | Vedlikehold, avhengigheter, bygg |

## Regler

1. Beskrivelsen skrives med liten forbokstav og uten punktum til slutt.
2. Maks 72 tegn i første linje.
3. Bruk `!` etter typen ved brytende endringer, for eksempel `feat!: fjern gammelt API`.
4. Se på `git diff --staged` før du foreslår en melding.

## Eksempler

- `feat(login): legg til innlogging med Microsoft-konto`
- `fix(api): returner 404 når maskinen ikke finnes`
- `docs: oppdater installasjonsguide`
```

**Test den:** Gjør en endring, stage den og skriv i chatten: *«Lag en commit-melding»*.

---

### Eksempel 4.2: Skill med skript (CSV-analyse)

Skills kan ha med kode som agenten kjører. Det gir **forutsigbare resultater**, fordi agenten ikke «finner på» beregninger selv.

```text
.github/skills/csv-analyse/
├── SKILL.md
└── scripts/
    └── oppsummer.py
```

📄 `SKILL.md`

```markdown
---
name: csv-analyse
description: Analyserer CSV-filer og gir statistikk (antall rader, kolonner, gjennomsnitt, manglende verdier). Bruk når brukeren vil analysere, oppsummere eller undersøke en CSV-fil.
---

# CSV-analyse

1. Finn CSV-filen brukeren mener. Spør hvis det er uklart.
2. Kjør skriptet. Ikke regn ut statistikk selv:

       python scripts/oppsummer.py <sti-til-fil.csv>

3. Presenter resultatet som en tabell.
4. Kommenter kort det som er påfallende, for eksempel mange manglende verdier eller ekstreme verdier.
5. Foreslå 1–2 videre analyser.

Hvis Python mangler, be brukeren installere Python 3.10 eller nyere.
```

📄 `scripts/oppsummer.py`

```python
import csv
import statistics
import sys

def main(path: str) -> None:
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    if not rows:
        print("Filen er tom.")
        return

    print(f"Rader: {len(rows)}")
    print(f"Kolonner: {', '.join(rows[0].keys())}\n")

    for col in rows[0].keys():
        values = [r[col] for r in rows]
        missing = sum(1 for v in values if v.strip() == "")
        numbers = []
        for v in values:
            try:
                numbers.append(float(v))
            except ValueError:
                pass
        line = f"- {col}: manglende={missing}"
        if numbers:
            line += (f", min={min(numbers)}, maks={max(numbers)}, "
                     f"snitt={statistics.mean(numbers):.2f}")
        print(line)

if __name__ == "__main__":
    main(sys.argv[1])
```

**Test den:** *«Analyser data/salg.csv»*.

---

### Eksempel 4.3: Skill med referansefiler (API-designregler)

Når en skill blir lang, deler du den opp. Hoved-`SKILL.md` holdes kort, og detaljene ligger i `references/`. Agenten leser dem bare ved behov.

```text
.github/skills/rest-api-design/
├── SKILL.md
├── references/
│   ├── feilhaandtering.md
│   └── paginering.md
└── assets/
    └── controller-mal.cs
```

📄 `SKILL.md`

```markdown
---
name: rest-api-design
description: Retningslinjer for å designe og implementere REST-endepunkter i ASP.NET Core (navngiving, statuskoder, feil, paginering). Bruk når brukeren lager eller endrer et API-endepunkt eller en controller.
---

# REST API-design

## Grunnregler
- Ressurser i flertall: `/api/studenter`, `/api/studenter/{id}`
- Riktige statuskoder: `200` OK, `201` opprettet, `204` slettet, `400` ugyldig input, `404` ikke funnet
- Aldri verb i URL-en (`/api/hentStudenter` ❌)

## Les mer ved behov
- Feilhåndtering og ProblemDetails: se [references/feilhaandtering.md](references/feilhaandtering.md)
- Lister med mange elementer: se [references/paginering.md](references/paginering.md)

## Ny controller
Ta utgangspunkt i malen i [assets/controller-mal.cs](assets/controller-mal.cs).
```

📄 `references/paginering.md`

```markdown
# Paginering

Bruk spørringsparametrene `page` (start på 1) og `pageSize` (standard 20, maks 100).

Respons:

    {
      "items": [ ... ],
      "page": 1,
      "pageSize": 20,
      "totalCount": 245
    }
```

---

### Eksempel 4.4: Interaktiv skill (intervju eller quiz)

Skills trenger ikke handle om kode. Denne gjør Copilot til en eksamenstrener:

📁 `~/.copilot/skills/quiz-meg/SKILL.md` (personlig skill)

```markdown
---
name: quiz-meg
description: Lager en interaktiv quiz for å teste forståelsen av et tema. Bruk når brukeren sier "quiz meg", "test meg" eller vil øve til eksamen.
---

# Quiz

1. Spør hvilket tema og hvilket nivå (nybegynner, middels, avansert) brukeren vil ha, hvis det ikke er oppgitt.
2. Still **ett** spørsmål om gangen. Vent på svar før du går videre.
3. Etter hvert svar:
   - Si om svaret er riktig, delvis riktig eller feil.
   - Forklar kort hvorfor, med et eksempel.
4. Juster vanskelighetsgraden: gjør spørsmålene vanskeligere etter riktige svar og lettere etter feil.
5. Etter 5 spørsmål: gi en poengsum og en liste over hva brukeren bør repetere.

Ikke avslør svaret før brukeren har svart.
```

---

### Eksempel 4.5: Skill som prosedyre for teamet (ny API-integrasjon)

Mange skills i virkelige prosjekter beskriver *slik gjør vi det her*. Det er kunnskap som ellers bare finnes i hodet til seniorutviklerne.

```markdown
---
name: ny-integrasjon
description: Steg-for-steg-prosedyre for å legge til en ny ekstern API-integrasjon med synkroniseringsjobb. Bruk når brukeren skal hente data fra et nytt eksternt system.
---

# Ny integrasjon

Følg stegene i rekkefølge. Ikke hopp over tester.

1. **Klient:** Lag en typed `HttpClient` i `src/External/<System>/`.
2. **DTO-er:** Lag records som speiler API-responsen.
3. **Entitet:** Legg til entitet og konfigurasjon i `src/Data/`.
4. **Migrering:** Bruk skillen `ef-core-migrations`.
5. **Jobb:** Lag synkjobben i `src/Jobs/` og registrer den i scheduleren.
6. **Tester:** Mock API-et med NSubstitute og test upsert-logikken.
7. **Verifiser:** Kjør `dotnet test` til alt er grønt.

## Vanlige feil
- Ikke glem `CancellationToken` på alle async-metoder.
- API-nøkler skal ligge i Key Vault, aldri i `appsettings.json`.
```

> Legg merke til at en skill kan **henvise til en annen skill** (`ef-core-migrations`). Slik bygger du opp et bibliotek av små skills som kan kombineres.
