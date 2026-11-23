---
title: "Samarbeid, Copilot og valg av verktøy"
description: "Git, deployment pipelines, sikkerhet, Copilot og når du bruker hva."
order: 9
---

# Samarbeid, Copilot og valg av verktøy

## 15. Samarbeid: Git, deployment pipelines og sikkerhet

### 15.1 Git-integrasjon

1. Gå til **Workspace settings → Git integration**.
2. Koble workspacet til et repo i **Azure DevOps** eller **GitHub**.
3. Fabric-elementer som notebooks, pipelines og semantiske modeller lagres som filer i repoet.
4. Bruk **Commit** og **Update** i kildekontrollpanelet.

```text
Utvikler A ─┐                         ┌─▶ Workspace Dev
            ├─▶ Git (feature-branch) ─┤
Utvikler B ─┘     ↓ pull request      └─▶ Code review
                main
```

### 15.2 Deployment pipelines (Dev → Test → Prod)

```text
┌──────────┐   Deploy   ┌──────────┐   Deploy   ┌──────────┐
│   Dev    │──────────▶ │   Test   │──────────▶ │   Prod   │
│workspace │            │workspace │            │workspace │
└──────────┘            └──────────┘            └──────────┘
```

1. Velg **Workspaces → Deployment pipelines → + New pipeline**.
2. Knytt et workspace til hvert steg.
3. Klikk **Deploy** for å flytte elementer videre.
4. Bruk **deployment rules** for å bytte for eksempel datakilde mellom test og produksjon.

### 15.3 Sikkerhet i lag

| Nivå | Mekanisme | Eksempel |
|---|---|---|
| Workspace | Roller (Admin/Member/Contributor/Viewer) | Studentene får Viewer |
| Element | Deling og tilganger per element | Del bare rapporten, ikke lakehouset |
| OneLake | OneLake security (data access roles) | Tilgang til bare enkelte mapper eller tabeller |
| Rad (RLS) | Row-Level Security | Selger i Oslo ser bare Oslo-salg |
| Kolonne (CLS) | Column-Level Security | Skjul e-postkolonnen |
| Maskering | Dynamic Data Masking | Vis `k***@example.no` |

**Eksempel: Row-Level Security i warehouse**

```sql
-- Funksjon som avgjør hvilke rader brukeren får se
CREATE FUNCTION dbo.fn_rls_by(@by AS VARCHAR(50))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS tilgang
    WHERE @by = 'Oslo' AND USER_NAME() = 'selger.oslo@nordlys.no'
       OR USER_NAME() = 'sjef@nordlys.no';
GO

CREATE SECURITY POLICY dbo.policy_by
ADD FILTER PREDICATE dbo.fn_rls_by(by) ON dbo.dim_kunde
WITH (STATE = ON);
```

---

## 16. Copilot og AI i Fabric

Hvis Copilot er aktivert i organisasjonen og kapasiteten støtter det, finnes AI-hjelp flere steder:

| Hvor | Hva Copilot kan gjøre | Eksempel på prompt |
|---|---|---|
| Notebook | Skrive og forklare PySpark-kode | *«Lag kode som fjerner duplikater i kunder_raw basert på kunde_id»* |
| Warehouse / SQL | Skrive SQL fra naturlig språk | *«Vis topp 5 produkter etter omsetning siste måned»* |
| Dataflow Gen2 | Lage transformasjonssteg | *«Fjern rader der epost er tom»* |
| Power BI | Lage rapportsider og DAX-mål, oppsummere | *«Lag en side som viser salg per kategori og by»* |
| KQL | Skrive KQL-spørringer | *«Antall klikk per produkt siste time»* |

**Fabric data agent** (tidligere *AI skill*) lar deg lage en egen chatassistent som svarer på spørsmål om *dine* data, for eksempel fra lakehouse, warehouse eller semantisk modell. Du gir den instruksjoner og eksempelspørsmål, og den oversetter spørsmål til SQL, DAX eller KQL.

> ⚠️ Kontroller alltid kode og tall fra AI. Copilot kan ta feil.

---

## 17. Velg riktig verktøy

```text
                          Hva skal du gjøre?
                                 │
      ┌──────────────┬───────────┼─────────────┬────────────────┐
      ▼              ▼           ▼             ▼                ▼
  Flytte/hente   Transformere  Lagre/spørre  Sanntid?       Visualisere?
    data?          data?         data?          │                │
      │              │           │              ▼                ▼
      ▼              │           │          Eventstream      Power BI
  Pipeline           │           │          + Eventhouse     (Direct Lake)
  (Copy data)        │           │          + KQL
  eller Mirroring    │           │
                     │           ├─ SQL-folk, full T-SQL ──▶ Warehouse
          ┌──────────┴────┐      └─ Spark, filer, ML ──────▶ Lakehouse
          ▼               ▼
     Kan kode?       Liker Excel/
     → Notebook      Power Query?
       (PySpark)     → Dataflow Gen2
```

| Behov | Anbefalt verktøy |
|---|---|
| Kopiere store datamengder fra kilde | Pipeline → Copy data |
| Speile en database kontinuerlig | Mirroring |
| Kompleks transformasjon eller store data | Notebook (PySpark) |
| Enkel transformasjon uten kode | Dataflow Gen2 |
| Lagre filer og tabeller, bruke Spark og ML | Lakehouse |
| Ren SQL-verden med skriving | Warehouse |
| Applikasjonsdatabase (OLTP) | SQL database in Fabric |
| Logger, IoT og strømmende data | Eventhouse + KQL |
| Rapporter og dashbord | Power BI |
| Varsler basert på data | Activator |
| Bruke data uten å kopiere | Shortcut |
