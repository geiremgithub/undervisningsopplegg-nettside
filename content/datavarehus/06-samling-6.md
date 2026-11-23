---
title: "Samling 6 – Spørringsoptimalisering"
description: "Execution plans, statistikk, scan vs. seek, partisjonering og vanlige ytelsesfeil."
order: 7
---

# Samling 6 – Spørringsoptimalisering

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Samling 5 gjennomført; `dw.FaktLab` (clustered på dato) og `dw.FaktLabCS` finnes. Studentene har sett på planen for rapport 1 hjemme.
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.6, `case/06-optimalisering.sql` (demoer), `case/06b-jakten.sql` (lab – del ut *bare* FØR-blokkene), `07-quiz.md`. SSMS med Ctrl+M på.

> Alle tall er målt på SQL Server 2022 (kompatibilitetsnivå 160). Flere av de klassiske «feilene» kompenserer SQL Server 2014/2019+ for – det er i seg selv et poeng, og demoene viser både gammel og ny oppførsel.

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Lese en grafisk execution plan systematisk: dataflyt, operatorer, pil-tykkelse, estimert vs. faktisk radantall, varsler
- (b) Forklare hva statistikk er (histogram, tetthet, endringsteller), når den oppdateres automatisk, og hva som skjer når estimatet bommer
- (c) Identifisere og rette de vanlige ytelsesfeilene: ikke-SARGable predikater, implisitt konvertering, `SELECT *`, catch-all-spørringer, tabellvariabler, parameter sniffing, manglende FK-indeks, skalarfunksjoner
- (d) Skille mellom en ytelsesfeil og en korrekthetsfeil, og vite at den siste er verre
- (e) Partisjonere en faktatabell, demonstrere partition elimination, bruke `SWITCH` for lasting og arkivering, og forklare prisen
- (f) Dokumentere en optimalisering med før/etter-måling og begrunnelse – og forkaste en optimalisering som ikke lønner seg

---

## Bolk 1 (0:00–0:45): Lese planen, forstå statistikk

### 0:00–0:10 Oppsummering

Spør hva de så i planen for rapport 1. Vanlige observasjoner: «mange bokser», «tykke piler fra FaktSalg», «Hash Match». Bruk det som inngang.

### 0:10–0:30 Teori: slik leser du en plan

Kjør rapport 1 (fra `04-rapporter.sql`) med Ctrl+M og gå gjennom planen live. Metoden – skriv den på tavla, den brukes resten av dagen:

| Steg | Hva du gjør | Hva du ser etter |
|---|---|---|
| 1 | **Les fra høyre til venstre** | Data flyter fra tabellene (høyre) mot `SELECT` (venstre). Det første som skjer står ytterst til høyre |
| 2 | **Finn den tykkeste pilen** | Pilbredde = antall rader. Der flest rader flyter, er kostnaden. I rapport 1: ut av `FaktSalg` |
| 3 | **Se på operatortypene** | *Scan* (leser alt) vs *Seek* (hopper til). *Nested Loops* (bra for få rader ytre side), *Hash Match* (bra for mange, trenger minne), *Merge Join* (begge sortert). *Sort* (dyrt – hvorfor sorteres det?). *Key Lookup* (indeksen dekker ikke) |
| 4 | **Hold musen over hver operator: Estimated vs Actual Number of Rows** | Avvik på 10× eller mer = optimalisereren tok beslutninger på feil grunnlag. Kilden er nesten alltid statistikk (bolk 1) eller noe den ikke kan estimere (funksjoner, variabler, tabellvariabler) |
| 5 | **Se etter varsler** (gult trekant) | Implisitt konvertering, spill til tempdb (sort/hash fikk for lite minne), manglende statistikk, manglende join-predikat |
| 6 | **Les «Missing Index»-forslaget – med skepsis** | Det ser bare denne spørringen |
| 7 | **Prosenttallene («Cost: 85 %») er ESTIMATER** | De er *ikke* målt. En operator med 2 % kan være den som faktisk tar tiden. Bruk `STATISTICS IO`/`TIME` for sannheten |

Si eksplisitt: *«Actual plan, ikke estimated. Estimated plan er hva optimalisereren tror skal skje. Actual er hva som skjedde. Forskjellen er hele poenget.»*

### 0:30–0:45 Demo S: statistikk

**Hva statistikk er** (5 min). Kjør `DBCC SHOW_STATISTICS ('dw.FaktStat', 'IX_Dato') WITH HISTOGRAM` og vis: opptil 200 **trinn** (`RANGE_HI_KEY`), hvert med antall rader på og under trinnet. Optimalisereren slår opp i dette for å gjette hvor mange rader `WHERE OrdreDatoKey >= 20260101` gir. Pluss **tetthet** (density = 1 / antall distinkte verdier) for likhetspredikater med ukjent verdi.

**Når oppdateres den?** Automatisk (`AUTO_UPDATE_STATISTICS`) når `modification_counter` passerer terskelen `sqrt(1000 × rader)` ≈ 24 000 for vår tabell (før 2016: 20 % = 116 000!). Mellom oppdateringene er histogrammet **utdatert**: nye datoer finnes ikke i det.

**Demoen** (10 min): 20 000 rader for januar 2026 settes inn – under terskelen. Spørringen `WHERE OrdreDatoKey >= 20260101`:

| | Estimator | Lesninger | Plan |
|---|---|---|---|
| S2 | Ny (2014+, standard) | **8 197** | Scan. Estimerer ut fra `modification_counter` at det finnes rader over histogrammet |
| S3 | Gammel (`FORCE_LEGACY_CARDINALITY_ESTIMATION`) | **60 086** | Estimat **1 rad** → Index Seek + Key Lookup × 20 000 |
| S4 | Gammel, etter `UPDATE STATISTICS` | 8 197 | Scan – nå vet den |

Poeng: (1) **statistikk bestemmer planen**; (2) moderne SQL Server kompenserer for «ascending key»-problemet, men du møter den gamle oppførselen i databaser med kompatibilitetsnivå < 120, og i andre databasesystemer; (3) **ETL bør oppdatere statistikk eksplisitt** etter lasting (`UPDATE STATISTICS dw.FaktSalg` i `etl.KjorAlt` – 2 sekunder, og aldri mer gjetting). Vis `sys.dm_db_stats_properties` (S3b): `modification_counter` er tallet å overvåke.

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): De vanlige feilene – før og etter

Kjør F1–F7 fra `06-optimalisering.sql`. For hver: la studentene gjette tallet, kjør, forklar. Hold tempo – 6 minutter per feil.

### F1 Ikke-SARGable predikat

| | Lesninger |
|---|---|
| `WHERE OrdreDatoKey / 100 = 202503` | **7 935** – scan |
| `WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331` | **147** – seek |

**SARGable** = *Search ARGument-able*: predikatet kan brukes til å søke i en indeks. Regelen: **kolonnen står alene på én side av sammenligningen.** `YEAR(dato) = 2025`, `dato / 100 = x`, `LEFT(navn, 3) = 'Nor'`, `ISNULL(x, 0) = 0`, `dato + 1 > …` – alle ødelegger seek. Skriv om så funksjonen står på *konstanten*: `dato >= '2025-01-01' AND dato < '2026-01-01'`, `navn LIKE 'Nor%'`.

F1c/F1d – nyansen: `WHERE YEAR(d.Dato) = 2025 AND MONTH(d.Dato) = 3` via `DimDato` gir **299** lesninger, like mye som `d.AarMaaned = '2025-03'`. Hvorfor ikke verre? Fordi funksjonen står på *dimensjonen* (4 000 rader – scan koster 10 sider), og joinen til fakta seeker likevel. Lærdom: **det er faktatabellen som teller.** Men bruk dimensjonskolonnene uansett – de finnes for det, og den dagen `DimDato` har en indeks på `AarMaaned`, virker den.

### F2 Implisitt konvertering

| | Lesninger |
|---|---|
| `WHERE Postnummer = N'0150'` (NVARCHAR-verdi mot CHAR-kolonne) | **33** – scan + gult varsel |
| `WHERE Postnummer = '0150'` | **4** – seek |

Når typene ikke stemmer, konverterer SQL Server den med *lavest prioritet* – og `NVARCHAR` slår `CHAR`/`VARCHAR`. Så **kolonnen** konverteres, for hver rad, og indeksen kan ikke brukes (under `SQL_`-kollasjoner; Windows-kollasjoner klarer seg bedre). Vanligste kilde: ORM-er og applikasjoner som sender alle strenger som `NVARCHAR` (`AddWithValue` i .NET). F2c viser det samme i kilden: `Kunde.Postnummer NVARCHAR(10)` mot `Postnummer CHAR(4)` – husker dere fra samling 1? Regel: **samme type på begge sider av `=`.** Planen varsler (`CONVERT_IMPLICIT`), men bare hvis du ser etter.

### F3 `SELECT *`

| | Lesninger |
|---|---|
| `SELECT OrdreDatoKey, NettoBelop … WHERE KundeKey = 2777` | **9** – covering seek |
| `SELECT * … WHERE KundeKey = 2777` | **3 490** – 1 134 key lookups |

Samme filter, 390× flere lesninger. `SELECT *` kan per definisjon ikke dekkes av noen indeks. Og i et datavarehus med Power BI som leser tabeller rett inn: **lag views som velger kolonner**, aldri eksponer tabellen.

### F4 Catch-all-spørringen

```sql
WHERE (@Kunde IS NULL OR KundeKey = @Kunde) AND (@Produkt IS NULL OR ProduktKey = @Produkt)
```

| | Lesninger |
|---|---|
| Som skrevet, `@Kunde = 2777`, `@Produkt = NULL` | **4 688** – scan (index union over begge) |
| Med `OPTION (RECOMPILE)` | **9** – seek |

Det ser fleksibelt ut: én prosedyre, valgfrie filtre. Men optimalisereren må lage **én plan som er riktig for alle kombinasjoner** av `NULL`/ikke-`NULL` – og det blir scan. `OPTION (RECOMPILE)` lager planen for *disse* verdiene; `@Produkt IS NULL` er da `TRUE` og hele grenen forsvinner. Kostnaden: kompilering per kall (~ms). For rapporter som kjøres noen hundre ganger om dagen: alltid verdt det. For OLTP-spørringer 10 000 ganger i sekundet: dynamisk SQL i stedet.

### F5 Tabellvariabel vs. temp-tabell

| | Lesninger |
|---|---|
| `@Nokler` med 50 000 rader, gammel oppførsel (`DISABLE_DEFERRED_COMPILATION_TV`) | **150 759** – estimat 1 rad → Nested Loops → 50 000 seeks |
| `@Nokler`, SQL Server 2019+ | **580** – riktig estimat → Merge Join |
| `#Nokler` (temp-tabell) | **580** |

Tabellvariabler har ingen statistikk og ble (før 2019) alltid estimert til **1 rad**. Med 50 000 rader velger optimalisereren Nested Loops – riktig for 1 rad, katastrofe for 50 000. SQL Server 2019 (kompat. 150) utsetter kompileringen til variabelen er fylt, og problemet forsvinner. Men: (1) mange databaser kjører fortsatt lavere kompatibilitetsnivå, (2) temp-tabeller kan indekseres fritt og har ekte statistikk. **Regel: temp-tabell for alt over noen hundre rader.** Det er derfor `etl.*` bruker `#Kunde`, `#Linje` osv.

### F6 Parameter sniffing

Prosedyre med `@Fra, @Til` på en tabell clustered på `SalgKey` med nonclustered på dato (slik `FaktSalg` faktisk er):

| Kall | Plan i cache | Lesninger |
|---|---|---|
| F6a: én dag (første kall) | Kompileres: seek + lookup | 1 290 |
| F6b: **hele året** med «én dag»-planen | Gjenbrukt: seek + **194 000 lookups** | **594 059** |
| F6c: hele året, frisk cache | Kompileres: scan | 7 927 |
| F6d: én dag med «hele året»-planen | Gjenbrukt: scan for 400 rader | 7 927 |
| F6e: `OPTION (RECOMPILE)` | Ny plan hver gang | 1 290 / 7 927 |

**Sniffing** = optimalisereren «lukter» på parameterverdiene ved *første* kall og lager en plan for dem. Planen caches og gjenbrukes for alle senere kall – også de med helt andre verdier. Det er en *feature* (kompilering er dyrt), men med skjev datafordeling blir det et problem. Symptomet i drift: «rapporten var rask i går, i dag tar den ti minutter, ingenting er endret» – noen kjørte den med en liten parameter først, etter en restart. Løsninger, i prioritert rekkefølge: (1) `OPTION (RECOMPILE)` på rapportspørringer, (2) `OPTIMIZE FOR (@Fra UNKNOWN)` – plan for «typisk» verdi, (3) Query Store med tvungen plan, (4) skriv om så planen er god for begge (covering index på dato → alltid seek).

### F7 Manglende indeks på fremmednøkkel

| | Lesninger |
|---|---|
| `JOIN DimProdukt … WHERE p.Varenummer = 'NH-00005'`, uten indeks på `FaktLab.ProduktKey` | **7 935** – scan av fakta |
| Med `(ProduktKey) INCLUDE (NettoBelop)` | **23** |

Dimensjonen filtreres til ett produkt (seek på `Varenummer`), men for å finne *faktaradene* for det produktet må hele faktatabellen leses. Enhver `Key`-kolonne i en faktatabell skal ha en indeks – det er derfor `02-dw-skjema.sql` lager fire. (Og ja: den glemte `OrdreinfoKey`. Det er J7 i jakten.)

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:30): Demo + lab – partisjonering

Kjør P1–P5 fra `06-optimalisering.sql` sammen med studentene.

**Hva det er** (5 min): tabellen deles fysisk i deler etter en kolonne – her år via `OrdreDatoKey`. Tre objekter: **partisjonsfunksjon** (grensene: `20240101, 20250101, …`, `RANGE RIGHT` = grensen tilhører partisjonen til høyre), **partisjonsskjema** (hvilken filgruppe hver partisjon ligger på – i produksjon ofte én per partisjon på ulike disker), og **tabellen/indeksen** opprettet `ON PS_Aar(OrdreDatoKey)`. Partisjonskolonnen *må* være med i clustered key.

| | Hva | Resultat |
|---|---|---|
| P1 | Rader per partisjon via `$PARTITION.PF_Aar(OrdreDatoKey)` | 2023: 192 840 · 2024: 193 617 · 2025: 193 836 · 2026: tom |
| P2 | `WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231` | **2 534** lesninger, «Actual Partition Count: 1» i planen – **partition elimination** |
| P3 | `WHERE SalgKey = 123456` – ikke partisjonskolonnen | **7 982** lesninger, Scan count 15 – *alle* partisjoner skannes |
| P3b | Samme på upartisjonert `FaktLab` | 2 237–7 935 (avhengig av hvilken indeks som skannes) |
| P4 | `SWITCH IN` av 2026-tabellen (300 rader – men ville vært likt for 300 millioner) | **26 ms**. Metadataoperasjon: ingen rader flyttes |
| P5 | `SWITCH OUT` av 2023 til arkivtabell | 192 840 rader ut på millisekunder |

**Poengene**:
- Partition elimination hjelper bare spørringer som filtrerer på partisjonskolonnen. P2 gir 2 534 – men `FaktLab` clustered på dato ga samme (E4/F6c: 2 234–2 528). **Partisjonering er ikke primært en ytelsesteknikk.**
- Den store gevinsten er **forvaltning**: `SWITCH IN` laster en måned/et år uten å røre resten av tabellen (ingen låser, ingen indeksvedlikehold på eksisterende data – indeksen bygges på den lille tabellen *før* switch). `SWITCH OUT` arkiverer eller sletter 200 000 rader på et øyeblikk, der `DELETE` ville tatt minutter og fylt transaksjonsloggen. Og: statistikk, komprimering og `REBUILD` kan gjøres per partisjon.
- Prisen: spørringer uten partisjonsfilter blir *tregere* (P3), alle unike indekser må inkludere partisjonskolonnen, og `SWITCH` krever identisk struktur + `CHECK`-begrensning som *beviser* at radene hører hjemme (se `CK_FaktPart_2026`).
- Når: faktatabeller på titalls millioner rader med tidsbasert lasting og arkivering. Nordhandel: ikke ennå. Om tre år, sammen med columnstore (som også er partisjonerbart – rowgroups per partisjon).

**Mini-lab (10 min):** Studentene legger til en partisjon for 2027 (`ALTER PARTITION FUNCTION PF_Aar() SPLIT RANGE (20280101)` – merk at `RANGE RIGHT` og en tom siste partisjon gjør dette billig), og forsøker `SWITCH IN` av en tabell *uten* `CHECK`-begrensning. Feilmeldingen (*«ALTER TABLE SWITCH statement failed. Check constraints … of source table … allow values that are not allowed by range defined by partition»*) er poenget.

---

## Bolk 3 forts. (2:30–2:50): Lab 6 – optimaliseringsjakten

Del ut FØR-blokkene fra `06b-jakten.sql` (åtte spørringer mot den ekte `dw.FaktSalg`). Oppgave: for hver – finn feilen, rett den, dokumenter lesninger og CPU/tid før og etter i en tabell. **Én av dem er ikke en ytelsesfeil.** Grupper som blir ferdige tidlig: finn den.

**Fasit (målt):**

| # | Feil | Før | Etter | Rettelse |
|---|---|---|---|---|
| J1 | Ikke-SARGable: `CONVERT(VARCHAR, OrdreDatoKey) LIKE '20250312%'` | 9 022 | **1 291** | `OrdreDatoKey = 20250312` |
| J2 | Korrelert `TOP 1 … ORDER BY` per produkt | 8 580 lesninger, **3 095 ms** (seriell) | 9 022 lesninger, **190 ms** | `ROW_NUMBER() OVER (PARTITION BY ProduktKey ORDER BY NettoBelop DESC)`. Lesningene er *like* – men planen er seriell vs. parallell, 16× raskere. **Lesninger er ikke alt** |
| J3 | `WHERE k.ErGjeldende = 1` på fakta-join | 9 022 – og **18 millioner for lite** (865,1 M vs 847,1 M) | – | Fjern filteret. Dette er **korrekthetsfeilen**. Ingen ytelsesforskjell – rapporten er bare *feil*. Grupper som «optimaliserer» den uten å se det, har ikke sjekket tallet |
| J4 | Implisitt konvertering: `@Postnummer NVARCHAR` mot `CHAR(4)` | DimKunde 12 (scan + varsel) | DimKunde **2** (seek) | Deklarer parameteren som `CHAR(4)`. Liten tabell, liten gevinst – men varselet i planen skal fanges |
| J5 | Catch-all `(@Dato IS NULL OR …)` i prosedyre | 2 589 | **1 291** | `OPTION (RECOMPILE)` |
| J6 | `UNION` av disjunkte sett (tre års-spørringer) | **27 066** (tre scans + sort/distinct) | **9 022** (én scan, én `GROUP BY`) | `UNION ALL` – eller enda bedre: `GROUP BY OrdreDatoKey / 10000` i én spørring |
| J7 | Manglende indeks på `FaktSalg.OrdreinfoKey` | 9 022 | **293** | `CREATE INDEX … (OrdreinfoKey) INCLUDE (OrdreDatoKey, NettoBelop)`. Den eneste FK-nøkkelen `02-dw-skjema.sql` ikke indekserte – med vilje, så noen skulle finne den |
| J8 | Skalarfunksjon `WITH INLINE = OFF` i aggregering | 8 580 lesninger, **3 948 ms** | 9 022 lesninger, **39 ms** | Uttrykket inline. 2019+ gjør dette selv for enkle funksjoner (*scalar UDF inlining*) – med mindre funksjonen er for kompleks eller `INLINE = OFF`. **Bonus**: `AVG(dekningsgrad)` er uansett feil – uvektet snitt av forholdstall. `SUM/SUM` |

Vurdering av lab/mappe: full uttelling krever (a) før/etter-tall for alle, (b) J3 identifisert som korrekthetsfeil, (c) minst én kommentar om at J2/J8 viser at lesninger ikke fanger alt.

---

## Bolk 4 (2:50–3:00): Avslutning

### Emnet i ett bilde (5 min)

Tegn hele reisen på tavla:

```
Samling 1: OLTP kan ikke svare → vi trenger et DW
Samling 2: korn, stjerne, SCD2 → modellen
Samling 3: staging, karantene, vannmerke, MERGE → dataene inn
Samling 4: OVER(), CTE, tre SCD2-mønstre → svarene ut
Samling 5: sider, B-tre, covering, columnstore → raskt nok
Samling 6: plan, statistikk, feilene, partisjonering → raskt nok også neste år
```

Og de tre setningene å ta med:
1. **Kilden glemmer. Datavarehuset husker.** (SCD2)
2. **Kjør den to ganger.** (idempotens)
3. **Mål før du endrer.** (lesninger, actual plan)

### Mappeinnlevering 3 og quiz (5 min)

- **M3 Ytelse** (20 %): fire rapporter, før/etter med plan og `STATISTICS IO`, begrunnet indeksstrategi, **én forkastet optimalisering** med begrunnelse, lastetid med/uten indekser (E7). Leveres om to uker.
- **Quiz** (40 %): 30 spørsmål, 60 min, åpen bok uten database. `07-quiz.md` har 30 øvingsspørsmål med fasit på samme nivå – ikke de samme spørsmålene.

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| Leser planen fra venstre | Følger ikke dataflyten | «Hvor kommer radene *fra*?» |
| Stoler på kostnadsprosentene | Tror de er målt | Vis J2: Sort-operatoren har lav %, men tar all tiden |
| Bruker estimated plan | Ser ikke avviket estimat/faktisk | Ctrl+M, ikke Ctrl+L |
| «Statistikk er noe DBA-en tar seg av» | Vet ikke at ETL endrer data uten å oppdatere | S3: 60 086 vs 8 197. Legg `UPDATE STATISTICS` i `etl.KjorAlt` |
| Legger `OPTION (RECOMPILE)` på alt | Overkompenserer | Kompilering koster. Rapporter ja, OLTP nei |
| Tvinger plan med indekshint | «Virker nå» | Hintet overlever dataendringer. Query Store-forcing er sporbart; hint er ikke |
| `WHERE YEAR(dato) = 2025` «men det er jo bare en liten funksjon» | SARGability | F1a/b: 7 935 vs 147 |
| Retter J3 ved å legge til indeks | Så ikke at tallet var galt | Spør: «stemmer 847 millioner med rapport 1?» |
| «Partisjonering gjør alt raskere» | Forveksler elimination med magi | P3: 15 scans |
| `SWITCH` feiler, gir opp | Mangler `CHECK` eller ulik struktur | Feilmeldingen sier det – les den |
| Tabellvariabel «fordi den er i minnet» | Myte | Begge kan spilles til disk. Forskjellen er statistikk |
| Lesninger like → «ingen forskjell» | Ser ikke på CPU/tid/parallellisering | J2 og J8 |

---

## Vedlegg: hurtigreferanse for læreren

**Målte tall samlet** (SQL Server 2022, ~580 000 rader):

| Demo | Før | Etter |
|---|---|---|
| S2/S3 statistikk, ny vs gammel CE | 60 086 (gammel) | 8 197 |
| F1 SARGable | 7 935 | 147 |
| F2 implisitt konvertering (DimKunde) | 33 | 4 |
| F3 `SELECT *` | 3 490 | 9 |
| F4 catch-all | 4 688 | 9 |
| F5 tabellvariabel (gammel/ny) | 150 759 | 580 |
| F6 sniffing: år med dag-plan / frisk | 594 059 | 7 927 |
| F7 FK-indeks | 7 935 | 23 |
| P2 elimination | – | 2 534 (1 partisjon) |
| P3 uten partisjonsfilter | 7 982 (15 scans) | – |
| P4 SWITCH IN | – | 26 ms |
| J1–J8 | se fasit-tabellen | |

**Kjøretid:** `06-optimalisering.sql` ~20 s, `06b-jakten.sql` ~10 s (J2 og J8 FØR tar 3–4 s hver).

**Hvis noe går galt:**
- *S3 gir ikke 60 000*: Databasen har kompat. < 120 (da er «gammel» allerede standard og S2 vil vise det), eller `FORCE_LEGACY_CARDINALITY_ESTIMATION` er ikke støttet (< 2016). Sjekk `SELECT compatibility_level FROM sys.databases WHERE name = 'NordhandelDW'`.
- *F5a gir 580 i stedet for 150 000*: Hintet `DISABLE_DEFERRED_COMPILATION_TV` krever 2019+. På eldre versjoner er F5a standardoppførselen uten hint.
- *F6b gir ikke 594 000*: Noen kjørte F6c først (cache). `DBCC FREEPROCCACHE` og kjør F6a → F6b i rekkefølge.
- *P4 SWITCH feiler «… allow values that are not allowed by range»*: `CHECK`-begrensningen mangler eller er `NOT TRUSTED` (`WITH NOCHECK`). Også hvis målpartisjonen ikke er tom.
- *J2 FØR tar > 30 s*: Serveren har få kjerner / mye annet. Stopp og vis planen – Nested Loops med `TOP` + `Sort` inne i løkken er poenget.
- *`dw.FaktLab` har gale indekser fra samling 5*: Skriptet forutsetter kun `CX_FaktLab_Dato`. `DROP INDEX` alt annet, eller kjør oppsettsdelen av `05-indeksering.sql` + `CREATE CLUSTERED INDEX CX_FaktLab_Dato ON dw.FaktLab (OrdreDatoKey, SalgKey)`.
