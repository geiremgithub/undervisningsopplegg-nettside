---
title: "Hva er Microsoft Fabric?"
description: "Hva Fabric er, kjernebegreper og hvordan du kommer i gang."
order: 1
---

# Hva er Microsoft Fabric?

> **Mål:** Etter denne gjennomgangen kan du forklare hva Microsoft Fabric er, bygge en enkel dataplattform fra rådata til ferdig rapport, og vite hvilket Fabric-verktøy du bør velge til hvilken oppgave.
>
> **Forkunnskaper:** Grunnleggende SQL. Litt Python er en fordel, men ikke et krav.
>
> **Gjennomgående case:** Vi bygger en analyseplattform for netthandelen **«Nordlys Sport»**, som selger sportsutstyr i Norge.

---

## 1. Hva er Microsoft Fabric?

**Microsoft Fabric** er en samlet analyseplattform i skyen (SaaS) fra Microsoft. Den samler verktøy som tidligere var separate produkter, som Azure Data Factory, Azure Synapse og Power BI, i **én tjeneste** med **én felles datalagring**.

### Før og etter Fabric

```text
FØR: mange separate tjenester                ETTER: én plattform
┌────────────┐ ┌────────────┐ ┌──────────┐    ┌──────────────────────────────────────┐
│ Data       │ │ Synapse /  │ │ Power BI │    │           Microsoft Fabric           │
│ Factory    │→│ Databricks │→│          │    │ Data Factory · Data Engineering ·    │
└────────────┘ └────────────┘ └──────────┘    │ Data Warehouse · Data Science ·      │
      ↓              ↓              ↓         │ Real-Time Intelligence · Power BI ·  │
┌────────────┐ ┌────────────┐ ┌──────────┐    │ Databases · Copilot                  │
│ Storage A  │ │ Storage B  │ │ Kopi C   │    ├──────────────────────────────────────┤
└────────────┘ └────────────┘ └──────────┘    │       OneLake (én felles datasjø)    │
Mange kopier, mange tilganger, mange fakturaer └──────────────────────────────────────┘
```

### Hvorfor er dette nyttig?

- **Én kopi av dataene.** Alle verktøy leser fra OneLake, så du slipper å flytte data mellom tjenester.
- **Åpent format.** Tabeller lagres som **Delta Parquet**, et åpent format som også andre verktøy kan lese.
- **Én faktura, én tilgangsstyring.** Du betaler for *kapasitet*, ikke for hver enkelt tjeneste.
- **Lav terskel.** Det samme systemet støtter både dra-og-slipp-verktøy og kode (SQL, Python, KQL).

---

## 2. Kjernebegreper

| Begrep | Forklaring | Analogi |
|---|---|---|
| **Tenant** | Organisasjonens Fabric-miljø | Hele skolen |
| **Capacity** (kapasitet) | Regnekraften du betaler for (F2, F4 … F64 …). Måles i *Capacity Units (CU)*. | Strømabonnementet |
| **Workspace** (arbeidsområde) | En mappe med Fabric-elementer og tilganger. Knyttes til én kapasitet. | Et klasserom |
| **Item** (element) | Én ting i et workspace: lakehouse, notebook, pipeline, rapport … | Et skap i klasserommet |
| **OneLake** | Den felles datasjøen for hele tenanten. «OneDrive for data.» | Skolens felles lager |
| **Lakehouse** | Lagrer både filer og tabeller. Brukes med Spark og SQL (lesing). | Lager med hyller *og* løse esker |
| **Warehouse** | Fullverdig SQL-datavarehus med T-SQL for både lesing og skriving | Et ryddig arkiv |
| **Delta-tabell** | Tabellformatet i OneLake. Støtter transaksjoner og tidsreiser. | Et regneark med full historikk |
| **Notebook** | Interaktiv kode (PySpark, Spark SQL, Python, R) | Laboratoriebok |
| **Pipeline** | Orkestrerer og automatiserer dataflyt | Samlebånd |
| **Dataflow Gen2** | Datatransformasjon med Power Query (lite eller ingen kode) | Excel på steroider |
| **Semantic model** | Datamodellen Power BI bruker (relasjoner og mål) | Oppslagsverket |
| **Eventhouse / KQL Database** | Database for sanntids- og loggdata | Overvåkningssentral |
| **Shortcut** | En lenke til data et annet sted, uten at dataene kopieres | Snarvei på skrivebordet |

### Hierarkiet

```text
Tenant (organisasjonen)
└── Capacity (F64)
    ├── Workspace: "NordlysSport-Dev"
    │   ├── Lakehouse: lh_nordlys
    │   ├── Notebook: nb_bronse_til_solv
    │   ├── Pipeline: pl_daglig_last
    │   └── Rapport: Salgsoversikt
    └── Workspace: "NordlysSport-Prod"
        └── ...
```

---

## 3. Komme i gang

### 3.1 Få tilgang

1. Gå til **<https://app.fabric.microsoft.com>**.
2. Logg inn med skole- eller jobbkonto. Fabric krever en organisasjonskonto, ikke en privat Gmail- eller Outlook-konto.
3. Hvis du ikke har en lisens, klikker du på profilbildet og velger **Start trial** (prøveperiode). Det gir deg en prøvekapasitet i en begrenset periode.

> 💡 Spør læreren eller IT-avdelingen hvis prøveperioden er deaktivert i organisasjonen. En administrator kan tildele et workspace til en kapasitet.

### 3.2 Opprett et workspace

1. Velg **Workspaces** i venstremenyen og klikk **+ New workspace**.
2. Navn: `NordlysSport-<ditt-navn>`.
3. Under **Advanced** velger du lisensmodus **Trial** eller **Fabric capacity**.
4. Klikk **Apply**.

### 3.3 Roller i et workspace

| Rolle | Kan … |
|---|---|
| **Admin** | Alt, også slette workspacet og styre tilganger |
| **Member** | Legge til andre (unntatt admin), dele og redigere |
| **Contributor** | Lage og redigere elementer |
| **Viewer** | Bare se og lese |
