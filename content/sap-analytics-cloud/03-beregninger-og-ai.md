---
title: "SAC: beregninger og AI-funksjoner"
description: "Beregnede og avgrensede mål, hierarkier, Just Ask og Smart Insights."
order: 3
---

# SAC: beregninger og AI-funksjoner

## 7. Eksempel 3: Beregnede mål, filtre og hierarkier

### 7.1 Calculated measure: dekningsbidrag

I et diagram eller en tabell velger du **+ Add Measure** → **Create Calculation** → **Calculated Measure**.

```text
Navn:   Dekningsbidrag
Formel: [Omsetning] - [Kostnad]
```

```text
Navn:   DB-grad %
Formel: ([Omsetning] - [Kostnad]) / [Omsetning] * 100
```

### 7.2 Restricted measure: bare Ski

Velg **Create Calculation** → **Restricted Measure**:

```text
Navn:      Omsetning Ski
Measure:   Omsetning
Dimension: Kategori = Ski
```

### 7.3 Betingelse med IF

```text
Navn:   Stort salg (flagg)
Formel: IF([Omsetning] > 50000, 1, 0)
```

### 7.4 Aggregering: antall unike produkter

Velg **Create Calculation** → **Aggregation**:

```text
Navn:            Antall produkter
Operation:       COUNT DIMENSIONS
Dimension:       Produkt
```

### 7.5 Avvik og sammenligning over tid

Med en datodimensjon kan du bruke **Time Calculation** eller **Variance**:

- **Variance:** **⋯** → **Add Variance** mellom to perioder eller versjoner, for eksempel *Actual* mot *Budget*.
- **Previous Period:** **Create Calculation** → **Time calculation** → **Previous Period**.

**Forventede verdier for hele perioden:**

| Mål | Verdi |
|---|---|
| Omsetning | 419 760 |
| Kostnad | 225 500 |
| Dekningsbidrag | 194 260 |
| DB-grad % | ca. 46,3 % |

---

## 8. Eksempel 4: Just Ask og Smart Insights

SAC har innebygde AI-funksjoner som er nyttige for brukere som ikke vil bygge diagrammer selv.

### 8.1 Just Ask (spør på naturlig språk)

> I nyere versjoner av SAC er Just Ask i ferd med å bli erstattet av, eller utfylt med, **SAP Joule**, SAPs AI-assistent.

1. Åpne **Just Ask** fra startsiden eller fra en story.
2. Velg modellen `NORDLYS_SALG`. Modellen må være indeksert for Just Ask.
3. Spør på engelsk, for eksempel:

   ```text
   Show revenue by category
   Top 3 cities by revenue
   Revenue by month in 2024
   Compare revenue and cost by region
   ```

4. Legg resultatet til i en story med **Copy to story**.

> 💡 Spørsmålene fungerer best når du bruker samme ord som dimensjons- og målnavnene. Gi dem gjerne engelske **synonymer** i modellen.

### 8.2 Smart Insights

Høyreklikk et datapunkt i et diagram, for eksempel søylen for Løping, og velg **Smart Insights**. SAC forklarer hva som driver tallet, for eksempel at Oslo står for en stor andel av omsetningen i Løping.

### 8.3 Smart Discovery

Velg **Smart Discovery** fra storymenyen, og velg modellen og et mål, for eksempel `Omsetning`. SAC lager automatisk sider med viktige påvirkningsfaktorer, uvanlige verdier og simulering.
