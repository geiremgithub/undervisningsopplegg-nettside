---
title: "SAP Datasphere"
description: "Spaces, views, analytic model, dataflyt med Python og live-tilkobling fra SAC."
order: 7
---

# SAP Datasphere

## 15. Eksempel 10: SAP Datasphere: space, views og analytic model

### 15.1 Opprett space

1. Logg inn i **SAP Datasphere** og velg **Space Management** → **Create**.
2. Navn: `NORDLYS`. Space-ID: `NORDLYS`. ID-en kan ikke endres senere.
3. Sett lagringskvote (disk og minne) og legg til deg selv som medlem.
4. Klikk **Deploy**.

### 15.2 Last inn data

**Alternativ A: fra fil**

1. **Data Builder** → space `NORDLYS` → **Import** → **Import CSV File** → `salg.csv`.
2. Kontroller datatypene: `Dato` → Date, `Omsetning` → Decimal.
3. Lagre som lokal tabell `T_SALG` og klikk **Deploy**.

**Alternativ B: fra HANA Cloud (eksempel 9)**

1. **Connections** → **Create** → **SAP HANA** (Cloud). Bruk vertsnavn og bruker fra eksempel 9.
2. **Data Builder** → **New Graphical View** → dra tabellen `SALG` fra *Sources* → *Connections*. Da opprettes en **remote table**.
3. Velg om dataene skal leses direkte (federation) eller replikeres (snapshot eller sanntid).

### 15.3 Graphical view: rens og berik

1. **Data Builder** → **New Graphical View** og dra inn `T_SALG`.
2. Legg til operatorer:
   - **Projection:** fjern kolonner du ikke trenger.
   - **Calculated Columns:** legg til `DEKNINGSBIDRAG = OMSETNING - KOSTNAD` og `AAR = YEAR(DATO)`.
   - **Filter:** for eksempel `OMSETNING > 0`.
3. Sett **Semantic Usage = Fact** og marker `Omsetning`, `Kostnad`, `Antall` og `Dekningsbidrag` som **Measures**.
4. Lagre som `V_SALG_FACT` og klikk **Deploy**.

### 15.4 SQL view: samme med SQL

**Data Builder** → **New SQL View**:

```sql
SELECT
    "Dato",
    "Region",
    "By",
    "Produkt",
    "Kategori",
    "Antall",
    "Omsetning",
    "Kostnad",
    "Omsetning" - "Kostnad"            AS "Dekningsbidrag",
    YEAR("Dato")                       AS "Aar",
    MONTH("Dato")                      AS "Maaned"
FROM "T_SALG"
WHERE "Omsetning" > 0
```

### 15.5 Dimensjon og assosiasjon

1. Lag view-et `V_PRODUKT_DIM` med kolonnene `Produkt` og `Kategori`. Sett **Semantic Usage = Dimension**.
2. Åpne `V_SALG_FACT`, velg **Associations** → **+** → `V_PRODUKT_DIM` og koble `Produkt = Produkt`.

```text
          ┌──────────────────┐
          │ V_PRODUKT_DIM    │  (Dimension)
          └────────┬─────────┘
                   │ assosiasjon
          ┌────────▼─────────┐
          │ V_SALG_FACT      │  (Fact)
          └────────┬─────────┘
                   │
          ┌────────▼─────────┐
          │ AM_NORDLYS_SALG  │  (Analytic Model) ──▶ SAC
          └──────────────────┘
```

### 15.6 Analytic model

1. **Data Builder** → **New Analytic Model** og velg `V_SALG_FACT`.
2. Velg hvilke **measures** og **dimensjoner** som skal være med. Assosierte dimensjoner hentes automatisk.
3. Legg til et **calculated measure**:

   ```text
   DB_PROSENT = "Dekningsbidrag" / "Omsetning" * 100
   ```

4. Legg til et **restricted measure**, `Omsetning Ski`, med filteret `Kategori = 'Ski'`.
5. Bruk **Data Preview** for å teste, og klikk **Deploy**.
6. Lagre som `AM_NORDLYS_SALG`.

> 💡 En analytic model i Datasphere tilsvarer omtrent en semantisk modell i Power BI. Den er bindeleddet mellom datalageret og rapportene.

---

## 16. Eksempel 11: Dataflyt med Python i Datasphere

**Data Flow** brukes til ETL-jobber som transformerer data og skriver dem til en måltabell. Den kan inneholde en **Script**-operator med **Python** (pandas).

### 16.1 Bygg dataflyten

1. **Data Builder** → **New Data Flow**.
2. Dra inn kilden `T_SALG`.
3. Legg til operatoren **Script** (Python).
4. Legg til **Target Table**: en ny tabell, `T_SALG_RENSET`.
5. Koble sammen: `T_SALG` → `Script` → `T_SALG_RENSET`.

### 16.2 Python-kode i Script-operatoren

```python
def transform(data):
    # 'data' er en pandas DataFrame med radene fra kilden

    # Standardiser bynavn: "oslo" → "Oslo"
    data["By"] = data["By"].str.strip().str.title()

    # Beregn dekningsbidrag og priskategori
    data["Dekningsbidrag"] = data["Omsetning"] - data["Kostnad"]
    data["Prisklasse"] = data["Omsetning"].apply(
        lambda x: "Høy" if x > 50000 else ("Middels" if x > 20000 else "Lav")
    )

    # Fjern rader med negativ eller manglende omsetning
    data = data[data["Omsetning"].notna() & (data["Omsetning"] > 0)]

    return data
```

> ⚠️ Kolonnene du lager i scriptet (`Dekningsbidrag`, `Prisklasse`) må også legges til i **output-kolonnene** til Script-operatoren. Ellers feiler dataflyten.

### 16.3 Kjør og planlegg

1. Klikk **Deploy** og deretter **Run**.
2. Følg med på kjøringen i **Data Integration Monitor** → **Flows**.
3. Planlegg den: **Schedule** → daglig kl. 06:00.

> 💡 Nyere versjoner av Datasphere har også **Transformation Flow**, som er SQL-basert og støtter delta-last, og **Replication Flow** for effektiv kopiering fra SAP-kilder. Bruk *Task Chains* for å kjøre flere steg i rekkefølge.

---

## 17. Eksempel 12: Koble SAC live mot Datasphere

### 17.1 Opprett tilkobling i SAC

1. I SAC: **Connections** → **+** → **Connect to Live Data** → **SAP Datasphere**.
2. Fyll inn vertsnavnet til Datasphere-tenanten.
3. Lagre som `DSP_NORDLYS`.

> Når SAC og Datasphere er i samme tenantoppsett eller del av Business Data Cloud, kan tilkoblingen være satt opp på forhånd.

### 17.2 Bruk analytic model i en story

1. **Stories** → **Create New** → **Add data** → **Data from a datasource** → `DSP_NORDLYS`.
2. Velg space `NORDLYS` og analytic model `AM_NORDLYS_SALG`.
3. Bygg diagrammene som i eksempel 2. Dataene leses nå **live**, uten kopiering til SAC.

### 17.3 Live eller import?

| | Live | Import |
|---|---|---|
| Data i SAC | Nei, spørres ved visning | Ja, kopieres |
| Alltid oppdatert | ✅ | ❌ (må planlegges) |
| Planlegging | Begrenset* | ✅ |
| Smart Predict, Smart Discovery | Begrenset | ✅ |
| Datasikkerhet i kilden | ✅ Brukes direkte | Må settes opp på nytt i SAC |
| Typisk bruk | Rapportering på store datamengder | Planlegging, prognoser, blanding av kilder |

\* SAP utvider stadig mulighetene for planlegging på live-data, så sjekk gjeldende dokumentasjon.
