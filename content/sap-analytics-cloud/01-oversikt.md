---
title: "Oversikt og kom i gang"
description: "SAPs skylandskap, kjernebegreper, prøvekontoer og testdataene for Nordlys Sport."
order: 1
---

# Oversikt og kom i gang

> **Mål:** Etter denne gjennomgangen kan du forklare hvordan SAPs skyplattform henger sammen, bygge en datamodell og en analyserapport (story) i SAP Analytics Cloud, lage et enkelt planleggingsscenario og hente data fra SAP Datasphere og SAP HANA Cloud.
>
> **Forkunnskaper:** Grunnleggende Excel og litt SQL. JavaScript og Python er en fordel i noen av eksemplene, men ikke et krav.
>
> **Gjennomgående case:** Vi bygger analyse og budsjettering for netthandelen **«Nordlys Sport»**, som selger sportsutstyr i Norge.

---

## 1. Oversikt: SAPs skylandskap

SAP har mange skyprodukter. For analyse er disse de viktigste:

```text
┌───────────────────────────────────────────────────────────────────────────┐
│                         SAP Business Data Cloud                           │
│                                                                           │
│  ┌───────────────────────────────┐   ┌─────────────────────────────────┐  │
│  │   SAP Analytics Cloud (SAC)   │   │      SAP Datasphere             │  │
│  │  • Rapporter (stories)        │◀──│  • Samler og modellerer data    │  │
│  │  • Planlegging og budsjett    │   │  • Spaces, views, analytic      │  │
│  │  • Prognoser (Smart Predict)  │   │    models, dataflyter           │  │
│  └───────────────────────────────┘   └────────────────┬────────────────┘  │
│                                                       │                   │
│                                      ┌────────────────▼────────────────┐  │
│                                      │       SAP HANA Cloud            │  │
│                                      │  In-memory database (SQL)       │  │
│                                      └─────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────────────────┤
│              SAP Business Technology Platform (SAP BTP)                   │
│  Kontoer, tilganger, integrasjon, app-utvikling (CAP), AI-tjenester       │
└───────────────────────────────────────────────────────────────────────────┘
          ▲                    ▲                     ▲
   SAP S/4HANA          SuccessFactors          Ikke-SAP-kilder
   (ERP)                (HR)                    (CSV, SQL Server, Snowflake …)
```

| Produkt | Hva det er | Typisk bruker |
|---|---|---|
| **SAP Analytics Cloud (SAC)** | BI, planlegging og prediksjon i én nettleserbasert løsning | Controller, analytiker, leder |
| **SAP Datasphere** | Datalager og datamodellering i skyen. Etterfølgeren til SAP BW og Data Warehouse Cloud. | Datamodellerer, dataingeniør |
| **SAP HANA Cloud** | Rask in-memory database som tjenester som Datasphere bygger på | Utvikler, databaseadministrator |
| **SAP BTP** | Selve skyplattformen: kontoer, tjenester, integrasjon og utvikling | Plattformadministrator, utvikler |
| **SAP Business Data Cloud** | En samlet pakke med Datasphere, SAC og ferdige dataprodukter fra SAP-systemer | Hele organisasjonen |

> 💡 **Kort sagt:** **BTP** er tomten og strømmen. **HANA Cloud** er grunnmuren. **Datasphere** er lageret der data samles og ryddes. **SAC** er utstillingsvinduet der folk ser, analyserer og planlegger.

---

## 2. Kjernebegreper

### SAP Analytics Cloud

| Begrep | Forklaring | Analogi |
|---|---|---|
| **Tenant** | Organisasjonens SAC-installasjon (egen URL) | Hele skolen |
| **Model** | Strukturen for dataene: dimensjoner, mål eller konti, hierarkier | Oppskriften på et regneark |
| **Dataset** | Enklere, flat datastruktur for rask analyse | Et enkelt regneark |
| **Dimension** | Noe du grupperer etter: produkt, kunde, dato, region | Kolonneoverskrift du filtrerer på |
| **Measure** | Tall du summerer: beløp, antall | Tallene i regnearket |
| **Account** | Spesiell dimensjon i planleggingsmodeller, for eksempel kontoplan | Kontoene i regnskapet |
| **Version** | Ulike utgaver av tallene: *Actual*, *Budget*, *Forecast* | Faktisk og budsjett |
| **Story** | Rapport eller dashbord med sider, diagrammer og tabeller | Powerpoint med levende tall |
| **Data action** | Automatisk beregning i planleggingsmodeller (kopier, fordel, regn ut) | Makro i Excel |
| **Import- eller live-tilkobling** | Kopier data inn i SAC, eller spør kilden direkte | Laste ned eller strømme |

### SAP BTP og Datasphere

| Begrep | Forklaring |
|---|---|
| **Global account** | Toppnivået: kontrakten mellom kunden og SAP |
| **Subaccount** | Et miljø inne i den globale kontoen (for eksempel Dev og Prod), knyttet til en region |
| **Entitlement** | Retten til å bruke en tjeneste og hvor mye (kvote) |
| **Space** (Datasphere) | Et avgrenset arbeidsområde med egne data, brukere og lagringskvote |
| **Local table** | Tabell lagret i Datasphere |
| **Remote table** | Tabell som peker på en kilde, med mulighet for å kopiere eller replikere |
| **View** | Grafisk eller SQL-basert visning som transformerer data |
| **Analytic model** | Forretningsklar modell med mål og dimensjoner, laget for SAC |
| **Semantic usage** | Hva et objekt *er*: Fact, Dimension, Text, Hierarchy … |

---

## 3. Komme i gang: prøvekontoer

| Produkt | Hvordan få tilgang |
|---|---|
| **SAP Analytics Cloud** | Gratis prøveperiode via SAPs nettsider (søk etter *SAP Analytics Cloud trial*), eller tilgang fra skolen eller arbeidsgiveren |
| **SAP BTP** | **SAP BTP Trial** eller **Free Tier** via <https://account.hanatrial.ondemand.com> eller SAP for Me |
| **SAP Datasphere** | Prøveperiode via SAPs nettsider, eller en tenant som skolen eller arbeidsgiveren har tilgang til |
| **SAP HANA Cloud** | Tilgjengelig som tjeneste i BTP Trial eller Free Tier |

> ⚠️ Prøvekontoer varer en begrenset tid, og noen funksjoner, som planlegging og Smart Predict, kan være begrenset. Undersøk hva skolen har avtale om før kurset starter. SAP har også egne universitetsprogrammer, for eksempel **SAP University Alliances**.

**Nettlesertips:** SAC fungerer best i Chrome eller Edge. Tillat popup-vinduer for tenant-adressen.

---

## 4. Testdata for Nordlys Sport

Lagre disse filene lokalt. Vi bruker dem gjennom hele dokumentet.

📄 `salg.csv` (faktiske tall)

```csv
Dato,Region,By,Produkt,Kategori,Antall,Omsetning,Kostnad
2024-01-15,Øst,Oslo,Langrennski Pro,Ski,12,59988,36000
2024-01-20,Vest,Bergen,Langrennski Pro,Ski,8,39992,24000
2024-02-03,Øst,Oslo,Skistaver Karbon,Ski,20,25980,14000
2024-02-14,Midt,Trondheim,Løpesko Fjell,Løping,15,28485,15000
2024-03-01,Vest,Stavanger,Løpejakke Vind,Løping,10,14990,7500
2024-03-18,Øst,Oslo,Sykkelhjelm Aero,Sykkel,25,24975,12500
2024-04-05,Vest,Bergen,Løpesko Fjell,Løping,30,56970,30000
2024-04-22,Midt,Trondheim,Sykkelhjelm Aero,Sykkel,18,17982,9000
2024-05-10,Øst,Oslo,Løpejakke Vind,Løping,22,32978,16500
2024-05-28,Vest,Stavanger,Sykkelhjelm Aero,Sykkel,35,34965,17500
2024-06-12,Øst,Oslo,Løpesko Fjell,Løping,40,75960,40000
2024-06-30,Midt,Trondheim,Skistaver Karbon,Ski,5,6495,3500
```

📄 `budsjett.csv` (til planleggingseksemplet)

```csv
Måned,Region,Kategori,Konto,Beløp
202407,Øst,Løping,Omsetning,80000
202407,Vest,Løping,Omsetning,60000
202407,Midt,Løping,Omsetning,30000
202407,Øst,Sykkel,Omsetning,25000
202407,Vest,Sykkel,Omsetning,35000
202407,Midt,Sykkel,Omsetning,20000
```
