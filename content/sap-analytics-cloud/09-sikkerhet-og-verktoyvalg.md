---
title: "Sikkerhet og valg av verktøy"
description: "Tilgangsstyring i SAC, Datasphere og BTP, og når du bruker hva."
order: 9
---

# Sikkerhet og valg av verktøy

## 19. Sikkerhet og tilganger

### SAP Analytics Cloud

| Nivå | Mekanisme | Eksempel |
|---|---|---|
| Bruker | **Roles** (BI Viewer, BI Content Creator, Planner Reporter, Admin …) | Studenter får *BI Viewer* |
| Mappe/fil | Deling av stories og modeller (Files) | Del storyen med "Salgsteam" |
| Data | **Data access control** på dimensjoner | Regionsjef Øst ser bare `Region = Øst` |
| Planlegging | **Data locking** og **Version management** | Lås januar etter regnskapsavslutning |
| Team | **Teams** for å gruppere brukere | `TEAM_OST`, `TEAM_VEST` |

### SAP Datasphere

| Nivå | Mekanisme |
|---|---|
| Space | Medlemskap og scoped roles per space |
| Data | **Data Access Controls (DAC)**: radnivåsikkerhet basert på kriterier eller tabeller |
| Deling | Objekter kan deles mellom spaces |

**Eksempel på radnivåsikkerhet i Datasphere:**

1. Lag tabellen `T_TILGANG` med kolonnene `Bruker` og `Region`:

   ```csv
   Bruker,Region
   kari@nordlys.no,Øst
   ola@nordlys.no,Vest
   sjef@nordlys.no,*
   ```

2. **Data Builder** → **New Data Access Control** → type **Single Values** og koble til `T_TILGANG`.
3. Knytt DAC-en til `V_SALG_FACT` på kolonnen `Region`.
4. Kari ser nå bare Øst, både i Datasphere og i SAC via live-tilkoblingen.

### SAP BTP

- **Role Collections** samler roller og tildeles brukere eller grupper.
- **Identity Authentication Service (IAS)** gir pålogging med organisasjonens konto (SSO).
- Prinsippet om **minste privilegium** gjelder også her: gi bare de tilgangene som trengs.

---

## 20. Velg riktig verktøy

```text
                           Hva skal du gjøre?
                                  │
     ┌──────────────┬─────────────┼──────────────┬──────────────────┐
     ▼              ▼             ▼              ▼                  ▼
 Rapportere/    Budsjett/     Samle data     Rå SQL/            Egen app
 analysere?     prognose?     fra mange      database-          eller API?
     │              │         kilder?        ytelse?                │
     ▼              ▼             │              │                  ▼
   SAC          SAC Planning      ▼              ▼              CAP på BTP
   Story        + Data actions  Datasphere    HANA Cloud
                + Smart Predict (views, flows,
                                 analytic model)
```

| Behov | Anbefalt verktøy |
|---|---|
| Dashbord og rapporter | SAC Stories |
| Rask analyse av en fil | SAC Dataset + Story |
| Budsjett, prognose, scenarioer | SAC Planning |
| Maskinlæring uten kode | SAC Smart Predict |
| Spørsmål på naturlig språk | SAC Just Ask / Joule |
| Samle og modellere data fra SAP og andre systemer | SAP Datasphere |
| ETL og transformasjoner | Datasphere Data Flow / Transformation Flow |
| Effektiv replikering fra S/4HANA | Datasphere Replication Flow |
| Rask SQL på store datamengder | SAP HANA Cloud |
| Egne forretningsapper og API-er | CAP på SAP BTP |
| Apper uten kode | SAP Build Apps |
| Integrasjon mellom systemer | SAP Integration Suite |

### Sammenligning med Microsoft Fabric

| SAP | Microsoft Fabric (omtrent tilsvarende) |
|---|---|
| SAP Analytics Cloud (Stories) | Power BI-rapporter |
| SAP Analytics Cloud (Planning) | Ingen innebygd planlegging (tredjeparts løsninger) |
| SAP Datasphere | Lakehouse/Warehouse + Dataflow/Pipeline |
| Analytic Model | Semantic Model |
| SAP HANA Cloud | Warehouse / SQL database |
| SAP BTP | Azure-plattformen |
