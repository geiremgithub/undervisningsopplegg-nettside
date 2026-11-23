---
title: "Videoer: Datavarehus og dataintegrasjon"
description: "Utvalgte videoer som forklarer begrepene og teknikkene i hver samling. Fint før samlingen eller til repetisjon."
order: 9
---

# Videoer: Datavarehus og dataintegrasjon

Videoene er sortert etter samling. Alle er på engelsk og gratis på YouTube. Se dem gjerne **før** samlingen, så har du begrepene klare.

> Lenkene er kontrollert, og alle videoene var offentlig tilgjengelige i november 2026. Beskrivelsene bygger på tittel, kanal og lengde. Noen videoer viser andre databaser enn SQL Server, men prinsippene er de samme.

---

## Samling 1: Fra kildesystem til datavarehus

Se [Samling 1](01-samling-1.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [Database vs Data Warehouse vs Data Lake – What is the Difference?](https://www.youtube.com/watch?v=-bSkREem8dM) | YouTube – Alex The Analyst · 5:22 | Rask og enkel forklaring av forskjellen på en vanlig database, et datavarehus og en data lake. God første video. |
| [OLAP vs OLTP](https://www.youtube.com/watch?v=iw-5kFzIdgY) | YouTube – IBM Technology · 5:26 | Forskjellen på systemer for transaksjoner (OLTP) og for analyse (OLAP). Kjernen i samling 1. |
| [Data Lake vs. Data Warehouse vs. Data Lakehouse: Which One to Choose?](https://www.youtube.com/watch?v=PQFWQmL3fLY) | YouTube – IBM Technology · 7:53 | Når du velger lake, warehouse eller lakehouse. Fin bro til Microsoft Fabric-emnet. |
| [Let's Compare the Kimball and Inmon Data Warehouse Architectures](https://www.youtube.com/watch?v=Tff34jj_V-0) | YouTube – nullQueries · 5:16 | De to klassiske arkitekturene for datavarehus side om side. |

## Samling 2: Dimensjonsmodellering

Se [Samling 2](02-samling-2.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [What is STAR schema – Star vs Snowflake Schema – Fact vs Dimension Table](https://www.youtube.com/watch?v=hQvCOBv_-LE) | YouTube – codebasics · 6:59 | Faktatabeller, dimensjonstabeller, stjerneskjema og snøfnuggskjema på sju minutter. |
| [Data Modeling Tutorial: Star Schema (aka Kimball Approach)](https://www.youtube.com/watch?v=gRE3E7VUzRU) | YouTube – Kahan Data Solutions · 16:34 | Bygger et stjerneskjema steg for steg etter Kimball-metoden. Mer praktisk og grundigere enn videoen over. |
| [How to Track History in a Data Warehouse (Slowly Changing Dimensions)](https://www.youtube.com/watch?v=LFoNaUVby9Q) | YouTube – Kahan Data Solutions · 13:52 | Hvordan historikk tas vare på med Slowly Changing Dimensions (SCD). |
| [Slowly Changing Dimensions For Data Engineers](https://www.youtube.com/watch?v=1FZ7et0pN4c) | YouTube – Seattle Data Guy · 8:15 | SCD type 1, 2 og 3 forklart fra en dataingeniørs ståsted. |

## Samling 3: ETL og ELT

Se [Samling 3](03-samling-3.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [ETL vs ELT – Modern Data Architectures](https://www.youtube.com/watch?v=_Nk0v9qUWk4) | YouTube – Kahan Data Solutions · 4:42 | Kort og tydelig om forskjellen på å transformere før og etter lasting. |
| [ETL vs ELT: Powering Data Pipelines for AI & Analytics](https://www.youtube.com/watch?v=KIv2Na2-u24) | YouTube – IBM Technology · 6:51 | Hvorfor moderne skyplattformer ofte bruker ELT, og når ETL fortsatt er riktig. |

## Samling 4: SQL for analyse

Se [Samling 4](04-samling-4.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [SQL Window Functions – Clearly Explained (PARTITION BY, ORDER BY, ROW_NUMBER, RANK, DENSE_RANK)](https://www.youtube.com/watch?v=rIcB4zMYMas) | YouTube – Maven Analytics · 7:52 | Den beste korte innføringen i vindusfunksjoner, med visuelle eksempler. |
| [SQL Window Function – How to write SQL Query using RANK, DENSE RANK, LEAD/LAG](https://www.youtube.com/watch?v=Ww71knvhQ-s) | YouTube – techTFQ · 24:55 | Grundig gjennomgang med mange spørringer, inkludert `LEAD` og `LAG`. Fin til lab 4. |
| [SQL WITH Clause – CTEs vs Subqueries vs Temp Tables – Recursive CTEs](https://www.youtube.com/watch?v=LJC8277LONg) | YouTube – Maven Analytics · 13:15 | CTE-er, og når du bør bruke CTE, subquery eller midlertidig tabell. |

## Samling 5: Indeksering

Se [Samling 5](05-samling-5.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [How to Think Like the Engine Part 1](https://www.youtube.com/watch?v=HhqOrbX3Bls) | YouTube – Brent Ozar Unlimited · 45:24 | Klassikeren som samling 5 bygger på: hvordan SQL Server leser sider og bruker indekser. **Anbefalt før samlingen.** |
| [Clustered vs. Nonclustered Index Structures in SQL Server](https://www.youtube.com/watch?v=ITcOiLSfVJQ) | YouTube – Voluntary DBA · 8:04 | Hvordan clustered og nonclustered indekser er bygd opp som B-trær. Eldre video, men prinsippene er de samme i dag. |
| [SQL Indexes (Visually Explained) – Clustered vs Nonclustered](https://www.youtube.com/watch?v=BxAj3bl00-o) | YouTube – Data with Baraa · 43:10 | Lang og grundig visuell gjennomgang av indekser, med eksempler. |
| [SQL Columnstore Index (Visually Explained) – Columnstore vs Rowstore](https://www.youtube.com/watch?v=k9DpO91W76o) | YouTube – Data with Baraa · 26:23 | Columnstore-indekser, og hvorfor de er så raske for analyse. |
| [SQL Server Quickie #40 – ColumnStore Indexes](https://www.youtube.com/watch?v=x1WNQ1mNiAk) | YouTube – SQLpassion · 6:25 | Kort demo av columnstore i SQL Server. |

## Samling 6: Spørringsoptimalisering

Se [Samling 6](06-samling-6.md).

| Video | Kilde og lengde | Hva den dekker |
|---|---|---|
| [How To Read SQL Server Execution Plans](https://www.youtube.com/watch?v=wYRreJZMYy4) | YouTube – Bert Wagner · 6:45 | Hvordan du leser en execution plan i SSMS: retning, operatorer og kostnader. |
| [SQL Execution Plans (Visually Explained) – SQL Hints](https://www.youtube.com/watch?v=O7AzUDogXsw) | YouTube – Data with Baraa · 32:16 | Scan vs. seek, join-typer og query hints, med mange eksempler. |
| [SQL Table Partitioning (Visually Explained) – Optimize Big Table Performance](https://www.youtube.com/watch?v=tQQ3XwrKbfM) | YouTube – Data with Baraa · 33:22 | Partisjonering av store tabeller: hvorfor og hvordan. |

---

> **Lærernotat:** Brent Ozar-videoen er forutsetningen for samling 5. Be studentene se den hjemme. Fra samling 2 bør alle se minst codebasics-videoen om stjerneskjema og én av SCD-videoene før laben.
