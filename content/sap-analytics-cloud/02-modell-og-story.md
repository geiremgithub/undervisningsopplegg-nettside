---
title: "SAC: modell og første story"
description: "Importer data, bygg en modell og lag din første interaktive rapport (story)."
order: 2
---

# SAC: modell og første story

> **Del A: SAP Analytics Cloud** (tema 2–5)

## 5. Eksempel 1: Importer data og lag en modell

### 5.1 Dataset eller model?

| | Dataset | Model |
|---|---|---|
| Oppsett | Raskt, nesten ingen modellering | Mer arbeid |
| Hierarkier, valuta, versjoner | Begrenset | ✅ |
| Planlegging | ❌ | ✅ (planning model) |
| Passer for | Rask utforsking, Smart Predict | Gjenbrukbare rapporter, planlegging |

### 5.2 Lag en modell fra CSV

1. Logg inn i SAC og velg **Modeler** i venstremenyen.
2. Klikk **New Model** → **Start with data** → **File** og last opp `salg.csv`.
3. SAC foreslår selv hva som er dimensjoner og mål. Kontroller forslaget:

   | Kolonne | Type |
   |---|---|
   | Dato | **Date**-dimensjon (oppløsning: dag) |
   | Region, By | Generic dimension |
   | Produkt, Kategori | Generic dimension |
   | Antall, Omsetning, Kostnad | **Measure** |

4. **Gjør Kategori til et attributt (property) av Produkt.** Velg kolonnen `Kategori` og sett den som **Property** av `Produkt`. Da hører kategorien til produktet.
5. **Lag et hierarki for geografi.** Region → By. Du kan lage det som et *level-based hierarchy* i dimensjonen.
6. Sjekk **Data quality**-panelet for advarsler, for eksempel ugyldige datoer eller tomme verdier.
7. Klikk **Create Model** og gi den navnet `NORDLYS_SALG`.

> 💡 Bruk gjerne en navnekonvensjon: `MDL_` for modeller, `STR_` for stories og `DA_` for data actions.

### 5.3 Planleggingsmodell eller analytisk modell?

Ved opprettelse kan du velge om modellen skal være **planning enabled**. En planleggingsmodell får blant annet:

- **Version**-dimensjon (Actual, Budget, Forecast …)
- **Account**-dimensjon i stedet for løse mål (i den klassiske modelltypen)
- Mulighet til å skrive inn data og kjøre data actions

Vi bruker en analytisk modell her og lager en planleggingsmodell i eksempel 5.

---

## 6. Eksempel 2: Din første story

En **story** er SACs rapport. Den kan ha flere sider: dashbord, tabeller og responsive sider for mobil.

### 6.1 Opprett story

1. Velg **Stories** → **Create New** → **Responsive** (eller **Canvas**).
2. Klikk **Add data** og velg `NORDLYS_SALG`.

### 6.2 Legg til elementer

| Element | Innstillinger | Hensikt |
|---|---|---|
| **Numeric Point** (KPI) | Measure: `Omsetning` | Total omsetning |
| **Numeric Point** | Measure: `Antall` | Antall solgte enheter |
| **Bar/Column chart** | Measure: `Omsetning`, dimensjon: `Kategori` | Hvilke kategorier selger best? |
| **Line chart** | Measure: `Omsetning`, dimensjon: `Dato` (måned) | Utvikling over tid |
| **Geo map** eller **Bar chart** | Dimensjon: `Region` → `By` | Hvor selger vi? |
| **Table** | Rader: `Region`, `By`. Kolonner: alle mål. | Detaljer |

### 6.3 Gjør storyen interaktiv

- **Input control** (filter): legg til en kontroll for `Kategori` øverst på siden.
- **Linked analysis:** velg et diagram, klikk **⋯** → **Linked Analysis** → **All widgets on this page**. Når du klikker på en søyle, filtreres resten av siden.
- **Drill:** i diagrammet med `Region` klikker du på pil ned for å gå fra region til by.
- **Ranking:** **⋯** → **Rank** → **Top 5** i tabellen.

### 6.4 Formatering

- Bruk **Styling**-panelet til høyre for farger og tallformat, for eksempel `kr` og tusenskille.
- Legg til en **tekstboks** med dynamisk tekst: **Insert → Text** → **Dynamic Text** → velg målet `Omsetning`.

**Forventet totalomsetning:** 419 760 kr.
