---
title: "Vanlige feil, øvingsoppgaver og ordliste"
description: "Typiske feil, sju øvingsoppgaver med økende vanskelighet og en ordliste."
order: 10
---

# Vanlige feil, øvingsoppgaver og ordliste

## 18. Vanlige feil og gode råd

### ❌ Vanlige feil

| Feil | Symptom | Løsning |
|---|---|---|
| Mellomrom eller spesialtegn i lakehouse- eller tabellnavn | Feilmelding ved opprettelse | Bruk `små_bokstaver_og_understrek` |
| Notebook ikke koblet til lakehouse | `Path does not exist` eller tabellen finnes ikke | Legg til lakehouse under **Add data items** og velg det som *default* |
| Lest CSV uten `header=True` | Kolonnene heter `_c0`, `_c1` … | `.option("header", True)` |
| Alle kolonner er tekst | Summer blir feil eller feiler | Cast eksplisitt (`.cast("int")`) |
| Prøver `INSERT` mot SQL analytics endpoint | Feil: skrivebeskyttet | Skriv med Spark, eller bruk et warehouse |
| Workspace ikke på kapasitet | Kan ikke lage lakehouse eller notebook | Tildel *Trial* eller *Fabric capacity* |
| Glemt å stoppe Spark-økten | Bruker kapasitet unødvendig | **Stop session** når du er ferdig |
| Duplikater havner i gull | Feil tall i rapporten | Rens i sølvlaget og test med `COUNT` mot `COUNT(DISTINCT)` |

### ✅ Gode råd

1. **Navnekonvensjon:** bruk prefikser som `lh_`, `wh_`, `nb_`, `pl_`, `df_`, `sm_`, `eh_` og `es_`.
2. **Hold bronse uendret.** Da kan du alltid kjøre alt på nytt fra rådataene.
3. **Ett workspace per miljø:** Dev, Test og Prod.
4. **Koble Dev-workspacet til Git** fra dag én.
5. **Bruk stjerneskjema i gull.** Power BI fungerer best med fakta- og dimensjonstabeller.
6. **Overvåk med Monitor hub** i venstremenyen. Der ser du alle kjøringer og feil.
7. **Følg med på kapasiteten** med appen *Fabric Capacity Metrics*.

---

## 19. Øvingsoppgaver

### Oppgave 1: Ditt første lakehouse (20 min) 🟢
1. Lag workspacet `Fabric-Ovelse-<navn>`.
2. Lag lakehouset `lh_ovelse`.
3. Last opp `produkter.csv` og gjør den om til en tabell med **Load to Tables**.
4. Skriv en SQL-spørring i SQL analytics endpoint som viser gjennomsnittspris per kategori.

### Oppgave 2: Rens data med notebook (45 min) 🟡
Gjenskap eksempel 2 og utvid det:
- Legg til kolonnen `kundesegment` i `solv_kunder`: **«Ny»** hvis registrert etter 2024-03-01, ellers **«Eksisterende»**.
- Lag gulltabellen `gull_salg_per_by` med omsetning per by.
- Skriv ut hvor mange rader som ble fjernet i hvert rensesteg.

### Oppgave 3: Samme jobb, to verktøy (40 min) 🟡
Rens `ordre.csv` (fjern ugyldige datoer og konverter typer) **både** med Dataflow Gen2 **og** med notebook.
Skriv en kort refleksjon på ½ side: hvilken metode var raskest å lage, hvilken er enklest å vedlikeholde, og hvilken passer best for 100 millioner rader?

### Oppgave 4: Automatiser (30 min) 🟡
Lag pipelinen `pl_ovelse` som:
1. Kjører notebooken fra oppgave 2.
2. Sender deg en e-post ved feil.
3. Er planlagt hver dag kl. 07:00.

Test feilhåndteringen ved å endre et filnavn i notebooken slik at den feiler.

### Oppgave 5: Rapport (45 min) 🟡
Lag en semantisk modell og en Power BI-rapport med:
- 3 KPI-kort
- 1 søylediagram og 1 linjediagram
- Slicer på by
- DAX-målet **«Omsetning forrige dag»** (hint: `CALCULATE` + `DATEADD` eller `PREVIOUSDAY`, og du trenger en datotabell)

### Oppgave 6: Sanntid (40 min) 🔴
Bruk Eventstream med eksempeldata og lag tre KQL-spørringer:
1. Antall hendelser per minutt siste 30 minutter, vist som graf
2. Topp 5 verdier for en valgfri kategori-kolonne
3. En spørring som bruker `bin()` og `summarize` med minst to aggregeringer

### Oppgave 7: Sluttprosjekt i gruppe (3–4 timer) 🔴
Velg et åpent datasett, for eksempel fra **data.norge.no**, **SSB** eller **Kaggle**, og bygg en komplett løsning:

| Krav | ✔ |
|---|---|
| Bronse-, sølv- og gull-lag i lakehouse | ☐ |
| Minst én notebook og én pipeline | ☐ |
| Workspace koblet til Git | ☐ |
| Semantisk modell med stjerneskjema og minst 5 DAX-mål | ☐ |
| Power BI-rapport med minst 2 sider | ☐ |
| Bonus: shortcut, KQL eller ML-modell | ☐ |

**Presentasjon på 10 min:** arkitekturskisse, demo og 3 ting dere lærte.

---

## 20. Ordliste og videre lesning

### Ordliste

| Begrep | Forklaring |
|---|---|
| **ACID** | Garanterer at en transaksjon enten fullføres helt eller ikke i det hele tatt |
| **CU (Capacity Unit)** | Målenhet for regnekraft i Fabric |
| **Delta Lake** | Åpent tabellformat oppå Parquet-filer, med transaksjonslogg |
| **DAX** | Formelspråket i Power BI og semantiske modeller |
| **ELT / ETL** | Extract-Load-Transform eller Extract-Transform-Load: måter å flytte og bearbeide data på |
| **KQL** | Kusto Query Language, spørrespråk for logg- og sanntidsdata |
| **M** | Spørrespråket bak Power Query og Dataflow Gen2 |
| **Medaljong** | Bronse-, sølv- og gull-lagdeling av data |
| **OneLake** | Fabrics felles datasjø |
| **Parquet** | Kolonnebasert og komprimert filformat |
| **PySpark** | Python-grensesnitt mot Apache Spark |
| **Semantic model** | Modell med tabeller, relasjoner og mål som Power BI bruker |
| **Stjerneskjema** | Faktatabell i midten med dimensjonstabeller rundt |
| **V-Order** | Fabrics optimalisering av Parquet-filer for rask lesing |

### Videre lesning

- Microsoft Learn: *Hva er Microsoft Fabric?*: <https://learn.microsoft.com/fabric/fundamentals/microsoft-fabric-overview>
- Microsoft Learn: læringsstier for Fabric: <https://learn.microsoft.com/training/browse/?products=fabric>
- End-to-end-veiledning for lakehouse: <https://learn.microsoft.com/fabric/data-engineering/tutorial-lakehouse-introduction>
- KQL-referanse: <https://learn.microsoft.com/kusto/query/>
- DAX-guide: <https://dax.guide>
- Sertifisering: **DP-600** (*Fabric Analytics Engineer*) og **DP-700** (*Fabric Data Engineer*)

---

> **Lærernotat:** Avsnitt 1–7 og oppgave 1–2 passer for første undervisningsdag. Dag to kan dekke pipeline, Dataflow og Power BI (avsnitt 9–11, oppgave 3–5). Sanntid, ML og samarbeid (avsnitt 12–15) passer for viderekomne eller som valgfri fordypning. Grensesnittet i Fabric endres ofte, så sjekk at menynavnene stemmer før timen.
