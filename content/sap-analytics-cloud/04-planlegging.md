---
title: "SAC: planlegging og data actions"
description: "Budsjett og prognose med versjoner, inntasting, fordeling og automatiske beregninger."
order: 4
---

# SAC: planlegging og data actions

## 9. Eksempel 5: Planlegging og budsjett

Planlegging er en av SACs store styrker: **BI og budsjettering i samme verktøy**.

### 9.1 Lag en planleggingsmodell

1. **Modeler** → **New Model** → **Start with an empty model** (eller med data fra `budsjett.csv`).
2. Velg **Planning enabled**.
3. Dimensjoner:
   - **Date** (granularitet: måned)
   - **Version**: lages automatisk
   - **Account**: kontoer, for eksempel `Omsetning`, `Kostnad` og `Dekningsbidrag`
   - **Region** og **Kategori**: generiske dimensjoner
4. Definer kontoen `Dekningsbidrag` som en formel i Account-dimensjonen:

   ```text
   [Omsetning] - [Kostnad]
   ```

5. Lagre som `NORDLYS_PLAN`.

### 9.2 Importer budsjett og faktiske tall

1. **Data Management** → **Import Data** → **File** → `budsjett.csv`.
2. Mapp kolonnene: `Måned` → Date, `Konto` → Account, `Beløp` → mål.
3. Velg **Version: Budget** (public).
4. Gjenta for de faktiske tallene, med **Version: Actual**.

### 9.3 Skriv inn tall direkte (input)

1. Lag en story og legg til en **Table** basert på `NORDLYS_PLAN`.
2. Rader: `Region` og `Kategori`. Kolonner: `Date` (jul.–des. 2024). Filter: `Version = Budget` og `Account = Omsetning`.
3. Klikk i en celle og skriv inn et tall. SAC lager en **privat kopi** (edit mode) av versjonen.
4. **Spread:** skriv inn et tall på et overordnet nivå, for eksempel `Øst`. SAC fordeler det automatisk ned på kategoriene, proporsjonalt med eksisterende verdier.
5. Klikk **Publish Data** for å lagre for alle.

### 9.4 Versjonshåndtering

```text
Actual (faktisk) ──▶ kopi ──▶ Forecast Q3 ──▶ justert av controller ──▶ Publish
                                    │
                                    └──▶ Privat versjon "Scenario: +10 % salg"
```

- **Public versions** er synlige for alle med tilgang.
- **Private versions** er dine egne "hva hvis"-scenarioer.
- **Data locking** låser perioder eller regioner slik at ingen endrer dem, for eksempel avsluttede måneder.

### 9.5 Kalender og arbeidsflyt

Med **Calendar** (planleggingskalender) kan du sette opp en budsjettprosess:

1. **Oppgave til regionsjef Øst:** «Legg inn budsjett for Øst innen 1. september».
2. **Godkjenning:** controller godkjenner eller avviser.
3. **Automatisk data action:** kjøres når alle regioner er levert.

---

## 10. Eksempel 6: Data actions og avanserte formler

**Data actions** automatiserer beregninger i planleggingsmodeller.

### 10.1 Copy step: forecast fra Actual

1. **Data Actions** → **New Data Action** → velg modellen `NORDLYS_PLAN`.
2. Legg til et **Copy step**:
   - **Fra:** `Version = Actual`, `Date = 2024 jan.–jun.`
   - **Til:** `Version = Forecast`, samme datoer
3. Lagre som `DA_KOPI_ACTUAL_TIL_FORECAST`.

### 10.2 Advanced formulas step: +5 % vekst

Legg til et **Advanced Formulas**-steg. Språket ligner på et script:

```text
// Gjelder bare Forecast-versjonen for 2. halvår 2024
MEMBERSET [d/Version] = "public.Forecast"
MEMBERSET [d/Date] = "202407" TO "202412"

// Omsetning = samme måned i fjor × 1,05
DATA([d/Account] = "Omsetning") =
    RESULTLOOKUP([d/Account] = "Omsetning", [d/Version] = "public.Actual",
                 [d/Date] = PREVIOUS(12)) * 1.05

// Kostnad = 52 % av planlagt omsetning
DATA([d/Account] = "Kostnad") =
    RESULTLOOKUP([d/Account] = "Omsetning") * 0.52
```

**Forklaring:**

| Nøkkelord | Betyr |
|---|---|
| `MEMBERSET` | Avgrenser hvilke data scriptet jobber på |
| `DATA(...) =` | Skriver verdier til cellene som matcher |
| `RESULTLOOKUP(...)` | Leser verdier, eventuelt fra en annen versjon eller periode |
| `PREVIOUS(12)` | Samme periode 12 måneder tilbake |
| `IF ... ENDIF` | Betingelser |
| `FOREACH ... ENDFOR` | Løkke over medlemmer, for eksempel for akkumulering |

### 10.3 Allokering

Med et **Allocation step** fordeler du for eksempel felles markedsføringskostnader på 100 000 kr til regionene etter andelen av omsetningen.

### 10.4 Kjør fra storyen

1. **Insert** → **Planning Trigger** (Data Action Trigger) i storyen.
2. Koble triggeren til `DA_KOPI_ACTUAL_TIL_FORECAST`.
3. Brukeren klikker på knappen, og beregningen kjøres.

> 💡 Data actions kan også planlegges i **Calendar** eller kjøres i rekkefølge i en **Multi Action**, for eksempel: importer data → kjør data action → publiser versjon.
