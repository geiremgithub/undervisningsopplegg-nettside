---
title: "Samling 4 – SQL for analyse"
description: "Vindusfunksjoner, rangering, CTE-er, subqueries og rapportspørringer mot datavarehuset."
order: 5
---

# Samling 4 – SQL for analyse

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Alle har fylt `NordhandelDW`. Før samlingen kjører alle: `02-dw-skjema.sql` → `03-etl.sql` → `EXEC etl.KjorAlt @FullLast = 1` → `04a-simuler-endringer.sql` (gir 25 kunder og 10 produkter med to versjoner, så rapport 4 får data). Ca. 50 sekunder totalt.
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.4, `case/04-rapporter.sql` (demoer vises live; rapportene deles ut etter lab), Ben-Gan kap. 1–2.

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Forklare forskjellen på `GROUP BY` (kollapser rader) og `OVER()` (beholder rader), og velge riktig
- (b) Skrive vindusfunksjoner med `PARTITION BY`, `ORDER BY` og eksplisitt ramme (`ROWS BETWEEN …`), og forklare hvorfor standardrammen `RANGE` gir uventede resultater ved like sorteringsverdier
- (c) Velge riktig rangeringsfunksjon (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`) ut fra hvordan likhet skal håndteres
- (d) Bruke `LAG`/`LEAD` for periode-mot-periode-sammenligninger og håndtere manglende perioder
- (e) Strukturere flertrinnsspørringer med CTE-er, og vite når en rekursiv CTE trengs (og når den ikke gjør det)
- (f) Skrive rapporter mot stjerneskjemaet som håndterer SCD type 2 riktig: forretningsnøkkel for «per kunde», surrogatnøkkel for «slik det var», hopp til gjeldende for «slik det er»
- (g) Bygge et datostativ (date spine) for rullerende vinduer, og forklare hvorfor `ROWS 29 PRECEDING` ikke er 30 dager

---

## Bolk 1 (0:00–0:45): Vindusfunksjoner fra bunnen

### 0:00–0:10 Oppsummering og oppvarming

Sjekk at alle har data: `SELECT COUNT(*) FROM dw.FaktSalg` (~580 000) og `SELECT COUNT(*) FROM dw.DimKunde GROUP BY KundeId HAVING COUNT(*) > 1` (25 rader).

Oppvarmingsspørsmål på tavla: *«Vis hver ordre for kunde 1 i 2023 sammen med kundens totale omsetning det året.»* La dem prøve i 3 minutter. De fleste lander på en subspørring:

```sql
SELECT f.OrdreId, SUM(f.NettoBelop) AS Belop,
       (SELECT SUM(f2.NettoBelop) FROM dw.FaktSalg f2 JOIN dw.DimKunde k2 ON … WHERE k2.KundeId = 1 AND …) AS Total
FROM … GROUP BY f.OrdreId
```
Det fungerer. Men: totalen beregnes én gang *per rad*, spørringen gjentar hele filteret, og hvis du vil ha total per kvartal i tillegg, blir det enda en subspørring. Vindusfunksjoner løser akkurat dette.

### 0:10–0:45 Teori + demo 4.1: `OVER()` trinn for trinn

**Grunnidéen** (5 min). Tegn:

```
GROUP BY:   12 rader ──► 1 rad per gruppe       (kollapser)
OVER():     12 rader ──► 12 rader + ekstra kolonne beregnet over en gruppe   (beholder)
```

`OVER()` definerer et **vindu** (window): hvilke rader beregningen skal se. Tre deler, alle valgfrie:

```
SUM(Belop) OVER ( PARTITION BY x   ORDER BY y   ROWS BETWEEN a AND b )
                  ─────────────    ──────────   ─────────────────────
                  del opp i        sorter       hvilke rader rundt
                  grupper          innenfor     denne raden (ramme/frame)
```

**Demo 4.1** – kjør spørringen fra `04-rapporter.sql` og gå gjennom kolonnene én om gangen. Kunde 1 i 2023, aggregert til ordrenivå først (en CTE – vi kommer tilbake til hvorfor):

| Kolonne | Uttrykk | Hva den gjør | Pek på i resultatet |
|---|---|---|---|
| `Total` | `SUM(Belop) OVER ()` | Tomt vindu = alle rader. Totalen gjentatt på hver rad | Samme tall på alle 12 rader: 1 542 343,81 |
| `AndelPst` | `100.0 * Belop / SUM(Belop) OVER ()` | Vindusfunksjon i et uttrykk | Første ordre = 0,09 % av året |
| `MaanedTotal` | `SUM(Belop) OVER (PARTITION BY OrdreDatoKey / 100)` | Ett vindu per måned. `20230111 / 100 = 202301` – heltallsdivisjon som månedsnøkkel | Januar-rader viser 71 266,21, februar 62 645,52 |
| `LopendeRANGE` | `SUM(Belop) OVER (ORDER BY OrdreDatoKey)` | `ORDER BY` uten ramme = løpende sum med **standardrammen** `RANGE UNBOUNDED PRECEDING` | **Se på 2023-01-11: to ordrer samme dag, begge viser 17 423,59.** `RANGE` inkluderer alle rader med *samme sorteringsverdi* (peers). «Løpende sum» hopper |
| `LopendeROWS` | `… ORDER BY OrdreDatoKey ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | Eksplisitt ramme: én rad om gangen | 2023-01-11: 10 752,76 og 17 423,59. Det er det folk *mener* med løpende sum |
| `Snitt3` | `AVG(Belop) OVER (ORDER BY OrdreDatoKey, OrdreId ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` | Glidende vindu: denne og to forrige | Legg merke til `OrdreId` i `ORDER BY` – med `ROWS` må sorteringen være *deterministisk*, ellers varierer resultatet mellom kjøringer |

**Lærernotat – `RANGE` vs `ROWS`:** Dette er den vanligste vindusfunksjonsfeilen i praksis, og den er usynlig når sorteringsverdiene er unike (så testene går grønt). Regel for studentene: **skriv alltid rammen eksplisitt når du bruker `ORDER BY` i et vindu.** `ROWS` er også raskere (SQL Server kan bruke en in-memory spool; `RANGE` krever disk-spool).

**Hvorfor CTE-en først?** (3 min) Vindusfunksjoner evalueres *etter* `GROUP BY` i logisk rekkefølge. Vi kunne skrevet `SUM(SUM(f.NettoBelop)) OVER ()` direkte på fakta – det er lovlig, men vanskelig å lese. Aggreger til riktig korn i en CTE, så vinduer på toppen. Dette blir mønsteret i alle rapportene.

**Logisk evalueringsrekkefølge** (5 min) – skriv den opp, den forklarer tre ting i dag:

```
FROM → WHERE → GROUP BY → HAVING → SELECT (her beregnes vindusfunksjoner) → DISTINCT → ORDER BY → TOP
```
1. Vindusfunksjoner kan ikke stå i `WHERE` (det evalueres før) → «Topp 10» krever en CTE (rapport 2)
2. Vindusfunksjoner kan ikke nøstes (`SUM(ROW_NUMBER() …) OVER …`) → to CTE-trinn
3. Alias fra `SELECT` kan brukes i `ORDER BY`, men ikke i `WHERE`/`GROUP BY`

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): Rangering, forskyvning, CTE-er og SCD2

### 0:55–1:10 Demo 4.2: rangering

Produkter etter antall solgt i mars 2025 – heltall, så det blir likhet:

| Varenummer | Antall | ROW_NUMBER | RANK | DENSE_RANK | NTILE(4) |
|---|---|---|---|---|---|
| NH-00016 | 121 | 6 | 6 | 6 | 1 |
| NH-00023 | 121 | 7 | **6** | **6** | 1 |
| NH-00027 | 119 | 8 | **8** | **7** | 1 |

| Funksjon | Ved likhet | Bruk når |
|---|---|---|
| `ROW_NUMBER()` | Vilkårlig rekkefølge (ikke-deterministisk uten tie-breaker!) | Du trenger nøyaktig N rader (paginering, «én rad per gruppe» med `WHERE rn = 1`) |
| `RANK()` | Samme plass, deretter hull (6, 6, 8) | «Delt sjetteplass» – idrettslogikk |
| `DENSE_RANK()` | Samme plass, ingen hull (6, 6, 7) | «Topp 10 verdier» der flere kan dele plass. Rapport 2 bruker denne |
| `NTILE(n)` | Deler i n like store grupper | Kvartiler, desiler, ABC-analyse |

Spør: *«Topp 10 produkter – hvilken bruker dere?»* `ROW_NUMBER` gir alltid 10 rader men kutter vilkårlig ved likhet. `DENSE_RANK <= 10` gir alle som deler de 10 beste plassene (kan bli 11+). `RANK <= 10` gir også alle med delt plass, men stopper ved hull. Det er en forretningsbeslutning – ikke en teknisk.

### 1:10–1:20 Demo 4.3: `LAG` / `LEAD`

Månedsomsetning 2023–2025:

```sql
ForrigeMaaned    = LAG(Omsetning)  OVER (ORDER BY AarMaaned),
EndringPst       = 100.0 * (Omsetning - LAG(Omsetning) OVER (ORDER BY AarMaaned)) / NULLIF(LAG(…), 0),
SammeMaanedIFjor = LAG(Omsetning)  OVER (PARTITION BY Maaned ORDER BY Aar),
NesteMaaned      = LEAD(Omsetning) OVER (ORDER BY AarMaaned)
```

| Poeng | Forklaring |
|---|---|
| `LAG(x)` = «verdien i forrige rad i vinduet» | Ikke «forrige måned» – forrige *rad*. Finnes ikke mars, er forrige rad for april lik februar |
| Samme måned i fjor: `PARTITION BY Maaned ORDER BY Aar`, ikke `LAG(x, 12)` | `LAG(…, 12)` teller 12 *rader* bakover og forutsetter at alle måneder finnes. Partisjonering på måned er robust |
| `NULLIF(…, 0)` i nevneren | Deling på null gir feil, ikke `NULL` |
| Første rad får `NULL` | `LAG(x, 1, 0)` gir default 0 – men da blir `EndringPst` «uendelig». La `NULL` være `NULL` |

Resultatet viser 7–11 % vekst år-over-år – det er prisfaktoren i testdataene (80 % → 100 %). Og −39 % fra desember til januar hvert år – sesongen vi la inn. Si: *«Her ser dere at datavarehuset gjenskaper det vi vet er sant om kilden. Det er den enkleste formen for validering.»*

### 1:20–1:30 Demo 4.4: CTE vs. subspørring, rekursiv CTE

Vis de to variantene av «kunder over snittet» side om side. Poengene:

- **Lesbarhet**: CTE-versjonen leses ovenfra og ned som en oppskrift. Subspørringsversjonen må leses innenfra og ut, og `PerKunde`-logikken står to ganger.
- **CTE-er er ikke materialisert i SQL Server**: `PerKunde` refereres to ganger (i `Snitt` og i hovedspørringen) og *beregnes to ganger*. Optimalisereren inliner dem. Det er ikke et problem her, men i samling 6 ser vi når en temp-tabell er bedre.
- **`KundeId`, ikke `KundeKey`**: «omsetning per kunde» skal slå sammen alle versjoner av kunden. Grupper på forretningsnøkkelen. Dette er den tredje måten å bruke SCD2 på, og den de glemmer oftest.

Rekursiv CTE på `stg.Kategori` (4.4b): vis stien `Klær > Jakker > Skalljakker`. Og så: `SELECT DISTINCT Hovedkategori, Kategori, Underkategori FROM dw.DimProdukt` – samme informasjon, null rekursjon. *«Rekursjonen gjorde dere én gang, i ETL. Nå slipper alle rapporter den. Det er hele poenget med å flate ut hierarkiet.»*

### 1:30–1:40 Demo 4.5: SCD type 2 i stor skala

Kjør A, B, C fra samling 2 på hele datasettet:

| | Metode | Akershus | Troms | Sum |
|---|---|---|---|---|
| **A** | Join på `KundeKey` – fylke på kjøpstidspunktet | 267,0 M | 96,7 M | 2 411 M |
| **B** | Hopp til `ErGjeldende = 1` via `KundeId` – nåværende fylke | 260,3 M | 107,5 M | 2 411 M |
| **C** | `WHERE k.ErGjeldende = 1` på fakta-joinen | 260,3 M | 96,7 M | **2 363 M** |

A og B gir samme total, fordelt ulikt. **C mister 47,7 millioner** – alle salg til de 25 flyttede kundene *før* flyttingen. Si: *«I en ekte bedrift er dette rapporten som avviker fra regnskapet med 2 %, og ingen skjønner hvorfor. Nå vet dere.»*

Oppsummer de tre mønstrene på tavla – dette er samlingens viktigste lysbilde:

| Spørsmål | Join | Eksempel |
|---|---|---|
| «… slik det var da» | `JOIN DimKunde k ON k.KundeKey = f.KundeKey` – ferdig | Rapport 4, fylke på kjøpstidspunktet |
| «… slik det er nå» | `JOIN DimKunde k ON k.KundeKey = f.KundeKey JOIN DimKunde kn ON kn.KundeId = k.KundeId AND kn.ErGjeldende = 1` | Nåværende fylke, nåværende segment |
| «… per kunde» (uavhengig av versjon) | `GROUP BY k.KundeId` | Rapport 3, kohortanalyse |
| **Aldri** | `WHERE k.ErGjeldende = 1` på fakta-joinen | |

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:45): Lab 4

Rapportspesifikasjonene fra `00-oversikt.md` kap. 1.3. Fasit = `04-rapporter.sql`, deles ut etter plenum.

### Oppgave G (grunnleggende): Rapport 1 og 2

**Rapport 1:** Omsetning og dekningsbidrag per måned per hovedkategori for 2025, med dekningsgrad i prosent. Bare gyldige salg. Bonus: legg til delsummer per måned og totalsum med `ROLLUP`.

**Rapport 2:** Topp 10 produkter per kvartal 2025 etter omsetning, og hvor mange plasser hvert produkt har flyttet seg fra forrige kvartal.

**Fasit G – gjennomgang:**

Rapport 1 er standardmønsteret: fakta i midten, tre dimensjonsjoins, filter og gruppering på dimensjonsattributter, aggregering på fakta. Nye elementer:
- `oi.ErGyldigSalg = 1` – forretningsregelen hentes fra dimensjonen, ikke hardkodet `Status NOT IN (…)`.
- `SUM(f.Dekningsbidrag)` – den beregnede kolonnen fra samling 2. Dekningsgrad = `SUM(DB) / SUM(Netto)`, **ikke** `AVG(DB/Netto)` – forholdstall beregnes fra summer (additivitetsregelen).
- `GROUP BY ROLLUP (d.AarMaaned, p.Hovedkategori)` gir tre nivåer i ett resultat: per måned×kategori, per måned (delsum), totalt. `GROUPING(kolonne) = 1` på delsumrader – brukes til etiketter («Alle kategorier») og sortering. Alternativt `GROUPING SETS` for full kontroll.
- `COUNT(DISTINCT f.OrdreId)` – den degenererte dimensjonen i bruk: antall *ordrer*, ikke linjer.

Rapport 2 er tretrinns-CTE-mønsteret:
1. `PerKvartal`: aggreger til kvartal × produkt. **`GROUP BY p.ProduktId`**, ikke `ProduktKey` – produkt 1–10 har to versjoner (ny pris), og «topp 10 produkter» skal ikke splitte dem. `MAX(p.Navn)` for å få med navnet uten å gruppere på det.
2. `Rangert`: `DENSE_RANK() OVER (PARTITION BY KvartalNavn ORDER BY Omsetning DESC)`.
3. `MedForrige`: `LAG(Plass) OVER (PARTITION BY ProduktId ORDER BY KvartalNavn)` – produktets plass forrige kvartal *blant alle produkter*, ikke bare topp 10. Derfor må filteret `Plass <= 10` komme *etter* `LAG`, i den ytterste spørringen. Legger du filteret i `Rangert`, blir `ForrigePlass` `NULL` for alle som var på plass 11+ forrige kvartal, og «▲ 4» blir «ny».
- Vanlig feil: `WHERE DENSE_RANK() OVER (…) <= 10` direkte → feilmelding *«Windowed functions can only appear in the SELECT or ORDER BY clauses»*. Logisk evalueringsrekkefølge.

### Oppgave V (viderekommen): Rapport 3 og 5

**Rapport 3:** Topp 20 kunder etter omsetning i 2025, med omsetning i fjor og vekst i prosent. En kunde som ikke handlet i 2024 skal ha `NULL` i vekst, ikke sammenlignes med 2023.

**Rapport 5:** Rullerende 30-dagers omsetning per kanal for 2025. Verifiser at vinduet faktisk dekker 30 *dager*.

**Fasit V – gjennomgang:**

Rapport 3:
- `GROUP BY k.KundeId` – per kunde på tvers av versjoner.
- Fellen: `LAG(Omsetning) OVER (PARTITION BY KundeId ORDER BY Aar)` gir *forrige rad*. For en kunde med rader for 2023 og 2025 (ikke 2024) er «forrige» 2023. Løsning: hent også `LAG(Aar)` og sjekk `ForrigeAar = Aar - 1`; ellers `NULL`. Alternativ løsning: datostativ kunde × år med `LEFT JOIN` (samme idé som rapport 5).
- Resultat: kunde 1 (Tor Hansen) 1,48 M i 2025, −3,6 % fra 2024; kunde 30 +135 %.

Rapport 5 – **dette er samlingens viktigste felle**:
- 5a (naiv): `SUM(Omsetning) OVER (PARTITION BY Kanal ORDER BY Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)` på daglig aggregat. Kolonnen `DagerIVindu = DATEDIFF(day, LAG(Dato, 29) OVER (…), Dato) + 1` er kontrollen: den skal være 30. Per kanal er den det (nesten) alltid i våre data, fordi alle kanaler har salg hver dag. **Studentene vil tro de har rett.**
- 5c viser fellen på en glissen serie (Devold i butikk): `DagerIVindu = 31` på ti dager, og naiv rullerende sum er inntil 53 743 kr for høy, fordi vinduet strekker seg over en dag uten salg og dermed inkluderer en ekstra salgsdag.
- 5b (riktig): bygg et **datostativ** – `DimDato CROSS JOIN (DISTINCT Kanal)` – og `LEFT JOIN` det daglige aggregatet med `ISNULL(…, 0)`. Nå er én rad = én dag, alltid, og `ROWS 29 PRECEDING` = 30 dager. Dette er den andre store grunnen til at datodimensjonen finnes.
- SQL Server støtter ikke `RANGE BETWEEN INTERVAL '29' DAY PRECEDING` (det gjør PostgreSQL og Oracle). Datostativet er løsningen uansett plattform, og det gir også `Snitt30` riktig (nevneren blir 30, ikke antall salgsdager).

### Oppgave U (utfordring): Rapport 6 og kohortanalyse

**Rapport 6:** Returandel per merke per kvartal 2025, med merkets plassering i kvartalet.

**Kohortanalyse:** For kunder med første kjøp i 2025: omsetning per kohort (første-kjøps-måned) i måned 0, 1, 2 … 5 etter første kjøp. Én rad per kohort, én kolonne per måned.

**Fasit U – gjennomgang:**

Rapport 6: Fra samling 2, pluss `RANK() OVER (PARTITION BY d.KvartalNavn ORDER BY SUM(…)/NULLIF(SUM(…),0) DESC)` – en vindusfunksjon *over et aggregat*, i samme `SELECT` som `GROUP BY`. Lovlig fordi vinduet evalueres etter grupperingen. Merkenavnene skal være «Osprey», «Hilleberg» – hvis noen ser «OSPREY», har de en gammel `03-etl.sql` (kollasjonsfeilen beskrevet i samling 3).

Kohort:
1. `MIN(AarMaaned) OVER (PARTITION BY KundeId)` – kundens første kjøpsmåned på *hver* av kundens rader, uten `GROUP BY`. Det er det vindusfunksjoner er til.
2. `DATEDIFF(month, ForsteDato, Dato)` = måneder siden første kjøp.
3. Aggreger til kohort × måneder-siden, pivoter med `SUM(CASE WHEN MaanederSiden = n THEN … END)`. (`PIVOT`-syntaks finnes, men `CASE` er lettere å lese og feilsøke.)
4. **Left-censoring:** data starter 2023-01-01, så «første kjøp» for en kunde som handlet i januar 2023 er egentlig ukjent – de kan ha handlet i 2022. Derfor begrenser vi til kohorter fra 2025. Men testdataene har få nye kunder i 2025 (kundene ble opprettet 2021–2022), så kohortene er små (2–9 kunder). Poenget er mønsteret, ikke tallene. Spør: *«Hvordan ville dere definert kohort hvis dere hadde `KundeSiden` fra kilden i stedet?»* (Svar: bruk den – men vi så i samling 1 at den er upålitelig for 40 kunder.)

### Diskusjon under laben: når er en vindusfunksjon feil verktøy?

Ta den med gruppene som blir ferdige:
1. Når du *skal* kollapse rader – `GROUP BY` er enklere og raskere. Ikke skriv `SELECT DISTINCT Kanal, SUM(x) OVER (PARTITION BY Kanal)` når `GROUP BY Kanal` gjør jobben.
2. Når resultatet skal filtreres på vindusverdien – da trenger du uansett en CTE, og noen ganger er en `JOIN` mot et aggregat like lesbart.
3. Når vinduet er stort og sorteringen dyr – `ORDER BY` i vinduet krever en sort av hele partisjonen. I samling 6 ser vi det i planen.
4. Når logikken hører hjemme i rapportverktøyet – rullerende 30 dager kan gjøres i DAX. Hvor skal den ligge? Svar: der den brukes av flest og kan testes best. Ofte: en view i data mart-laget, så Power BI og Excel får samme tall.

---

## Bolk 4 (2:45–3:00): Plenum og avslutning

### Gjennomgang (8 min)

1. Vis rapport 5c (fellen) og 5b (datostativet). Spør hvem som la merke til at `DagerIVindu` ikke var 30. Dette er det viktigste de tar med seg.
2. Vis de tre SCD2-mønstrene en gang til (tabellen fra demo 4.5). Be én gruppe peke på hvor i rapport 2, 3 og 4 hvert mønster brukes.

### Diskusjon (4 min)

*«En kollega har skrevet rapport 3 med fire korrelerte subspørringer. Den gir riktig svar. Er det et problem?»* – Styr mot: riktig svar er nødvendig, ikke tilstrekkelig. Koden skal (1) kunne leses av den neste, (2) kunne endres når kravet endres («legg til vekst i antall ordrer også»), (3) skalere når data tidobles. Fire korrelerte subspørringer feiler på alle tre. Men: ikke skriv om kode som virker uten en grunn – lesbarhet *er* en grunn.

### Hjemmearbeid

1. **Mappeinnlevering 2** (leveres før samling 5): ETL fra samling 3 + alle seks rapportene + testdokumentasjon. Rapportene skal kjøre mot `NordhandelDW` slik den ser ut etter `04a-simuler-endringer.sql`.
2. Før samling 5: se Brent Ozar, *How to Think Like the SQL Server Engine* (hele serien, ~90 min). Slå på «Include Actual Execution Plan» (Ctrl+M) i SSMS og kjør rapport 1 – bare *se* på planen. Ikke prøv å forstå den ennå.
3. Les Fritchey kap. om indekser (kap. 8–9 i 6. utg.).

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| `SUM(x) OVER (ORDER BY dato)` uten ramme, «rare» løpende summer | Standardrammen `RANGE` inkluderer peers | Demo 4.1, 2023-01-11. Regel: alltid eksplisitt `ROWS` |
| `WHERE ROW_NUMBER() OVER (…) = 1` | Logisk evalueringsrekkefølge | Feilmeldingen sier det. CTE |
| `WHERE Plass <= 10` inne i `Rangert` i rapport 2 | Filtrerer før `LAG` kan se forrige kvartal | «▲ 4» blir «ny». Flytt filteret ut |
| `ROW_NUMBER` for topp 10 uten tie-breaker | Ikke-deterministisk ved likhet | Kjør to ganger, få ulikt resultat. Legg til `, Varenummer` i `ORDER BY` |
| `LAG(x, 12)` for «samme måned i fjor» | Teller rader, ikke måneder | `PARTITION BY Maaned ORDER BY Aar` |
| `GROUP BY k.KundeKey` i «per kunde»-rapporter | Splitter kunder med flere versjoner | Kunde 1 dukker opp to ganger i rapport 3 |
| `WHERE k.ErGjeldende = 1` på fakta-join | Mister historikk | Demo 4.5 C: 47,7 M borte |
| `AVG(Dekningsbidrag / NettoBelop)` | Uvektet snitt av forholdstall | Vis at det avviker fra `SUM/SUM`. Additivitetsregelen |
| `ROWS 29 PRECEDING` = 30 dager | Teller rader | `DagerIVindu`-kontrollen. Datostativ |
| `AVG(x) OVER (… ROWS 29 PRECEDING)` på glissen serie | Nevneren er antall *rader* med salg, ikke 30 | Datostativ med `ISNULL(…, 0)` |
| CTE referert tre ganger, forventer én kjøring | Tror CTE materialiseres | Vis planen (forsmak på samling 6). Temp-tabell hvis dyr |
| Bruker `stg.Kategori` i rapporter | Rapporterer mot staging | Staging tømmes hver natt. Hierarkiet ligger i `DimProdukt` |
| `PIVOT`-syntaks i kohortanalysen og får `NULL` overalt | `PIVOT` krever eksakt én aggregat og nøyaktige kolonnenavn | `CASE`-pivot er enklere å feilsøke |

---

## Vedlegg: hurtigreferanse for læreren

**Verifiserte tall** (etter full last + `04a-simuler-endringer.sql`; varierer ±5 % mellom genereringer):

| Hva | Verdi |
|---|---|
| Faktarader | ~580 000 (+100 fra simuleringen) |
| Kunder / produkter med to versjoner | 25 / 10 |
| Demo 4.1: kunde 1, 2023, total | ~1,54 M, 12 ordrer vist av ~130 |
| Demo 4.1: dato med to ordrer (RANGE-fellen) | 2023-01-11 (kunde 1) – sjekk med `SELECT OrdreDatoKey, COUNT(DISTINCT OrdreId) … HAVING COUNT(DISTINCT OrdreId) > 1` hvis dataene er regenerert |
| Demo 4.3: år-over-år vekst | +6 til +11 % (prisfaktor), −39 % des→jan (sesong) |
| Demo 4.5: tapt i variant C | ~47,7 M av 2 411 M (2,0 %) |
| Rapport 1: DG-prosent | 36–40 % i alle kategorier (innkjøp × 1,4–2,2) |
| Rapport 4 | 25 kunder × 2 rader; «etter» har 2 ordrer hver (fra simuleringen) |
| Rapport 5c: dager med avvik, Devold i butikk | ~10 dager, avvik opptil ~54 000 kr |
| Kohort 2025 | 2–9 kunder per kohort |

**Kjøretid `04-rapporter.sql`:** 15–25 s for hele filen (demo 4.4a med nøstede subspørringer er tregest).

**Hvis noe går galt:**
- *Rapport 4 er tom*: `04a-simuler-endringer.sql` er ikke kjørt.
- *Rapport 6 viser «OSPREY»*: gammel `03-etl.sql`. Kjør oppdatert versjon og last på nytt.
- *Demo 4.1 viser ikke RANGE-fellen*: dataene er regenerert og kunde 1 har ingen dag med to ordrer i januar 2023. Finn en med spørringen i tabellen over, eller fjern `TOP (12)` og scroll.
- *`stg.Kategori` er tom*: Extract har ikke kjørt i denne databasen. Kjør `EXEC etl.KjorAlt` (den fyller staging, selv uten endringer).
