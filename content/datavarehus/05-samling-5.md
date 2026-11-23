---
title: "Samling 5 – Indeksering"
description: "Clustered og nonclustered, columnstore, covering- og kompositt-indekser, og hva indekser koster."
order: 6
---

# Samling 5 – Indeksering

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Fylt `NordhandelDW` (som etter samling 4). Alle har sett Brent Ozars *How to Think Like the SQL Server Engine*. Mappeinnlevering 2 er levert.
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.5, `case/05-indeksering.sql` (kjøres eksperiment for eksperiment i demoen), SSMS med **Ctrl+M** (Include Actual Execution Plan) på hos alle.

> **Alle tall i dette dokumentet er målt** på SQL Server 2022 med ~580 000 rader i `FaktSalg`. Dine tall vil avvike litt, men forholdene mellom dem holder.

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Forklare hvordan en tabell er lagret (8 KB-sider, heap vs. clustered index) og hvordan et B-tre gjør oppslag i 3–4 lesninger
- (b) Forklare forskjellen på clustered og nonclustered index, og hva en key lookup er og koster
- (c) Lese `SET STATISTICS IO` og bruke *logiske lesninger* som primært mål på spørringskostnad
- (d) Forklare tipping point: hvorfor optimalisereren velger scan fremfor seek + lookup når mange rader treffes
- (e) Lage en covering index med `INCLUDE` og begrunne hva som skal være nøkkel og hva som skal inkluderes
- (f) Begrunne kolonnerekkefølge i en komposittindeks ut fra spørringens predikater
- (g) Forklare når columnstore er bedre enn rowstore, og demonstrere det med målinger
- (h) Kvantifisere kostnaden ved indekser (lastetid, plass) og veie den mot lesegevinsten

---

## Bolk 1 (0:00–0:45): Hvordan data er lagret

### 0:00–0:10 Oppsett og oppvarming

Alle kjører oppsettsdelen av `05-indeksering.sql` (til og med første `GO` etter `sp_spaceused`). Det lager `dw.FaktLab` – en kopi av `FaktSalg` **uten indekser** – og skriver ut nøkkeltall:

| Hva | Verdi |
|---|---|
| Rader | 580 593 |
| Rader på én dag (2025-03-12) | 417 |
| Rader i én måned (mars 2025) | 10 916 (1,9 %) |
| Rader for den mest aktive kunden | 1 134 |
| Størrelse | 60 MB data ≈ 7 550 sider |

Slå på `Ctrl+M` og `SET STATISTICS IO ON` hos alle. Si: *«I dag ser vi på to tall for hver spørring: logiske lesninger i Messages, og operatorene i planen. Tid er støy – den avhenger av cache, CPU og hva naboen gjør. Lesninger er deterministiske.»*

### 0:10–0:45 Teori: sider, heap, B-tre, clustered og nonclustered

**Sider** (5 min). Alt i SQL Server lagres i **sider (pages)** à 8 KB. En rad i `FaktLab` er ~100 byte → ~80 rader per side → 580 000 rader ≈ 7 500 sider. Når vi sier «logical reads 7546», betyr det at motoren hentet 7 546 sider fra minne (buffer pool). Fysiske lesninger (fra disk) er null fordi alt er cachet – i produksjon er det der det gjør vondt.

**Heap** (5 min). En tabell uten clustered index er en **heap**: sider i vilkårlig rekkefølge, holdt sammen av en allokeringskart (IAM). For å finne «alle rader fra mars» må motoren lese *alle* sidene – **table scan**. Det er E0.

**B-tre** (10 min). Tegn:

```
                        ┌─────────────┐
   Rotnivå              │ 1 … 580593  │                  1 side
                        └──┬───┬───┬──┘
                ┌──────────┘   │   └──────────┐
   Mellomnivå   │ 1…80000 │ 80001…│ … │ …580593│          ~10 sider
                └────┬────┘
            ┌────────┼────────┐
   Bladnivå │ s.1 │ s.2 │ … │ s.7500 │                    7 500 sider = DATAENE (clustered)
            └─────┴─────┴───┴────────┘                    eller nøkkel + peker (nonclustered)
```

- Hver side på mellomnivå peker til ~500 sider under seg. Tre nivåer dekker 500 × 500 × 80 = 20 millioner rader. Derfor koster et oppslag 3–4 lesninger uansett tabellstørrelse. Det er **seek**.
- Bladnivået er sortert på indeksnøkkelen. Et områdefilter («mars») er et seek til første rad, deretter lesing *fremover* langs bladnivået til siste – **range scan**. Kostnaden er proporsjonal med antall treff, ikke tabellstørrelsen.

**Clustered index** (5 min). Bladnivået *er* tabellen. Tabellen er fysisk sortert på nøkkelen. Bare én per tabell – data kan bare være sortert på én måte. Default blir primærnøkkelen clustered, men det er et **valg**. For `FaktSalg` valgte vi `SalgKey` (IDENTITY) i samling 2 – det gir raske innsettinger (alltid på slutten) men hjelper ingen rapport.

**Nonclustered index** (10 min). En separat B-tre-struktur. Bladnivået inneholder indeksnøkkelen + **en peker til raden** (clustered key, eller RID på heap). For å hente kolonner som ikke er i indeksen, må motoren følge pekeren inn i clustered index – **key lookup** – én gang per rad, 3–4 lesninger hver gang.

```
NC-indeks på OrdreDatoKey:            Clustered index (tabellen):
┌─────────────┬─────────┐             ┌─────────┬──────┬─────────┬─────┐
│ OrdreDatoKey│ SalgKey │  ──lookup──►│ SalgKey │ Dato │ Netto   │ …   │
│ 20250312    │ 4711    │             │ 4711    │ …    │ 1 299,00│     │
│ 20250312    │ 98213   │  ──lookup──►│ 98213   │ …    │   349,00│     │
└─────────────┴─────────┘             └─────────┴──────┴─────────┴─────┘
417 treff → 417 lookups → ~1 250 lesninger. For 10 916 treff → 33 000 lesninger. Tabellscan: 7 900.
```

Dette er **tipping point**: når antall lookups × 3 > antall sider i tabellen, er scan billigere. For `FaktLab` ligger grensen rundt 2 500 rader = 0,4 % av tabellen. Optimalisereren vet dette og velger scan for mars-spørringen *selv om det finnes en indeks på dato*. Studentene vil tolke det som «indeksen virker ikke». Den virker – den er bare feil verktøy for den spørringen.

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): Demo – eksperimentene E0–E6

Kjør hvert eksperiment fra `05-indeksering.sql` og skriv tallet på tavla før du forklarer. La studentene gjette først.

### E0–E1: Heap og clustered på surrogatnøkkel

```sql
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
```

| | Lesninger | Plan |
|---|---|---|
| E0 Heap | **7 546** | Table Scan, parallell (Scan count 12 = 12 tråder) |
| E1 Clustered på `SalgKey` | **7 927** | Clustered Index Scan |

Poeng: clustered index på `SalgKey` hjalp ingenting for denne spørringen – litt *flere* lesninger fordi B-treet har overhead. En clustered index er bare nyttig for spørringer som filtrerer eller sorterer på nøkkelen. `SalgKey` filtrerer ingen på.

### E2: Nonclustered på dato – seek, lookup og tipping point

```sql
CREATE INDEX IX_FaktLab_Dato ON dw.FaktLab (OrdreDatoKey);
```

| | Rader | Lesninger | Plan |
|---|---|---|---|
| E2a Én dag | 417 | **1 290** | Index Seek → Key Lookup (Nested Loops) |
| E2b Én måned | 10 916 | **7 927** | Clustered Index Scan – indeksen ignoreres! |
| E2c Én måned, tvunget indeks (`WITH (INDEX(…))`) | 10 916 | **33 470** | Seek + 10 916 lookups |

- E2a: 1 290 / 417 ≈ 3 lesninger per rad = én lookup hver. Indeksen traff 417 rader med noen få lesninger, resten er lookups.
- E2b: optimalisereren estimerte ~11 000 rader, regnet ut at lookups ville koste ~33 000 lesninger, og valgte scan (7 927). **Den hadde rett** – E2c beviser det. Vis det i planen: hold musen over Clustered Index Scan, se «Estimated Number of Rows» ≈ faktisk. Det er statistikken som gjør dette mulig (samling 6).
- Vis den grønne «Missing Index»-teksten i planen for E2b: optimalisereren foreslår en indeks på `OrdreDatoKey` med `INCLUDE (NettoBelop)`. Det er E3.

### E3: Covering index

```sql
CREATE INDEX IX_FaktLab_Dato_Cover ON dw.FaktLab (OrdreDatoKey) INCLUDE (NettoBelop);
```

| | Lesninger | Plan |
|---|---|---|
| E3a Én måned, `SUM(NettoBelop)` | **41** | Index Seek, ingen lookup |
| E3b Samme, men `SUM(NettoBelop), SUM(Kostnad)` | **7 927** | Clustered Index Scan igjen |
| E3c Hele året, `SUM(NettoBelop)` | **654** | Index Scan (av den smale indeksen) |

- E3a: fra 7 927 til **41** – 190× færre lesninger. Alt spørringen trenger ligger på indeksens bladnivå; ingen lookup. Indeksen **dekker** (covers) spørringen.
- E3b: legg til én kolonne som ikke er inkludert → tilbake til scan. En covering index dekker *spesifikke* spørringer. Dette er grunnen til at `SELECT *` er ødeleggende for indeksstrategi: ingen indeks kan dekke «alle kolonner» uten å være en kopi av tabellen.
- E3c: hele året (214 000 rader, 37 %) → Index *Scan*, ikke Seek, men bare 654 lesninger. Indeksen er smal (dato + netto + nøkkel ≈ 20 byte/rad vs. 100 i tabellen), så selv å lese *hele* indeksen koster 1/12 av tabellen. **Scan er ikke et skjellsord.** Scan av en smal covering index er ofte den beste planen.
- `INCLUDE` vs. nøkkel: `NettoBelop` i `INCLUDE` ligger bare på bladnivå – ikke i mellomnivåene, ikke sortert. Billigere å vedlikeholde enn om den var nøkkelkolonne. Regel: kolonner du filtrerer/sorterer på i nøkkelen, kolonner du bare *leser* i `INCLUDE`.

### E4: Clustered index på dato i stedet

```sql
CREATE CLUSTERED INDEX CX_FaktLab_Dato ON dw.FaktLab (OrdreDatoKey, SalgKey);
```

| | Lesninger | Plan |
|---|---|---|
| E4a Én måned, `SUM(Netto), SUM(Kostnad), SUM(Antall)` – tre kolonner | **147** | Clustered Index Seek (range) |
| E4b `SELECT * WHERE SalgKey = 123456` | **7 935** | Clustered Index Scan |

- E4a: 147 lesninger for *alle* kolonner – uten covering index. Tabellen er fysisk sortert på dato, så mars ligger på ~140 sammenhengende sider. Dette er hvorfor datavarehus ofte clusterer faktatabellen på datonøkkelen: nesten alle rapporter filtrerer på dato, og de får range scan på data gratis.
- `SalgKey` som andre kolonne gjør nøkkelen unik. Uten det legger SQL Server til en skjult 4-byte «uniqueifier» – greit, men eksplisitt er bedre.
- E4b: prisen. Oppslag på `SalgKey` er nå scan. Trenger vi det? ETL-ens `MERGE` matcher på `OrdrelinjeId`, som har egen unik indeks. Ingen bruker `SalgKey` til oppslag. Prisen er null i praksis – men det må *sjekkes*, ikke antas.
- Andre pris: innsettinger er ikke lenger «på slutten». Nye ordrer kommer med dagens dato = slutten av indeksen, så i praksis fortsatt sekvensielt. Men sene ordrer med gammel dato gir **page splits**. Nevn det; mål det i lab U.

### E5: Komposittindeks – rekkefølgen

Spørring: *«Omsetning for kunde X i 2025»* – `WHERE KundeKey = 2777 AND OrdreDatoKey BETWEEN 20250101 AND 20251231`.

| Indeks | Predikat | Lesninger | Hva skjer |
|---|---|---|---|
| `(KundeKey, OrdreDatoKey)` | Kunde **og** dato | **5** | Seek på begge: går rett til kundens 2025-rader |
| `(KundeKey, OrdreDatoKey)` | Bare kunde | **9** | Seek på ledende kolonne |
| `(KundeKey, OrdreDatoKey)` | Bare dato (mars) | **2 234** | Kan ikke seeke – dato er ikke ledende. Scan av hele indeksen |
| `(OrdreDatoKey, KundeKey)` | Kunde **og** dato (2025) | **747** | Seek på dato (hele 2025 = 214 000 rader), filtrer på kunde underveis |
| `(OrdreDatoKey, KundeKey)` | Bare dato (mars) | **45** | Seek |

Telefonkatalogen: sortert på etternavn, så fornavn. «Alle Hansen» – lett. «Alle Hansen som heter Kari» – lett. «Alle som heter Kari» – les hele boka.

Regler for rekkefølge:
1. **Likhetspredikater (`=`) først**, områdepredikater (`BETWEEN`, `>`) sist. Etter et områdepredikat kan ikke senere kolonner brukes til seek.
2. Blant likhetskolonnene: **mest selektive først** (den som filtrerer bort flest rader) – men dette er mindre viktig enn regel 1.
3. En indeks på `(A, B)` dekker også spørringer på bare `A`. Du trenger ikke en egen indeks på `A`. (Den er redundant – og `sp_BlitzIndex` vil klage.)

Så for Nordhandel: `(KundeKey, OrdreDatoKey)` passer «én kunde over tid» (kundekort i CRM). `(OrdreDatoKey, …)` passer «alle kunder i en periode» (rapporter). Begge kan være riktige – det avhenger av hvilke spørringer som faktisk kjører. **Du kan ikke indeksere uten å kjenne arbeidslasten.**

### E6: Columnstore

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FaktLabCS ON dw.FaktLabCS;
```

| | Rowstore (clustered på dato) | Columnstore |
|---|---|---|
| Plass | **60 MB** | **15 MB** (4×) |
| E6b/c Rapport 1-aggregering (alle rader, 4 kolonner) | **7 935** lesninger, 12 tråder | **988** lob-lesninger (8×) |
| E6d Punktoppslag `WHERE OrdrelinjeId = 250000` | 3–4 (med indeks) | **3 189** – hele kolonnen dekomprimeres |
| E6e `SUM(Netto)` for mars | 147 | **402** – leser bare to kolonner, men hele segmentet |

- **Hvordan det virker**: i stedet for å lagre rad for rad, lagres hver kolonne for seg i komprimerte **segmenter** à ~1 million rader. `SUM(NettoBelop)` leser bare `NettoBelop`-segmentet – 1/15 av dataene. Pluss **batch mode**: operatorer behandler ~900 rader om gangen i stedet for én og én. Vis «Actual Execution Mode: Batch» i planen.
- **Komprimering**: 4× her. Med mer repetitive data (få distinkte verdier) er 10× vanlig. `OrdreinfoKey` har 73 verdier – det komprimeres til nesten ingenting.
- **Punktoppslag er elendig** (E6d). Columnstore har ingen B-tre; for å finne én rad dekomprimeres alle kolonner for hele segmentet. I SQL Server 2016+ kan man legge en nonclustered B-tre-indeks *oppå* columnstore for akkurat dette.
- **Segment elimination**: hvert segment lagrer min/maks per kolonne. Med `WHERE OrdreDatoKey BETWEEN …` hopper motoren over segmenter som ikke kan inneholde treff – *hvis dataene ble lastet sortert på dato*. Vi har 580 000 rader = ett eneste segment, så det kan ikke demonstreres her. Nevn det: med 50 millioner rader lastet månedsvis får en månedsspørring 1 av 50 segmenter.
- **Når**: faktatabeller > noen millioner rader, analytiske spørringer (aggregering over mange rader, få kolonner), lasting i batch om natten. **Ikke**: dimensjoner (små, mange punktoppslag fra ETL), tabeller med hyppige enkeltrad-oppdateringer (deltastore-overhead).
- For `FaktSalg` i Nordhandel i dag: rowstore clustered på dato er godt nok (147 lesninger for en måned). Om tre år med 5 millioner rader: columnstore.

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:45): Lab 5

Studentene jobber på sin egen `dw.FaktLab`. Fasit under.

### Oppgave G (grunnleggende): Finn riktig indeks

`dw.FaktLab` har nå clustered index på `(OrdreDatoKey, SalgKey)` og ingen nonclustered. For hver av disse tre spørringene: (1) kjør og noter lesninger og plan, (2) lag den indeksen du mener er best, (3) kjør igjen og noter. Begrunn kolonnevalg og rekkefølge.

```sql
-- Q1: Alle ordrelinjer for én ordre (kundeservice slår opp)
SELECT OrdrelinjeId, ProduktKey, Antall, NettoBelop FROM dw.FaktLab WHERE OrdreId = 150000;

-- Q2: Antall solgt per produkt i 2025 (innkjøpsavdelingen)
SELECT ProduktKey, SUM(Antall) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231 GROUP BY ProduktKey;

-- Q3: Omsetning per betalingsmåte per måned (økonomi)
SELECT OrdreDatoKey / 100, OrdreinfoKey, SUM(NettoBelop) FROM dw.FaktLab GROUP BY OrdreDatoKey / 100, OrdreinfoKey;
```

**Fasit G:**

| | Før | Indeks | Etter | Begrunnelse |
|---|---|---|---|---|
| Q1 | **7 935** (scan) | `(OrdreId) INCLUDE (OrdrelinjeId, ProduktKey, Antall, NettoBelop)` | **3** | Likhet på `OrdreId` → nøkkel. De fire kolonnene leses, filtreres ikke → `INCLUDE`. Uten `INCLUDE`: seek + 3 lookups ≈ 12 – også greit, men covering er billig her |
| Q2 | **2 528** (clustered range scan – dato er clustered!) | `(OrdreDatoKey, ProduktKey) INCLUDE (Antall)` | **629** | Clustered på dato gjør allerede jobben (2 528 vs 7 935 for scan). Covering index er smalere → 4× færre lesninger. Men: er én spørring fra innkjøp verdt 8 MB og skrivekostnad? **Et godt svar drøfter det**, uansett konklusjon |
| Q3 | **7 935** (scan, hele tabellen) | `(OrdreinfoKey) INCLUDE (OrdreDatoKey, NettoBelop)` | **2 344** | Ingen filter → det blir scan uansett. Gevinsten er en *smalere* scan (3,4×). Sammenlign med columnstore-alternativet: ~400 |

Poenget med Q2 og Q3: studentene skal oppdage at **en indeks uten filter bare gir smalere scan**, og at gevinsten må veies mot kostnaden. Hvem lager indeks for Q2 uten å kjøre «før»-målingen først?

### Oppgave V (viderekommen): Komposittindeks og redundans

Nordhandel kjører disse fire spørringene hyppig. Lag **færrest mulig** indekser som gir alle fire seek. Mål hver. Kjør deretter spørringen under for å se om du har overlappende indekser.

```sql
-- A: WHERE KundeKey = @k AND OrdreDatoKey BETWEEN @fra AND @til          → SUM(NettoBelop)
-- B: WHERE KundeKey = @k                                                   → COUNT(DISTINCT OrdreId)
-- C: WHERE ProduktKey = @p AND OrdreDatoKey BETWEEN @fra AND @til        → SUM(Antall)
-- D: WHERE OrdreDatoKey BETWEEN @fra AND @til AND ProduktKey = @p         → SUM(Antall), SUM(NettoBelop)

SELECT i.name, STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS Nokkel
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID('dw.FaktLab')
GROUP BY i.name;
```

**Fasit V:** To indekser holder:
- `(KundeKey, OrdreDatoKey) INCLUDE (NettoBelop, OrdreId)` – dekker A (seek på begge) og B (seek på ledende kolonne, `OrdreId` inkludert for `COUNT DISTINCT`).
- `(ProduktKey, OrdreDatoKey) INCLUDE (Antall, NettoBelop)` – dekker C og D. **D har predikatene i motsatt rekkefølge i `WHERE`, men det spiller ingen rolle** – optimalisereren omorganiserer. Det er indeksens kolonnerekkefølge som teller, ikke `WHERE`-klausulens.
- Vanlig feil: lage `(ProduktKey, OrdreDatoKey)` for C **og** `(OrdreDatoKey, ProduktKey)` for D. Den andre gir seek på dato (bredt) og filter på produkt – dårligere enn den første for D også. Redundant.
- Vanlig feil 2: en egen indeks på `(KundeKey)` for B. Redundant med `(KundeKey, OrdreDatoKey)`.
- Målt: A = 6, B = 9, C = 13, D = 13 lesninger. (C og D er identiske – samme indeks, samme plan, uansett rekkefølge i `WHERE`.)

### Oppgave U (utfordring): Nattlastingens regnestykke

Kjør E7 (lastetid med 0/3/6 indekser). Nordhandels nattlasting legger inn ~600 nye ordrelinjer per dag i dag, men ledelsen planlegger oppkjøp som gir 50 000 per dag. Datavarehuset leses av 40 Power BI-brukere mellom 08 og 17.

1. Hva koster de seks indeksene i lastetid per natt i dag? Om ett år?
2. Hva sparer de? Anslå ut fra E3a (7 927 → 41 lesninger) og anta 2 000 rapportkjøringer per dag.
3. Bør Nordhandel droppe indeksene før lasting og gjenskape dem etterpå? Hvilke tall trenger du for å svare?
4. Tilleggsspørsmål: bytt `INSERT INTO dw.FaktLabLast SELECT * FROM #Kilde` til å sette inn i **datosortert** rekkefølge (`ORDER BY OrdreDatoKey`). Endres lastetiden? Hvorfor?

**Fasit U:**

Målt i E7 (100 000 rader):

| Nonclustered indekser | Lastetid | Per rad |
|---|---|---|
| 0 | **511 ms** | 5 µs |
| 3 (FK-indekser) | **2 199 ms** (4,3×) | 22 µs |
| 6 (+ 3 covering) | **3 733 ms** (7,3×) | 37 µs |

Plass: clustered 10 MB, seks nonclustered til sammen **16 MB** – indeksene er større enn dataene.

1. I dag: 600 rader × 37 µs ≈ **22 ms**. Irrelevant. Om ett år med 50 000/dag: ~2 s. Fortsatt irrelevant i et nattevindu. Det er først ved millioner rader per natt at dette teller – og da er columnstore + partisjonering (samling 6) svaret, ikke færre indekser.
2. 2 000 kjøringer × (7 927 − 41) ≈ **16 millioner lesninger spart per dag**. I minne: sekunder. Fra disk: minutter til timer. Og det er CPU og minne som frigjøres for de andre 39 brukerne.
3. **Nei, ikke ennå.** Drop/recreate lønner seg når (a) lastevolumet per natt er en betydelig andel av tabellen (>10–20 %), og (b) gjenoppbyggingen er raskere enn den inkrementelle vedlikeholdskostnaden. Her er lastingen 0,1 % av tabellen. Tallene som trengs: lastetid med indekser, lastetid uten + rebuild-tid, og *lengden på nattevinduet*. Mål, ikke gjett. Generelt mønster for store DW: drop nonclustered → last → rebuild, fordi rebuild av en indeks på 50 millioner rader (sekvensiell skriving) er langt raskere enn 50 millioner enkeltinnsettinger i et B-tre (tilfeldig skriving).
4. Sortert innsetting er typisk **20–40 % raskere** med clustered på dato (ikke på `SalgKey` som i E7 – bytt clustered først for å se det). Rader lander på slutten av indeksen i stedet for å splitte sider midt i. `#Kilde` er bevisst `ORDER BY NEWID()` for å simulere «sene» rader. Lærdom: ETL bør sortere batchen på clustered key før `INSERT`. SQL Server gjør det ofte selv (sort-operator før insert) når den tror det lønner seg – se i planen.

---

## Bolk 4 (2:45–3:00): Plenum og avslutning

### Gjennomgang (7 min)

Vis `sys.dm_db_index_usage_stats` for `dw.FaktSalg` (den ekte tabellen) etter en uke med rapportkjøringer:

```sql
SELECT i.name, s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s ON s.object_id = i.object_id AND s.index_id = i.index_id AND s.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('dw.FaktSalg');
```
`user_updates` høyt og `user_seeks + user_scans` = 0 → indeksen koster og gir ingenting. Dette er den første spørringen du kjører i et ukjent datavarehus. (DMV-en nullstilles ved restart – i produksjon logges den.)

### Diskusjon (5 min): Når bør man *ikke* lage en indeks?

La gruppene foreslå, samle på tavla. Mål: minst disse:
1. Når spørringen treffer en stor andel av tabellen (> 5–10 %) – scan er riktig uansett (E2b, E3c)
2. Når tabellen er liten (< noen hundre sider) – scan koster mindre enn B-tre-overheaden
3. Når en eksisterende indeks allerede dekker den (ledende kolonne) – redundant (lab V)
4. Når tabellen skrives mye og leses sjelden – staging! `stg.*` skal *aldri* ha indekser
5. Når «Missing Index»-forslaget er basert på én kjøring av én ad-hoc-spørring – forslaget ser ikke de 40 andre spørringene og ikke skrivekostnaden
6. Når kolonnen har svært lav selektivitet (`ErGyldigSalg` med to verdier) – med mindre det er en filtrert indeks eller en del av en komposittindeks
7. Når du ikke har målt «før» – du vet ikke om den hjalp

### Hjemmearbeid

1. **Mappeinnlevering 3 starter nå**: velg fire av de seks rapportene fra samling 4. For hver: mål lesninger og tid mot `dw.FaktSalg` *slik den er* (clustered på `SalgKey` + fire FK-indekser), lag din indeksstrategi, mål igjen, dokumenter. Minst én optimalisering skal *forkastes* med begrunnelse. Leveres etter samling 6.
2. Les Fritchey kap. om execution plans og statistikk (kap. 6–7, 13 i 6. utg.) – eller Microsoft Learn: *Execution plan overview* og *Statistics*.
3. Kjør rapport 1 med actual plan og finn operatoren med tykkest pil. Noter estimert vs. faktisk radantall. Ta det med til neste gang.

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| «Indeksen virker ikke – planen sier scan» (E2b) | Kjenner ikke tipping point | E2c: tving indeksen, vis 33 000 lesninger |
| Tvinger indeks med `WITH (INDEX())` i rapportkode | Overstyrer optimalisereren permanent | Hint fryser planen. Når data endrer seg, er hintet feil. Samling 6 |
| «Index Scan = dårlig» | Blander scan av smal indeks med tabellscan | E3c: 654 lesninger for hele året |
| `INCLUDE` med 12 kolonner | Kopierer tabellen | Hver inkluderte kolonne koster plass og skrivetid. Dekk de spørringene som *kjører*, ikke alle tenkelige |
| Indeks på hver kolonne «for sikkerhets skyld» | Ikke forstått kompositt og kostnad | E5 + E7 |
| `(Dato, Kunde)` og `(Kunde, Dato)` som «samme indeks» | Rekkefølge ikke forstått | Telefonkatalogen. E5c vs E5e: 2 234 vs 45 |
| Stoler på Missing Index-forslaget blindt | Forslaget er per spørring | Vis at det foreslår `INCLUDE` av alt spørringen ba om, og ikke kjenner skrivekostnaden |
| Clustered = primærnøkkel, alltid | Default forvekslet med regel | E4a: 147 vs 7 927 |
| Columnstore på alt | «Det er raskest» | E6d: punktoppslag 3 189 lesninger. Dimensjoner skal ikke ha det |
| Måler tid, ikke lesninger | Støy fra cache og CPU | Kjør samme spørring to ganger – tiden halveres, lesningene er like |
| Glemmer `GO` mellom `CREATE INDEX` og `WITH (INDEX(…))` | Hint kompileres før indeksen finnes | Msg 308. Egen batch |
| `SELECT INTO` beholder `IDENTITY` | Innsetting i kopien feiler | `ISNULL(SalgKey, 0)` i `SELECT INTO` fjerner egenskapen |

---

## Vedlegg: hurtigreferanse for læreren

**Alle målte tall samlet** (580 593 rader, SQL Server 2022):

| Eksperiment | Lesninger | Merknad |
|---|---|---|
| E0 heap, måned | 7 546 | |
| E1 clustered SalgKey, måned | 7 927 | |
| E2a NC dato, én dag (417 rader) | 1 290 | seek + lookup |
| E2b NC dato, måned | 7 927 | scan valgt |
| E2c NC dato tvunget, måned | 33 470 | |
| E3a covering, måned | 41 | |
| E3b covering + ekstra kolonne | 7 927 | |
| E3c covering, hele året | 654 | index scan |
| E4a clustered dato, måned, 3 kolonner | 147 | |
| E4b clustered dato, `WHERE SalgKey = n` | 7 935 | |
| E5a `(Kunde,Dato)`, kunde+år | 5 | |
| E5b `(Kunde,Dato)`, kunde | 9 | |
| E5c `(Kunde,Dato)`, dato | 2 234 | index scan |
| E5d `(Dato,Kunde)`, kunde+år | 747 | |
| E5e `(Dato,Kunde)`, dato | 45 | |
| E6 plass rowstore / columnstore | 60 MB / 15 MB | |
| E6b/c aggregering rowstore / columnstore | 7 935 / 988 lob | |
| E6d punktoppslag columnstore | 3 189 lob | |
| E6e måned columnstore | 402 lob | ett segment |
| E7 last 100 000 med 0/3/6 NC | 511 / 2 199 / 3 733 ms | |
| E7 plass clustered / 6 NC | 10 MB / 16 MB | |

**Kjøretid `05-indeksering.sql`:** ~30 s.

**Hvis noe går galt:**
- *Tallene avviker mye*: Sjekk at `FaktLab` har ~580 000 rader. Hvis studenten har kjørt `04a-simuler-endringer.sql` flere ganger, er det flere. Forholdene holder likevel.
- *E2b velger seek i stedet for scan*: Statistikken er annerledes (færre rader i mars i deres generering). Bruk hele kvartalet.
- *Columnstore viser «logical reads 0»*: Riktig – se `lob logical reads` lenger ut på linjen.
- *E7 gir helt andre tider*: Avhenger av disk og CPU. Forholdet 1 : 4 : 7 er det som teller.
- *Planen viser ingen «Missing Index»*: Optimalisereren foreslår bare når gevinsten er stor nok. E2b skal gi forslag; E3c ikke.
