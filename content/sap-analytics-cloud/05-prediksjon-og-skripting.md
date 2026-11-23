---
title: "SAC: Smart Predict og skripting"
description: "Prognoser uten kode og interaktivitet med skripting i stories."
order: 5
---

# SAC: Smart Predict og skripting

## 11. Eksempel 7: Prognose med Smart Predict

**Smart Predict** gir maskinlæring uten kode.

### 11.1 Scenariotyper

| Type | Spørsmål | Eksempel |
|---|---|---|
| **Classification** | Skjer det, ja eller nei? | Kommer kunden til å slutte? |
| **Regression** | Hvor mye? | Hvor mye vil en kunde handle for? |
| **Time Series** | Hva skjer fremover i tid? | Månedlig omsetning neste 6 måneder |

### 11.2 Tidsserieprognose for omsetning

1. Velg **Predictive Scenarios** → **Time Series Forecast** og gi scenarioet navnet `PRED_OMSETNING`.
2. Datakilde: et dataset med `Dato` og `Omsetning`. Planleggingsmodeller kan også brukes.
3. Innstillinger:
   - **Target:** `Omsetning`
   - **Date:** `Dato`
   - **Entity:** `Kategori` (lager én prognose per kategori)
   - **Number of forecast periods:** 6
4. Klikk **Train & Forecast**.
5. Les resultatet:
   - **Expected MAPE:** gjennomsnittlig prosentvis feil, der lavere er bedre
   - **Forecast-graf** med konfidensintervall
   - **Signal analysis:** trend og sesong
6. **Save Predictions** til planleggingsmodellen, i `Version = Forecast`.

> ⚠️ Vårt datasett er for lite til gode prognoser. Poenget er å lære arbeidsflyten. Bruk gjerne et større åpent datasett i oppgavene.

### 11.3 Predictive Forecast direkte i tabell

I en planleggingstabell kan du høyreklikke en rad og velge **Predictive Forecast**. Da lager SAC en rask prognose direkte i planen.

---

## 12. Eksempel 8: Interaktivitet med skripting

Med **Optimized Story Experience**, der tidligere *Analytics Designer* nå er integrert i stories, kan du bruke **JavaScript-lignende skripting** for avansert interaktivitet.

### 12.1 Dropdown som filtrerer et diagram

1. Lag en story med **Optimized Story Experience** og legg til diagrammet `Chart_1`.
2. Legg til en **Dropdown** (`Dropdown_1`) med verdiene `Øst`, `Vest` og `Midt`.
3. Klikk **fx** ved dropdownen og velg **onSelect**:

```javascript
// Filtrer diagrammet på valgt region
var region = Dropdown_1.getSelectedKey();
Chart_1.getDataSource().setDimensionFilter("Region", region);
```

### 12.2 Knapp som bytter mellom diagram og tabell

```javascript
// Knapp: Button_Toggle → onClick
var visDiagram = Chart_1.isVisible();
Chart_1.setVisible(!visDiagram);
Table_1.setVisible(visDiagram);
Button_Toggle.setText(visDiagram ? "Vis diagram" : "Vis tabell");
```

### 12.3 Nullstill alle filtre

```javascript
// Knapp: Button_Reset → onClick
Chart_1.getDataSource().removeDimensionFilter("Region");
Table_1.getDataSource().removeDimensionFilter("Region");
Dropdown_1.setSelectedKey("");
```

### 12.4 Kjør en data action fra script

```javascript
// Forutsetter at det finnes en Data Action Trigger eller et Data Action-objekt i storyen
DataAction_1.setParameterValue("Vekst", 1.05);
DataAction_1.execute();
Application.showMessage(ApplicationMessageType.Success, "Prognosen er oppdatert!");
```

> 💡 Bruk **Ctrl + Space** i script-editoren for å se tilgjengelige metoder. API-referansen finnes i SAP Help: *Analytics Designer API Reference*.
