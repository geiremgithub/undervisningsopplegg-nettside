---
title: "Oversikt over emnet"
description: "Rammer, det gjennomgående caset Nordhandel AS, læringsmål, samlingsplan, vurdering og ressurser."
order: 1
---

# Datavarehus og dataintegrasjon – undervisningsopplegg

Komplett opplegg for et 6-ukers emne i datavarehus (data warehouse), dimensjonsmodellering, ETL/ELT, analytisk SQL, indeksering og spørringsoptimalisering.

Dokumentet er delt opp slik:

| Fil | Innhold |
|---|---|
| `00-oversikt.md` (denne) | Rammer, gjennomgående case, læringsmål, emnebeskrivelse, samlingsplan, vurdering, misforståelser, diskusjon, ressurser |
| `01-samling-1.md` … `06-samling-6.md` | Full detalj per samling: tidsplan, teori, demo-SQL linje for linje, oppgaver med fasit |
| `case/` | Oppsettskript for caset (kildesystem, staging, datavarehus, testdata) |

---

## 0. Antakelser

Punktene i oppgaven var markert med klammeparenteser, så jeg har gjort følgende antakelser. Alt kan justeres uten at opplegget endrer struktur.

| Ramme | Antakelse | Begrunnelse |
|---|---|---|
| Målgruppe | Årsstudenter / 2. år bachelor i informatikk eller IT-drift | Har hatt ett innføringsemne i databaser |
| Forkunnskaper | `SELECT`, `WHERE`, `JOIN` (inner/left), `GROUP BY`, enkel ER-modellering og normalisering til 3NF | Nødvendig for å gå rett på dimensjonsmodellering |
| Omfang | 6 samlinger à 3 timer (4 × 45 min med pauser), én samling per uke, pluss 4–6 timer eget arbeid per uke | Gir tid til både teori og lab i hver samling |
| Verktøy | **SQL Server 2022** (Developer Edition eller Docker-container) + **SQL Server Management Studio (SSMS)** eller **Azure Data Studio** | Gratis, har visuell execution plan, columnstore, Query Store. ETL gjøres i **T-SQL** (stored procedures) – ikke SSIS, fordi SSIS krever Windows og tar fokus fra prinsippene. Python/pandas vises som alternativ i samling 3 |
| Undervisningsform | 45–60 min forelesning med live-demo, deretter lab i grupper på 2–3 med oppgaver i tre nivåer | Studentene må skrive SQL selv for å lære dette |
| Vurdering | Mappe (3 innleveringer) 60 % + individuell digital quiz 40 % | Prosjekt-tung vurdering passer et praktisk emne |

Hvis du i stedet bruker PostgreSQL: alt i samling 1–4 fungerer med små syntaksendringer (`TOP` → `LIMIT`, `IDENTITY` → `GENERATED ALWAYS AS IDENTITY`, `MERGE` finnes fra PG 15). Samling 5–6 må tilpasses mer (PostgreSQL har ikke clustered index eller columnstore innebygd; bruk `EXPLAIN (ANALYZE, BUFFERS)` i stedet for grafisk plan).

---

## 1. Gjennomgående case: Nordhandel AS

Nordhandel er en norsk nettbutikk som selger friluftsutstyr. Caset følger studentene gjennom alle seks samlingene:

```
Samling 1   Samling 2       Samling 3        Samling 4        Samling 5-6
OLTP-kilde → Dimensjons-  → ETL inn i DW   → Rapporter     → Indeksering og
(Nordhandel   modell         (staging,        (vindus-         optimalisering
 Shop)        (stjerne-      SCD, feil-       funksjoner,      av rapportene
              skjema)        håndtering)      CTE-er)
```

### 1.1 Kildesystemet `NordhandelShop` (OLTP)

Et normalisert (3NF) ordresystem. Tabellene er med vilje litt «skitne»: inkonsistente postnumre, manglende kategorier, kunder som bytter adresse og produkter som bytter pris. Dette gir realistisk ETL-arbeid.

```sql
CREATE DATABASE NordhandelShop;
GO
USE NordhandelShop;
GO

CREATE TABLE Kunde (
    KundeId        INT IDENTITY PRIMARY KEY,
    Epost          NVARCHAR(200) NOT NULL UNIQUE,
    Fornavn        NVARCHAR(100) NOT NULL,
    Etternavn      NVARCHAR(100) NOT NULL,
    Postnummer     NVARCHAR(10)  NULL,          -- NULL og feil format forekommer
    Poststed       NVARCHAR(100) NULL,
    Kundesegment   NVARCHAR(20)  NULL,          -- 'Privat', 'Bedrift', NULL
    Opprettet      DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    SistEndret     DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Kategori (
    KategoriId     INT IDENTITY PRIMARY KEY,
    Navn           NVARCHAR(100) NOT NULL,
    ForelderId     INT NULL REFERENCES Kategori(KategoriId)   -- hierarki: Klær > Jakker > Skalljakker
);

CREATE TABLE Produkt (
    ProduktId      INT IDENTITY PRIMARY KEY,
    Varenummer     NVARCHAR(20)  NOT NULL UNIQUE,
    Navn           NVARCHAR(200) NOT NULL,
    KategoriId     INT NULL REFERENCES Kategori(KategoriId),  -- NULL forekommer
    Merke          NVARCHAR(100) NULL,
    Innkjopspris   DECIMAL(10,2) NOT NULL,
    Salgspris      DECIMAL(10,2) NOT NULL,       -- endres over tid, historikk finnes IKKE i kilden
    Aktiv          BIT NOT NULL DEFAULT 1,
    SistEndret     DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Ordre (
    OrdreId        INT IDENTITY PRIMARY KEY,
    KundeId        INT NOT NULL REFERENCES Kunde(KundeId),
    Ordredato      DATETIME2 NOT NULL,
    Status         NVARCHAR(20) NOT NULL,        -- 'Ny','Betalt','Sendt','Levert','Kansellert','Returnert'
    Betalingsmate  NVARCHAR(20) NULL,            -- 'Kort','Vipps','Faktura', NULL
    Kanal          NVARCHAR(20) NOT NULL,        -- 'Web','App','Butikk'
    Fraktkostnad   DECIMAL(10,2) NOT NULL DEFAULT 0,
    SistEndret     DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Ordrelinje (
    OrdrelinjeId   INT IDENTITY PRIMARY KEY,
    OrdreId        INT NOT NULL REFERENCES Ordre(OrdreId),
    ProduktId      INT NOT NULL REFERENCES Produkt(ProduktId),
    Antall         INT NOT NULL,
    EnhetsprisEksMva DECIMAL(10,2) NOT NULL,     -- prisen på salgstidspunktet
    RabattProsent  DECIMAL(5,2) NOT NULL DEFAULT 0
);
```

Testdata genereres med skriptet `case/01-oltp-testdata.sql` (ca. 5 000 kunder, 800 produkter, 200 000 ordrer, 600 000 ordrelinjer over 3 år). Volumet er stort nok til at indekser og planer gir målbare forskjeller i samling 5–6, men lite nok til å kjøre på en laptop.

### 1.2 Målet: `NordhandelDW` (datavarehus)

Et stjerneskjema som bygges gradvis:

```
                 DimDato
                    |
DimKunde ------ FaktSalg ------ DimProdukt
(SCD type 2)        |            (SCD type 2 på pris, type 1 på navn)
                    |
              DimOrdreinfo (junk dimension: Status, Betalingsmåte, Kanal)
```

Korn (grain) for `FaktSalg`: **én rad per ordrelinje**. Dette velges eksplisitt i samling 2 og diskuteres mot alternativene (én rad per ordre, én rad per produkt per dag).

### 1.3 Rapportene som skal kunne besvares

Disse brukes som rød tråd og som akseptansekriterier for datavarehuset:

1. Omsetning og dekningsbidrag per måned per kategori (med hierarki)
2. Topp 10 produkter per kvartal, og hvordan rangeringen endrer seg
3. Kundeomsetning år-over-år med vekstprosent (vindusfunksjoner)
4. Kunder som har flyttet mellom fylker – omsetning før og etter flytting (krever SCD type 2)
5. Rullerende 30-dagers omsetning per kanal
6. Returandel per merke per kvartal

---

## 2. Læringsmål

### 2.1 For hele emnet

Etter emnet skal studenten kunne:

**Kunnskap**
- K1. Forklare forskjellen på transaksjonssystemer (OLTP) og analysesystemer (OLAP), og begrunne hvorfor de modelleres ulikt
- K2. Beskrive typiske datavarehusarkitekturer (staging, kjerne/integrasjonslag, data mart) og plassere data lake, lakehouse og data warehouse i forhold til hverandre
- K3. Forklare prinsippene i dimensjonsmodellering: korn, fakta, dimensjoner, surrogatnøkler, konformerte dimensjoner og Slowly Changing Dimensions
- K4. Forklare hvordan en SQL-spørring utføres (execution plan), hva statistikk er, og hvordan indekser påvirker lese- og skrivekostnad

**Ferdigheter**
- F1. Modellere et stjerneskjema fra et normalisert kildesystem, med begrunnet valg av korn
- F2. Implementere ETL-flyt i SQL med staging, datakvalitetskontroll, SCD type 1 og 2, inkrementell lasting, logging og feilhåndtering
- F3. Skrive analytiske SQL-spørringer med vindusfunksjoner, CTE-er og subspørringer som besvarer realistiske rapportbehov
- F4. Lese en execution plan, identifisere flaskehalser, og forbedre ytelse med indekser (rowstore og columnstore), partisjonering og omskriving av spørringer
- F5. Måle og dokumentere effekten av en optimalisering (før/etter)

**Generell kompetanse**
- G1. Vurdere avveininger (trade-offs) mellom lesehastighet, skrivehastighet, lagringsplass, kompleksitet og vedlikehold
- G2. Kommunisere datamodeller og ytelsesanalyser skriftlig til både utviklere og forretningsbrukere

### 2.2 Per samling

| Samling | Tema | Studenten skal kunne … |
|---|---|---|
| **1** | Datavarehus: formål og arkitektur | (a) Forklare minst fire konkrete grunner til at man ikke rapporterer rett fra OLTP-databasen. (b) Tegne en trelags DW-arkitektur og forklare hva hvert lag gjør. (c) Plassere data lake, data warehouse og data mart i en arkitekturskisse og gi ett eksempel på når hver er riktig valg. (d) Analysere et gitt kildeskjema og identifisere hvilke tabeller som er kandidater til fakta og dimensjoner. |
| **2** | Dimensjonsmodellering | (a) Velge og begrunne korn for en faktatabell. (b) Modellere stjerneskjema og snøfnuggskjema for samme case og sammenligne dem. (c) Forklare hvorfor surrogatnøkler brukes i stedet for forretningsnøkler. (d) Implementere SCD type 1, 2 og 3 i DDL og forklare når hver brukes. (e) Bygge en datodimensjon. |
| **3** | ETL og ELT | (a) Forklare forskjellen på ETL og ELT og når hver passer. (b) Implementere en staging-basert lasting med `MERGE`/`INSERT … WHERE NOT EXISTS`. (c) Implementere inkrementell lasting med vannmerke (watermark) og begrunne når full lasting er bedre. (d) Validere datakvalitet (nullverdier, dubletter, referanseintegritet, format) og rute feilrader til en karantenetabell. (e) Logge kjøringer med radantall og varighet, og bruke `TRY…CATCH` og transaksjoner korrekt. |
| **4** | SQL for analyse | (a) Skrive spørringer med `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `SUM() OVER` med rammer (frames). (b) Bruke CTE-er for lesbarhet og rekursive CTE-er for hierarkier. (c) Avgjøre når en subspørring, CTE, `JOIN` eller vindusfunksjon er mest egnet. (d) Oversette et rapportbehov i prosa til korrekt SQL mot stjerneskjemaet, inkludert riktig håndtering av SCD type 2. |
| **5** | Indeksering | (a) Forklare B-tre-struktur og forskjellen på clustered og nonclustered index. (b) Lage covering index med `INCLUDE` og begrunne kolonnerekkefølge i komposittindekser. (c) Forklare når columnstore er bedre enn rowstore og demonstrere forskjellen. (d) Kvantifisere kostnaden ved indekser (skrivetid, plass, vedlikehold) med måling. |
| **6** | Spørringsoptimalisering | (a) Lese en grafisk execution plan: operatorer, estimert vs. faktisk radantall, varsler. (b) Forklare hva statistikk er, hvorfor den blir utdatert og hvordan det påvirker planen. (c) Identifisere og rette minst fem vanlige ytelsesfeil (SARGability, implisitt konvertering, `SELECT *`, funksjoner på kolonner i `WHERE`, feil `JOIN`-type). (d) Partisjonere en faktatabell og vise partition elimination i planen. |

---

## 3. Utfyllende emnebeskrivelse

Dette er «lærerens manus» – stoffet forklart i den rekkefølgen og med de begrunnelsene som fungerer best i undervisning. Detaljert SQL finnes i samlingsfilene.

### 3.1 Datavarehus: hvorfor finnes de?

**Start med problemet, ikke løsningen.** Be studentene tenke seg at de er analytikere i Nordhandel og skal lage en månedsrapport over omsetning per kategori. De har bare lesetilgang til `NordhandelShop`. Hva går galt?

1. **Ytelse og konflikt.** Rapportspørringen leser 600 000 ordrelinjer med fire joins mens butikken tar imot ordrer. Hver rapport konkurrerer om CPU, I/O og låser med kassesystemet. I verste fall får kundene «vent litt» i kassen fordi noen kjører en årsrapport.
2. **Historikk mangler.** `Produkt.Salgspris` er dagens pris. Hva var prisen i mars i fjor? Kilden vet ikke. Kundens postnummer er dagens postnummer – flyttet kunden, er all omsetning nå «flyttet med». OLTP-systemer er laget for å vite *hva som er sant nå*; analyse trenger å vite *hva som var sant da*.
3. **Kompleksitet.** For å få kategori-hierarkiet må man joine `Kategori` rekursivt med seg selv. Forretningsbrukere i Power BI klarer ikke dette. Modellen er optimalisert for å skrive én ordre raskt og konsistent, ikke for å lese millioner av ordrer på en forståelig måte.
4. **Flere kilder.** I virkeligheten kommer kundedata også fra CRM, lagerdata fra WMS, markedsføringsdata fra et annet system. Ingen av dem deler nøkler eller definisjoner («kunde» betyr noe ulikt i hvert system). Noen må integrere.
5. **Definisjonskaos.** Hva er «omsetning»? Med eller uten frakt? Med eller uten mva? Inkludert kansellerte ordrer? Uten ett felles sted der dette er bestemt, får hver avdeling sitt eget tall.

Et datavarehus løser alle fem: det er en **separat database, lastet periodisk, modellert for lesing, med historikk og én definisjon av hvert begrep**. Inmons klassiske definisjon er fortsatt nyttig: *subject-oriented, integrated, time-variant, non-volatile*. Gå gjennom hvert ord og koble det til problemene over.

**OLTP vs. OLAP** – sett det opp i en tabell på tavla og la studentene fylle ut:

| | OLTP (Online Transaction Processing) | OLAP (Online Analytical Processing) |
|---|---|---|
| Formål | Drive virksomheten | Forstå virksomheten |
| Typisk operasjon | `INSERT`/`UPDATE` av få rader, `SELECT` på nøkkel | `SELECT` med aggregering over millioner rader |
| Modell | Normalisert (3NF), mange smale tabeller | Denormalisert (stjerne), få brede tabeller |
| Brukere | Mange samtidige, korte transaksjoner | Få, lange spørringer |
| Historikk | Nåtilstand | Fullstendig historikk |
| Optimalisert for | Skriving, konsistens, låsing | Lesing, skanning, komprimering |
| Datavolum per spørring | KB | GB |

**Arkitektur.** Tegn det klassiske trelagsbildet og forklar *hvorfor* hvert lag finnes:

```
Kilder            Staging              Kjerne / DW             Presentasjon
──────            ───────              ───────────             ────────────
NordhandelShop ─┐                   ┌─ DimKunde ─┐
CRM            ─┼─► stg.Kunde   ───►│  DimProdukt │──► Data mart "Salg"  ──► Power BI
WMS            ─┤   stg.Ordre       │  DimDato    │    (views / aggregater)   Excel
Excel-filer    ─┘   stg.Ordrelinje  └─ FaktSalg ──┘                           Python
                    (rå kopi,        (renset, integrert,
                     1:1 med kilde)   historisert)
```

- **Staging** er en rå kopi. Poenget er å *frikoble* uttrekk fra transformasjon: hvis transformasjonen feiler, trenger man ikke lese fra kilden på nytt. Det gjør også feilsøking mulig («hva så dataene ut som da de kom inn?»).
- **Kjernen** er der integrasjon og historikk skjer. Her er dimensjonsmodellen (Kimball) eller en normalisert modell (Inmon / Data Vault). Vi bruker Kimball fordi det er enklest å lære og mest utbredt i mellomstore virksomheter.
- **Data mart** er en avgrenset utsikt for ett forretningsområde (salg, lager, økonomi). I praksis ofte bare et sett views eller en egen schema. Poenget med *konformerte dimensjoner* (conformed dimensions) er at alle marts deler samme `DimKunde` og `DimDato`, slik at tall kan sammenlignes på tvers.

**Data lake vs. data warehouse.** Studentene har hørt begge begrepene og tror ofte at data lake er «det nye datavarehuset». Avklar:

| | Data warehouse | Data lake | Lakehouse |
|---|---|---|---|
| Lagrer | Strukturerte, modellerte data | Alt: filer, logger, bilder, JSON, CSV | Filer i åpent format (Parquet/Delta) med tabell-lag oppå |
| Skjema | Ved skriving (schema-on-write) | Ved lesing (schema-on-read) | Begge |
| Brukere | Analytikere, rapportering | Data scientists, ingeniører | Begge |
| Styrke | Kvalitet, ytelse, ett sannhetssett | Billig, fleksibelt, rådata bevart | Kombinerer |
| Svakhet | Dyrt, tregt å endre | «Data swamp» uten styring | Nyere, mer kompleks |

Konklusjon for studentene: det er ikke enten/eller. Vanlig i dag: rådata lander i en lake (Azure Data Lake, S3), kuraterte data modelleres som stjerneskjema – enten i et DW (Synapse, Snowflake, SQL Server) eller som Delta-tabeller i et lakehouse (Databricks, Fabric). **Dimensjonsmodellering er like relevant uansett lagringsteknologi.**

### 3.2 Dimensjonsmodellering

**Grunnidéen** (Kimball): forretningsbrukere stiller spørsmål på formen «*hvor mye* [måltall] per [noe] per [noe annet]». *Hvor mye* er et **faktum** (fact, measure): omsetning, antall, kostnad. *Per noe* er en **dimensjon**: tid, kunde, produkt, sted. Modellen gjenspeiler setningsstrukturen direkte:

```
Omsetning  per  måned   per  kategori  per  kundesegment
   │             │             │              │
FaktSalg     DimDato     DimProdukt       DimKunde
```

**Korn (grain)** er den viktigste beslutningen i hele modellen, og den studentene oftest hopper over. Korn = «hva representerer én rad i faktatabellen?». For Nordhandel:

- *Én rad per ordrelinje*: finest mulig korn. Kan svare på alt. Flest rader.
- *Én rad per ordre*: mister produktinformasjon. Kan ikke lage topp-10-produkter.
- *Én rad per produkt per dag*: aggregat. Rask, men kan ikke svare på kundenivå.

Regel: **velg det fineste kornet kilden tillater**. Aggregater kan alltid lages senere; detaljer kan aldri gjenskapes. Kornet bestemmer hvilke dimensjoner som gir mening – en «ordrelinje» har én kunde, ett produkt, én dato. Faktum som ikke matcher kornet (f.eks. fraktkostnad, som er per ordre) må enten fordeles (allokeres) ned til linjene eller legges i en egen faktatabell. Dette er en gullgruve for diskusjon.

**Stjerne vs. snøfnugg.** I et **stjerneskjema (star schema)** er hver dimensjon én flat, denormalisert tabell: `DimProdukt` har kolonnene `Kategori`, `Underkategori`, `Hovedkategori` side om side, selv om det er redundant. I et **snøfnuggskjema (snowflake schema)** normaliseres dimensjonene: `DimProdukt → DimUnderkategori → DimKategori`.

Studentene har nettopp lært normalisering og synes snøfnugg er «riktigere». Argumentet for stjerne:
- Færre joins → enklere SQL og raskere spørringer
- Forretningsbrukere forstår en flat tabell
- Redundansen er ufarlig: dimensjoner er små (800 produkter) og lastes kontrollert av ETL, så oppdateringsanomalier oppstår ikke
- Lagringskostnaden ved redundans i en dimensjon er ubetydelig sammenlignet med faktatabellen

Snøfnugg brukes når en dimensjon er enorm, eller når et subhierarki deles av flere dimensjoner (f.eks. geografi brukt av både kunde og butikk). I praksis: **start med stjerne, snøfnugg bare med en konkret grunn.**

**Surrogatnøkler (surrogate keys).** Hvorfor ikke bare bruke `KundeId` fra kilden som nøkkel i `DimKunde`?
1. **Historikk**: Med SCD type 2 skal samme kunde ha flere rader (én per adresseperiode). `KundeId` kan ikke være primærnøkkel da.
2. **Flere kilder**: CRM og nettbutikk har ulike `KundeId`. Surrogatnøkkelen er DW-ens egen identitet.
3. **Ytelse**: Et `INT` er raskere å joine og tar mindre plass i faktatabellen enn `NVARCHAR(200)`-e-post. Med 600 000 faktrader × 4 dimensjoner betyr dette noe.
4. **Isolasjon**: Hvis kilden endrer nøkkelformat (fra INT til GUID), berøres bare dimensjonen.

Konvensjon: `KundeKey INT IDENTITY` er surrogatnøkkel, `KundeId` fra kilden beholdes som **forretningsnøkkel (business/natural key)** i dimensjonen. Faktatabellen inneholder bare surrogatnøkler.

**Slowly Changing Dimensions (SCD).** Dimensjonsattributter endrer seg: kunden flytter, produktet får ny pris, kategorien omdøpes. Spørsmålet er: skal historisk omsetning følge den *gamle* eller *nye* verdien?

| Type | Teknikk | Historikk | Brukes når |
|---|---|---|---|
| **Type 0** | Aldri oppdater | Original beholdes | Fødselsdato, opprinnelig segment |
| **Type 1** | Overskriv | Ingen – alt ser ut som nå | Stavefeil, navn på produkt, ting der historikk ikke gir mening |
| **Type 2** | Ny rad med `GyldigFra`/`GyldigTil`/`ErGjeldende` | Full – fakta peker på riktig versjon | Kundens adresse, produktets pris, selgerens avdeling |
| **Type 3** | Ekstra kolonne `ForrigeVerdi` | Én generasjon | Omorganisering der man vil sammenligne «gammel og ny struktur» |

Type 2 er den som må øves grundig: ETL-en må (a) oppdage endringen, (b) sette `GyldigTil` og `ErGjeldende = 0` på gammel rad, (c) sette inn ny rad med ny surrogatnøkkel, og (d) sørge for at nye fakta kobles til den *gjeldende* versjonen, mens gamle fakta fortsatt peker på gammel. Spørringer som skal vise «kundens nåværende fylke» må da filtrere `ErGjeldende = 1`, mens «fylke på salgstidspunktet» bruker nøkkelen i faktaraden direkte. Dette gir rapport 4 i caset.

**Andre mønstre som bør nevnes** (korte innslag, ikke egne øvelser): datodimensjon (alltid egen tabell, aldri bare en `DATE`-kolonne – fordi helligdager, regnskapsuker og «er helg» ikke kan beregnes enkelt); junk dimension (små flagg og statuser samlet i én dimensjon for å slippe fem bittesmå dimensjonstabeller); degenerert dimensjon (ordrenummer ligger i faktatabellen uten egen dimensjonstabell); role-playing dimension (`DimDato` brukt som både ordredato og leveringsdato); «ukjent»-rad med nøkkel `-1` eller `0` i hver dimensjon så fakta aldri får `NULL`-nøkkel.

### 3.3 ETL og ELT

**ETL (Extract, Transform, Load)**: data hentes ut, transformeres i et eget verktøy (SSIS, Informatica, Python), og lastes ferdig inn i DW. **ELT (Extract, Load, Transform)**: data lastes rått inn i målplattformen og transformeres der med SQL. ELT har vunnet frem fordi moderne databaser (Snowflake, BigQuery, Synapse, Databricks) har mer regnekraft enn ETL-serverne, og fordi SQL er enklere å versjonere og teste enn grafiske ETL-pakker (jf. dbt). I dette emnet gjør vi **ELT i T-SQL**: det er plattformnøytralt i prinsipp og lar studentene se hvert steg som SQL.

**Stegene i en lasting** – vis alltid denne rekkefølgen, og diskuter hvorfor:

```
1. Start logg         ─ skriv rad i etl.Kjoring (starttid, jobbnavn)
2. Extract            ─ kopier endrede kilderader til stg.* (TRUNCATE + INSERT, eller inkrementelt)
3. Valider            ─ sjekk nullverdier, dubletter, referanser; rute feil til etl.Karantene
4. Last dimensjoner   ─ ALLTID før fakta (fakta trenger nøklene). SCD-logikk her.
5. Last fakta         ─ slå opp surrogatnøkler, bruk -1 for ukjent, INSERT nye rader
6. Oppdater vannmerke ─ lagre «siste SistEndret jeg har sett»
7. Avslutt logg       ─ radantall, varighet, status OK/FEIL
```

**Full lasting vs. inkrementell lasting.** Full lasting (`TRUNCATE` + last alt) er enkel, idempotent og alltid korrekt, men skalerer ikke: 600 000 rader går fint, 600 millioner gjør ikke det. Inkrementell lasting henter bare rader der `SistEndret > @Vannmerke`. Det krever (a) at kilden har en pålitelig endringskolonne, (b) at slettinger håndteres (soft delete, eller sammenligning av nøkkelmengder), og (c) at man håndterer «sene» rader som endres mens lastingen pågår (bruk vannmerke = starttidspunkt for lastingen, ikke `MAX(SistEndret)`). Pedagogisk poeng: **start alltid med full lasting, gjør det inkrementelt når det blir nødvendig, og behold muligheten til full relasting.**

**Datakvalitet.** Kategoriser feil og vis at hver type krever ulik håndtering:

| Feiltype | Eksempel i Nordhandel | Håndtering |
|---|---|---|
| Manglende verdi | `Kunde.Postnummer IS NULL` | Erstatt med «Ukjent», ikke `NULL`, i dimensjonen |
| Ugyldig format | Postnummer `'O5O1'` (bokstav O) | Rute til karantene, eller korriger med regel hvis entydig |
| Brutt referanse | `Produkt.KategoriId` peker på slettet kategori | Koble til «Ukjent kategori» (nøkkel -1), logg antall |
| Dublett | To kunder med samme e-post i ulik case | Normaliser (`LOWER`, `TRIM`) før matching; velg nyeste |
| Logisk feil | `Antall <= 0`, `Ordredato` i fremtiden | Karantene – dette er sannsynligvis feil i kilden og må meldes |
| Inkonsistens | `Status = 'Levert'` men ingen sendt-dato | Last, men flagg i `DimOrdreinfo` som «inkonsistent» |

Prinsippet er **aldri stopp hele lastingen for én dårlig rad, og aldri la en dårlig rad forsvinne i stillhet**. Karantenetabellen (`etl.Karantene`) med kilde, rad-ID, regel og tidspunkt gjør begge deler mulig.

**Feilhåndtering og transaksjoner.** Last dimensjoner og fakta i én transaksjon slik at DW aldri er i halvlastet tilstand. Bruk `BEGIN TRY … BEGIN CATCH` med `ROLLBACK`, logg `ERROR_MESSAGE()` til `etl.Kjoring` og `THROW` videre så jobbplanleggeren ser feilen. Vis også **idempotens**: samme jobb kjørt to ganger skal gi samme resultat (bruk `MERGE` eller `WHERE NOT EXISTS`, aldri ren `INSERT`).

**Logging og overvåkning.** Minimum per kjøring: starttid, sluttid, status, rader lest/innsatt/oppdatert/karantenert. Dette muliggjør de tre viktigste spørsmålene i drift: *Kjørte den? Hvor lang tid tok den? Er radantallet som forventet?* Vis en enkel spørring som flagger kjøringer med radantall mer enn 50 % unna 7-dagers snitt – det fanger de fleste kildefeil før brukerne gjør det.

### 3.4 SQL for analyse

Studentene kan `JOIN` og `GROUP BY`. Det som er nytt, og som gjør analytisk SQL kraftig, er **vindusfunksjoner (window functions)**. Forklar grunnidéen: `GROUP BY` kollapser rader til grupper; `OVER()` beregner over grupper men *beholder* radene. Det løser klassiske problemer som «vis hver ordre sammen med kundens totale omsetning» uten subspørring.

Undervis i denne rekkefølgen:

1. **`OVER()` uten partisjon**: `SUM(Belop) OVER ()` = totalsum på hver rad → andel av total.
2. **`PARTITION BY`**: `SUM(Belop) OVER (PARTITION BY KundeKey)` = kundens total på hver rad.
3. **`ORDER BY` i vinduet → løpende sum**: `SUM(Belop) OVER (PARTITION BY KundeKey ORDER BY DatoKey)`. Her må man forklare **standard ramme** (`RANGE UNBOUNDED PRECEDING`) og hvorfor den kan gi uventede resultater ved like `ORDER BY`-verdier – bruk `ROWS` eksplisitt.
4. **Rangering**: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE` – og forskjellen ved like verdier.
5. **Forskyvning**: `LAG`/`LEAD` for «forrige måned», «vekst fra i fjor».
6. **Rammer (frames)**: `ROWS BETWEEN 29 PRECEDING AND CURRENT ROW` for rullerende 30 dager (men vis fellen: det er 30 *rader*, ikke 30 *dager*, hvis det finnes dager uten salg – løsning: joine mot `DimDato` først).

**CTE-er (Common Table Expressions)** undervises som verktøy for lesbarhet: bryt en kompleks rapport i navngitte steg (`WITH Maanedssalg AS (…), MedForrige AS (…) SELECT …`). Påpek at CTE-er i SQL Server er *ikke* materialisert – de er inlinet, så de påvirker ikke ytelse i seg selv (relevant for samling 6). **Rekursive CTE-er** brukes til kategorihierarkiet.

**Subspørringer** finnes fortsatt i tre former: skalar (`SELECT (SELECT MAX…)`), i `WHERE` (`IN`, `EXISTS`) og som avledet tabell. Lær studentene å velge: `EXISTS` for «finnes det», vindusfunksjon for «sammenlign med gruppen», CTE for «flere steg», `JOIN` for «kombinér».

**Rapportspørringer mot stjerneskjema** har et fast mønster studentene skal gjenkjenne:

```sql
SELECT  d.Aar, d.Maaned, p.Hovedkategori,          -- dimensjonsattributter
        SUM(f.NettoBelop) AS Omsetning,            -- aggregerte fakta
        SUM(f.NettoBelop - f.Kostnad) AS Dekningsbidrag
FROM    dw.FaktSalg f
JOIN    dw.DimDato d    ON d.DatoKey = f.OrdreDatoKey
JOIN    dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
WHERE   d.Aar = 2025
GROUP BY d.Aar, d.Maaned, p.Hovedkategori;
```

Dette er alltid: fakta i midten, join til dimensjoner på surrogatnøkkel, filtrer og grupper på dimensjonsattributter, aggreger fakta. Poengter at dette er nøyaktig det Power BI genererer.

### 3.5 Indeksering

Begynn med den fysiske modellen – uten den blir indekser magi. En tabell er lagret i **8 KB-sider (pages)**. Å lese en tabell uten indeks er å lese alle sidene (**table scan**). En indeks er et **B-tre (B-tree)**: en sortert struktur som lar databasen hoppe til riktig side med 3–4 lesninger i stedet for tusenvis (**seek**).

**Clustered index** bestemmer den fysiske sorteringen av tabellen. Det kan bare være én; bladnivået *er* tabellen. Default settes den på primærnøkkelen, men det er et valg: for `FaktSalg` er en clustered index på `OrdreDatoKey` ofte bedre enn på `SalgKey`, fordi rapporter filtrerer på dato og da leser et sammenhengende område. **Nonclustered index** er en separat struktur med indeksnøkkelen + en peker (clustered key) til raden. Å følge pekeren kalles **key lookup** og koster én ekstra lesning per rad – dette er den vanligste årsaken til at en indeks «ikke blir brukt» ved mange treff (tipping point).

**Covering index** løser key lookup: inkluder alle kolonnene spørringen trenger, enten i nøkkelen eller med `INCLUDE (…)`. `INCLUDE`-kolonner ligger bare på bladnivå og koster derfor mindre enn nøkkelkolonner.

**Komposittindeks**: rekkefølgen på kolonnene er avgjørende. En indeks på `(KundeKey, OrdreDatoKey)` kan brukes til `WHERE KundeKey = 5` og `WHERE KundeKey = 5 AND OrdreDatoKey > …`, men *ikke* til `WHERE OrdreDatoKey > …` alene (telefonkatalog-analogien: sortert på etternavn, så fornavn – du finner ikke alle «Ola» uten å lese hele boka). Regel: likhetskolonner først, deretter ulikhets-/områdekolonne, mest selektive først blant likhetene.

**Columnstore index** lagrer data kolonnevis i komprimerte segmenter i stedet for radvis. For analytiske spørringer som leser få kolonner av mange rader (`SUM(NettoBelop)` over 600 000 rader) gir det typisk 10× mindre I/O og 10× bedre komprimering, pluss **batch mode**-utførelse. For punktoppslag og hyppige oppdateringer er rowstore bedre. For faktatabeller er **clustered columnstore** i dag standardvalget; demonstrer forskjellen med `SET STATISTICS IO ON` – tallene taler for seg.

**Kostnader ved indekser** – må måles, ikke bare nevnes:
- Hver `INSERT`/`UPDATE`/`DELETE` må vedlikeholde hver indeks. Vis at lasting av 100 000 rader tar X sekunder med 0 indekser og Y med 6.
- Plass: `sp_spaceused` viser at indeksene kan være større enn tabellen.
- Fragmentering og statistikkvedlikehold.
- Optimalisereren får flere valg og kan velge feil.

Konklusjon: **indekser er et bytte av skrivetid og plass mot lesetid**. I et DW, der lasting skjer én gang om natten og lesing hele dagen, er bytteforholdet gunstig – men det er fortsatt vanlig praksis å droppe nonclustered indekser før en stor lasting og gjenskape dem etterpå.

### 3.6 Spørringsoptimalisering

**Execution plan** er optimalisererens «oppskrift» på hvordan spørringen utføres. Lær studentene å lese den systematisk:

1. Les **fra høyre til venstre, topp til bunn** – data flyter mot `SELECT`-operatoren.
2. Finn **tykkeste pilene** – det er der flest rader flyter.
3. Se på **operatorene**: Scan (leser alt), Seek (hopper til), Nested Loops (bra for få rader), Hash Match (bra for mange), Sort (dyrt, trenger minne), Key Lookup (indeks dekker ikke).
4. Sammenlign **estimert og faktisk radantall** (actual plan). Stort avvik = statistikkproblem eller noe optimalisereren ikke kan estimere (funksjoner, variabler, tabellvariabler).
5. Se etter **varsler** (gult utropstegn): implisitt konvertering, spill til tempdb, manglende statistikk, manglende indeks (forslaget er en hint, ikke en fasit).

**Statistikk** er histogrammer over verdifordelingen i kolonner. Optimalisereren bruker dem til å gjette radantall, og gjetter den feil, velger den feil plan (f.eks. Nested Loops for 2 millioner rader). Vis det konkret: last 500 000 rader uten å oppdatere statistikk, kjør en spørring, se at estimatet er 1 rad og at planen er elendig; kjør `UPDATE STATISTICS`, se forskjellen. Auto-update finnes, men trigges først ved ~20 % endring (eller sqrt(1000 × rader) på nyere versjoner), så etter en inkrementell lasting bør ETL-jobben oppdatere statistikk eksplisitt.

**Vanlige ytelsesfeil** – hver vises som før/etter med plan:
1. **Ikke-SARGable predikater**: `WHERE YEAR(Ordredato) = 2025` kan ikke bruke indeks på `Ordredato`. Skriv om til `WHERE Ordredato >= '2025-01-01' AND Ordredato < '2026-01-01'`.
2. **Implisitt konvertering**: `WHERE Varenummer = 12345` der `Varenummer` er `NVARCHAR` → hele kolonnen konverteres, scan. Vis varselet i planen.
3. **`SELECT *`** hindrer covering index og drar med unødvendige kolonner i sort og hash.
4. **Funksjoner i `JOIN`-betingelser** og `OR` på tvers av tabeller.
5. **Feil tabelltype**: tabellvariabler estimeres til 1 rad; bruk temp-tabeller for mellomresultater over noen hundre rader.
6. **Parameter sniffing**: samme prosedyre, ulik parameter, feil plan gjenbrukt. Nevnes, demonstreres hvis tid.
7. **Manglende indeks på fremmednøkkel** i faktatabellen – alle dimensjons-joins blir scans.

**Partisjonering** deler en stor tabell i fysiske deler etter en kolonne (typisk dato). Fordelen er ikke primært spørringshastighet – det er **forvaltning**: man kan laste en ny måned som egen partisjon (`SWITCH IN` på sekunder), arkivere gamle år (`SWITCH OUT`), og bygge indekser per partisjon. Spørringer som filtrerer på partisjonskolonnen får **partition elimination** (leser bare relevante partisjoner), men spørringer som ikke filtrerer på den kan bli *tregere*. Demonstrer begge deler i planen.

---

## 4. Samlingsplan

Hver samling er 3 klokketimer: 4 bolker à 45 min, med 10 min pause mellom bolk 1–2 og 3–4 og 20 min pause i midten. Mønsteret er fast så studentene vet hva som kommer:

| Bolk | Innhold | Form |
|---|---|---|
| 1 (45 min) | Oppsummering av forrige lab (10 min), teori del 1 | Forelesning med spørsmål |
| 2 (45 min) | Teori del 2 med live-demo i SSMS | Forelesning + demo, studentene følger med på egen maskin |
| 3 (45 min) | Lab: grunnleggende og viderekommen oppgave | Grupper på 2–3, læreren går rundt |
| 4 (45 min) | Lab: utfordringsoppgave (10 min), felles gjennomgang av fasit og diskusjonsspørsmål (20 min), introduksjon til hjemmearbeid (5 min) | Gruppe → plenum |

### Samling 1 – Fra kildesystem til datavarehus: hvorfor og hvordan

| Tid | Aktivitet |
|---|---|
| 0:00–0:15 | Introduksjon til emnet, vurdering, verktøyoppsett (alle skal ha SQL Server + `NordhandelShop` kjørende før samlingen – sjekkliste sendt ut på forhånd) |
| 0:15–0:45 | Teori: problemet med å rapportere fra OLTP. Øvelse på tavla: «skriv månedsrapporten mot `NordhandelShop`» – la studentene prøve i 10 min, samle frustrasjonene |
| 0:45–0:55 | Pause |
| 0:55–1:20 | Teori: OLTP vs. OLAP, Inmons fire egenskaper, trelagsarkitektur |
| 1:20–1:40 | Demo: utforsk `NordhandelShop` – finn datakvalitetsproblemene med SQL (`GROUP BY` på postnummerlengde, `LEFT JOIN` for å finne produkter uten kategori, pris-«historikk» som ikke finnes) |
| 1:40–2:00 | Pause |
| 2:00–2:45 | Lab 1: (G) kartlegg kildeskjemaet og lag en kvalitetsrapport, (V) klassifiser hver tabell/kolonne som fakta-kandidat, dimensjons-kandidat eller ikke relevant, (U) skisser en arkitektur med staging, DW og mart for Nordhandel når de også får data fra et CRM-system |
| 2:45–3:00 | Plenum: sammenlign klassifiseringene. Diskusjon: data lake eller data warehouse for Nordhandel? Hjemmearbeid: les Kimball kap. 1–2, skriv én side om «hva er kornet i vår faktatabell og hvorfor» |

### Samling 2 – Dimensjonsmodellering

| Tid | Aktivitet |
|---|---|
| 0:00–0:10 | Oppsummering: studentenes forslag til korn, diskuter alternativene |
| 0:10–0:45 | Teori: fakta, dimensjoner, korn, stjerne vs. snøfnugg, surrogatnøkler |
| 0:45–0:55 | Pause |
| 0:55–1:25 | Teori: SCD type 0–3, datodimensjon, junk dimension, ukjent-rad |
| 1:25–1:40 | Demo: opprett `NordhandelDW` med `dw.DimDato` (generert med rekursiv CTE eller tally-tabell) og `dw.DimKunde` som SCD type 2 |
| 1:40–2:00 | Pause |
| 2:00–2:45 | Lab 2: (G) lag DDL for `DimProdukt` (type 1 på navn, type 2 på pris og kategori) og `FaktSalg` med riktig korn, (V) legg til `DimOrdreinfo` som junk dimension og modeller fraktkostnad, (U) modellér «retur» – egen faktatabell eller negativ rad i `FaktSalg`? Begrunn |
| 2:45–3:00 | Plenum: sammenlign modeller. Diskusjon: «hvilke attributter i `DimKunde` bør være type 1 og hvilke type 2 – og hvem bestemmer det?» |

### Samling 3 – ETL og ELT

| Tid | Aktivitet |
|---|---|
| 0:00–0:10 | Oppsummering: ferdig DDL deles ut så alle har samme utgangspunkt |
| 0:10–0:45 | Teori: ETL vs. ELT, lastesekvens, staging, full vs. inkrementell, vannmerke |
| 0:45–0:55 | Pause |
| 0:55–1:40 | Demo (lang): bygg `etl.LastKunde` steg for steg – staging, validering til karantene, SCD type 2 med `MERGE`, logging, `TRY…CATCH`. Kjør den to ganger for å vise idempotens. Endre en kundes postnummer i kilden, kjør igjen, vis de to radene |
| 1:40–2:00 | Pause |
| 2:00–2:45 | Lab 3: (G) skriv `etl.LastProdukt` etter samme mønster, (V) skriv `etl.LastFaktSalg` med oppslag av surrogatnøkler og -1 for ukjent, inkrementelt med vannmerke, (U) implementer sletting i kilden (kansellert ordre som forsvinner) og en avviksrapport på radantall |
| 2:45–3:00 | Plenum: hvilke datakvalitetsfeil fant dere, og hva gjorde dere med dem? Kort innslag: samme lasting i Python/pandas (10 linjer) – hva er likt, hva er annerledes? |

### Samling 4 – SQL for analyse

| Tid | Aktivitet |
|---|---|
| 0:00–0:10 | Oppsummering: alle laster fullt DW fra ferdig skript, så alle har samme data |
| 0:10–0:45 | Teori + demo: vindusfunksjoner trinn for trinn (`OVER()`, `PARTITION BY`, `ORDER BY`, rammer) med omsetning per kunde |
| 0:45–0:55 | Pause |
| 0:55–1:25 | Teori + demo: rangering, `LAG`/`LEAD`, CTE-er, rekursiv CTE på kategorihierarkiet |
| 1:25–1:40 | Demo: rapport 4 (kunder som flyttet) – hvordan SCD type 2 brukes riktig og galt i spørringer |
| 1:40–2:00 | Pause |
| 2:00–2:45 | Lab 4: (G) rapport 1 og 2, (V) rapport 3 og 5 (inkl. fellen med manglende dager), (U) rapport 6 pluss «kohortanalyse: omsetning per kundens første-kjøps-måned» |
| 2:45–3:00 | Plenum: gjennomgang av én løsning per rapport. Diskusjon: «når er en vindusfunksjon feil verktøy?» |

### Samling 5 – Indeksering

| Tid | Aktivitet |
|---|---|
| 0:00–0:10 | Oppsummering. Alle slår på `SET STATISTICS IO, TIME ON` og «Include Actual Execution Plan» |
| 0:10–0:45 | Teori: sider, B-trær, clustered vs. nonclustered, seek vs. scan, key lookup |
| 0:45–0:55 | Pause |
| 0:55–1:25 | Demo: samme spørring mot `FaktSalg` med heap, clustered på `SalgKey`, clustered på `OrdreDatoKey`, nonclustered med key lookup, covering index. Logiske lesninger på tavla etter hvert steg |
| 1:25–1:40 | Teori + demo: columnstore. Konverter `FaktSalg` til clustered columnstore, kjør rapport 1 – sammenlign I/O og tid |
| 1:40–2:00 | Pause |
| 2:00–2:45 | Lab 5: (G) finn riktig indeks for tre gitte spørringer, mål før/etter, (V) komposittindeks – test kolonnerekkefølge, (U) mål lastetid for 100 000 rader med 0, 3 og 6 indekser og lag en anbefaling for Nordhandels nattlasting |
| 2:45–3:00 | Plenum: diskusjon «når bør man *ikke* lage en indeks?» |

### Samling 6 – Spørringsoptimalisering

| Tid | Aktivitet |
|---|---|
| 0:00–0:10 | Oppsummering |
| 0:10–0:45 | Teori + demo: lese execution plan systematisk. Statistikk-demo (utdatert statistikk → feil plan) |
| 0:45–0:55 | Pause |
| 0:55–1:40 | Demo: syv vanlige feil, hver som før/etter med plan og I/O |
| 1:40–2:00 | Pause |
| 2:00–2:30 | Demo + lab: partisjoner `FaktSalg` på år, vis partition elimination, `SWITCH` inn en ny måned |
| 2:30–2:50 | Lab 6: «optimaliseringsjakten» – åtte bevisst dårlige rapportspørringer, finn og fiks feilene, dokumenter før/etter |
| 2:50–3:00 | Avslutning: oppsummering av emnet, gjennomgang av mappeinnlevering 3 og quiz |

---

## 5. Vurdering

### 5.1 Mappe (60 %)

Tre innleveringer som til sammen utgjør et komplett datavarehus for Nordhandel. Gruppearbeid (2–3), men med individuelt refleksjonsnotat.

| Innlevering | Leveres etter | Innhold | Vekt |
|---|---|---|---|
| **M1: Modell** | Samling 2 | DDL for komplett stjerneskjema med begrunnelse for korn, SCD-valg per attributt og håndtering av frakt og retur. Maks 3 sider + SQL | 15 % |
| **M2: ETL** | Samling 4 | Fungerende lasteprosedyrer med staging, validering, karantene, SCD type 2, inkrementell lasting, logging. Testdokumentasjon: «vi endret X i kilden og fikk Y i DW». Pluss SQL for alle seks rapportene | 25 % |
| **M3: Ytelse** | Samling 6 | Ytelsesrapport: for minst fire rapportspørringer, dokumenter plan og I/O før/etter, hvilke indekser som ble lagt til og hvorfor, og én optimalisering som ble *forkastet* med begrunnelse. Måling av lastetid med/uten indekser | 20 % |

**Vurderingskriterier (brukes for alle tre):**

| Kriterium | Ikke bestått | Bestått | Godt | Fremragende |
|---|---|---|---|---|
| **Korrekthet** | Kjører ikke / gir feil tall | Kjører, tallene stemmer for hovedtilfellet | Håndterer kanttilfeller (NULL, ukjent, dubletter) | Håndterer også sletting, sene rader og re-kjøring |
| **Begrunnelse** | Ingen eller gale begrunnelser | Beskriver hva som er gjort | Forklarer hvorfor, med referanse til teori | Drøfter alternativer og avveininger med måling |
| **Håndverk** | Uleselig SQL, ingen struktur | Konsistent navngiving, kommentarer | Idempotent, logget, transaksjonssikker | Testbart, modulært, kunne gått i produksjon |
| **Kommunikasjon** | Ingen dokumentasjon | Beskriver løsningen | Forståelig for en ny utvikler | Forståelig for en forretningsbruker også |

### 5.2 Individuell digital quiz (40 %)

60 minutter, 30 spørsmål, flervalg og kortsvar, åpen bok men uten database. Fordeling: 5 spørsmål per samling. Eksempler på nivå:

- *Kunnskap:* «Hvilken SCD-type bør brukes for kundens fødselsdato? Begrunn med én setning.»
- *Anvendelse:* Gitt et skjermbilde av en execution plan: «Hvilken operator bør du se nærmere på først, og hva vil du sjekke?»
- *Analyse:* Gitt en spørring med `WHERE CAST(Ordredato AS DATE) = '2025-03-01'` og en indeks på `Ordredato`: «Blir indeksen brukt til seek? Skriv om spørringen.»
- *Vurdering:* «En kollega foreslår å snøfnugge `DimProdukt` fordi kategorinavn er redundante. Gi ett argument for og to mot.»

En full quiz med 30 spørsmål og fasit ligger i `07-quiz.md` (skrives sammen med samling 6).

---

## 6. Vanlige misforståelser og feil

Organisert per tema, med hvordan læreren oppdager det og hva som hjelper.

### Datavarehus og arkitektur
| Misforståelse | Hvordan den viser seg | Hva som hjelper |
|---|---|---|
| «Et datavarehus er bare en kopi av produksjonsdatabasen» | Studenten foreslår replikering/backup som løsning | Vis pris-historikk-problemet: kopien har heller ikke historikk |
| «Data lake erstatter datavarehus» | Arkitekturskisser uten modellering | Spør: «hvordan vet Power BI-brukeren hva omsetning er i en Parquet-fil?» |
| «Staging er unødvendig, vi kan transformere direkte fra kilden» | ETL-skript som leser kilden flere ganger | La dem oppleve en feil midtveis i lastingen |

### Dimensjonsmodellering
| Misforståelse | Hvordan den viser seg | Hva som hjelper |
|---|---|---|
| Hopper over kornbeslutningen | Faktatabell med både ordre- og linjenivå-kolonner; fraktkostnad summeres per linje | Still alltid «hva er én rad?» før de får vise DDL |
| «Normalisering er alltid riktig» | Snøfnugg overalt | Tell joins i rapport 1 i begge modeller |
| Bruker forretningsnøkkel som primærnøkkel i SCD2-dimensjon | `PRIMARY KEY (KundeId)` – feiler ved første type 2-endring | La dem kjøre ETL mot egen DDL i samling 3 |
| Fakta i dimensjonstabellen / dimensjonsattributter i faktatabellen | `DimProdukt.AntallSolgt`, `FaktSalg.Produktnavn` | Regel: fakta er tall som summeres; attributter er tekst man filtrerer på |
| `NULL` som fremmednøkkel for ukjent dimensjon | `LEFT JOIN` i alle rapporter, rader forsvinner med `INNER JOIN` | Ukjent-rad med nøkkel -1 |
| Datokolonne i stedet for datodimensjon | `FaktSalg.Ordredato DATE` og `DATEPART` i alle rapporter | Spør: «hvilke rader er helligdager?» |

### ETL
| Misforståelse | Hvordan den viser seg | Hva som hjelper |
|---|---|---|
| Laster fakta før dimensjoner | Alle nøkler blir -1 | Tegn avhengighetsgrafen |
| Vannmerke = `MAX(SistEndret)` fra forrige kjøring | Rader som endres under kjøringen mistes | Tidslinje på tavla med en rad som endres midt i lastingen |
| Ren `INSERT` uten eksistenssjekk | Dubletter ved rekjøring | Krav: kjør alltid to ganger i testen |
| Stopper hele jobben ved første feilrad | `THROW` i valideringssteget | Karantenetabell |
| Ignorerer sletting i kilden | Kansellerte ordrer forblir i DW | Oppgave U i samling 3 |
| `MERGE` med flere matchende kilderader | Feilmelding «MERGE statement attempted to UPDATE or DELETE the same row more than once» | Dedupliser i staging først |

### SQL for analyse
| Misforståelse | Hvordan den viser seg | Hva som hjelper |
|---|---|---|
| `ORDER BY` i `OVER()` uten rammeangivelse gir «rare» løpende summer | Like datoer gir hopp i summen | Vis `RANGE` vs `ROWS` med to like datoer |
| `RANK` og `ROW_NUMBER` brukes om hverandre | Topp 10 gir 12 rader eller mister likeplasseringer | Lite datasett med like verdier |
| Filtrerer på vindusfunksjon i `WHERE` | Syntaksfeil «Windowed functions can only appear in SELECT or ORDER BY» | Forklar logisk evalueringsrekkefølge |
| Bruker `ErGjeldende = 1` på alle SCD2-spørringer | Historisk omsetning tilordnes kundens nåværende fylke | Rapport 4 gir forskjellig svar – la dem se det |
| Rullerende 30 rader ≠ 30 dager | Resultatene ser riktige ut men er feil | Fjern en dags salg og se |
| Tror CTE «lagrer» resultatet | Samme CTE referert tre ganger, forventer det kjøres én gang | Vis planen |

### Indeksering og optimalisering
| Misforståelse | Hvordan den viser seg | Hva som hjelper |
|---|---|---|
| «Flere indekser = raskere» | Indeks på hver kolonne | Mål lastetiden |
| «Index Scan betyr at indeksen ikke brukes» | Prøver å tvinge seek med hints | Forklar tipping point; scan av en smal covering index er ofte riktig |
| Primærnøkkel = clustered index, alltid | Faktatabell clustered på `IDENTITY` | Vis I/O med clustered på dato |
| Kolonnerekkefølge i komposittindeks spiller ingen rolle | `(Dato, Kunde)` brukes ikke for `WHERE Kunde = …` | Telefonkatalog |
| Stoler blindt på «Missing Index»-forslaget | Lager overlappende indekser med 15 INCLUDE-kolonner | Vis at forslaget bare ser én spørring |
| Estimert plan er nok | Ser ikke avviket mellom estimert og faktisk | Krev alltid actual plan |
| `WHERE YEAR(dato) = 2025` «bruker jo indeksen» (scan) | Ser scan, tror det er OK | Sammenlign lesninger med områdefilter |
| Tror partisjonering alltid gir raskere spørringer | Partisjonerer alt | Vis spørring uten partisjonsfilter som blir tregere |

---

## 7. Diskusjonsspørsmål og refleksjonsoppgaver

Brukes i plenum (bolk 4) og som grunnlag for det individuelle refleksjonsnotatet i mappen.

**Samling 1**
1. Nordhandel har 200 000 ordrer per år. Er det egentlig behov for et datavarehus, eller kan de rapportere fra en lesereplika? Hva endrer seg når de kjøper opp en konkurrent med eget ordresystem?
2. Hvem i organisasjonen bør eie definisjonen av «omsetning»? Hva skjer hvis IT bestemmer det alene?

**Samling 2**
3. Daglig leder sier «jeg vil bare vite hvor kunden bor *nå*». Markedssjefen sier «jeg vil vite hvor de bodde da de kjøpte». Kan begge få viljen sin? Hva koster det?
4. Når bør man bevisst velge et grovere korn enn kilden tillater? (Hint: personvern, volum, kildens pålitelighet.)
5. Er en junk dimension et brudd på god modellering, eller et pragmatisk kompromiss? Hvor går grensen?

**Samling 3**
6. En feilrad i karantene er fortsatt en feil ingen ser på. Hvordan bør Nordhandel organisere oppfølgingen av karantene – og hvem skal få varselet?
7. Full relasting tar 4 minutter i dag. Hvorfor skal dere bruke tid på inkrementell lasting i det hele tatt? Når snur regnestykket?
8. ELT flytter transformasjonen inn i databasen. Hva mister man når logikken ligger i 40 stored procedures i stedet for i et ETL-verktøy med grafisk oversikt? Hva vinner man?

**Samling 4**
9. En kollega har skrevet rapport 3 med fire korrelerte subspørringer. Den gir riktig svar. Er det et problem? Når er «riktig svar» ikke godt nok?
10. Rapport 5 (rullerende 30 dager) kan beregnes i SQL eller i Power BI (DAX). Hvor bør logikken ligge, og hvorfor?

**Samling 5**
11. **Når bør man *ikke* lage en indeks?** Lag en sjekkliste med minst fem punkter.
12. Databaseansvarlig vil ha clustered columnstore på alle tabeller «fordi det er raskest». Hvilke tabeller i `NordhandelDW` bør *ikke* ha det?
13. Nattlastingen tar 20 minutter; å droppe og gjenskape indeksene tar 6. Er det verdt det? Hvilke tall trenger du for å svare?

**Samling 6**
14. Optimalisereren foreslår en manglende indeks med 94 % estimert forbedring. List opp tre spørsmål du bør stille før du lager den.
15. En spørring går fra 40 sekunder til 2 sekunder etter at du la til et indekshint. Hvorfor er dette likevel en løsning du bør være skeptisk til?
16. Partisjonering gjorde årsrapporten raskere og kunderapporten tregere. Hvem bestemmer hva som er viktigst, og hvordan dokumenterer du avveiningen?

---

## 8. Ressursliste

### Litteratur
| Ressurs | Bruk |
|---|---|
| Kimball, R. & Ross, M. (2013). *The Data Warehouse Toolkit*, 3. utg. Wiley | Hovedbok for samling 1–3. Kap. 1–2 (grunnlag), kap. 3 (retail case – nesten identisk med Nordhandel), kap. 5 (SCD), kap. 19 (ETL) |
| Kimball Group: *Dimensional Modeling Techniques* (gratis, kimballgroup.com) | 3-siders oppslagsliste over alle mønstre – gi til studentene som «jukselapp» |
| Ben-Gan, I. (2019). *T-SQL Window Functions*, 2. utg. Microsoft Press | Samling 4. Kap. 1–2 er nok |
| Ben-Gan, I. (2020). *T-SQL Fundamentals*, 4. utg. Microsoft Press | Repetisjon for studenter med svakere SQL-grunnlag |
| Fritchey, G. (2022). *SQL Server 2022 Query Performance Tuning*, 6. utg. Apress | Samling 5–6. Kap. om execution plans, indeksering og statistikk |
| Brent Ozar: *How to Think Like the SQL Server Engine* (gratis videoserie, brentozar.com) | Samling 5 – den beste forklaringen av sider, clustered/nonclustered og key lookup som finnes. Ca. 90 min, gis som forarbeid |
| Winand, M. *Use The Index, Luke!* (use-the-index-luke.com, gratis) | Plattformnøytral indeksteori. Kapittelet om komposittindekser («concatenated indexes») |
| Inmon, W.H. (2005). *Building the Data Warehouse*, 4. utg. | Kun kap. 1–2 for historikk og den alternative tilnærmingen |

### Dokumentasjon
| Ressurs | Bruk |
|---|---|
| Microsoft Learn: *Execution plan overview* og *Showplan logical and physical operators reference* | Oppslag i samling 6 |
| Microsoft Learn: *Columnstore indexes – Design guidance* | Samling 5 |
| Microsoft Learn: *Partitioned tables and indexes* | Samling 6 |
| Microsoft Learn: *MERGE (Transact-SQL)* – inkl. avsnittet om kjente problemer | Samling 3 |
| Microsoft Learn: *Statistics* og *Cardinality Estimation* | Samling 6 |
| dbt-dokumentasjon: *What is dbt?* og *Snapshots* | Viser moderne ELT og SCD2 i et verktøy – 15 min innslag i samling 3 |

### Verktøy
| Verktøy | Bruk |
|---|---|
| SQL Server 2022 Developer Edition (gratis) eller `mcr.microsoft.com/mssql/server:2022-latest` i Docker | Hovedplattform |
| SQL Server Management Studio 20 / Azure Data Studio | Grafisk execution plan. SSMS anbefales for plan-visning |
| SentryOne Plan Explorer (gratis) | Bedre plan-visualisering for samling 6 |
| `sp_BlitzIndex` (First Responder Kit, gratis) | Valgfritt: viser indeksbruk og duplikatindekser i samling 5 |
| dbdiagram.io eller draw.io | Modelltegning i samling 2 |

### Datasett
| Datasett | Bruk |
|---|---|
| **Nordhandel** (dette opplegget, `case/`) | Hovedcase, generert med kontrollerte datakvalitetsfeil |
| **AdventureWorksDW2022** (Microsoft, gratis) | Et ferdig, «perfekt» stjerneskjema å sammenligne med. God for å vise role-playing dimensions (`DimDate` × 3) og SCD2 i `DimProduct` |
| **WideWorldImportersDW** (Microsoft, gratis) | Viser columnstore, partisjonering og temporal tables i praksis. Referanse i samling 5–6 |
| **Contoso Retail DW** (Microsoft, gratis, ~10 GB) | Hvis man vil ha reelt volum for ytelsesdemonstrasjoner |
| **Stack Overflow-databasen** (Brent Ozar, gratis, 10–150 GB) | Alternativ for samling 5–6 hvis man vil ha «ekte» OLTP-data med ytelsesproblemer |

---

## 9. Neste steg

Samlingsfilene `01-samling-1.md` til `06-samling-6.md` inneholder for hver samling:
- Detaljert tidsplan med lærernotater («si dette», «vent på svar», «vanlig feil her»)
- All demo-SQL med linje-for-linje-forklaring
- Alle lab-oppgaver (grunnleggende / viderekommen / utfordring) med fasit og løsningsforklaring
- Før/etter-eksempler med execution plan (samling 5–6)

Og `case/` inneholder:
- `00-oltp-skjema.sql` – kildesystemet
- `01-oltp-testdata.sql` – generering av testdata med innebygde kvalitetsfeil (~30 s)
- `02-dw-skjema.sql` – ferdig datavarehus (fasit for M1), inkl. `DimDato` med norske helligdager
- `03-etl.sql` – ferdige lasteprosedyrer (fasit for M2): `EXEC etl.KjorAlt @FullLast = 1` (~45 s)
- `04a-simuler-endringer.sql` – flytter kunder og endrer priser så SCD2-rapportene får data
- `04-rapporter.sql` – demoer + de seks rapportene + kohortanalyse (fasit for lab 4)
- `05-indeksering.sql` – eksperimentene E0–E7 med `STATISTICS IO` (samling 5)
- `06-optimalisering.sql` – statistikk, feilene F1–F7, partisjonering (samling 6)
- `06b-jakten.sql` – optimaliseringsjakten: åtte dårlige spørringer med fasit (lab 6)

Og `07-quiz.md` har 30 øvingsspørsmål med fasit.

**Kjør alt fra bunnen** (ca. 2 minutter): `00` → `01` → `02` → `03` → `EXEC etl.KjorAlt @FullLast = 1` → `04a`. Deretter er `04`, `05`, `06` og `06b` uavhengige av hverandre (men `06` forutsetter at `05` har laget `dw.FaktLab`).
