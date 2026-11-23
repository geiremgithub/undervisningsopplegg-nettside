---
title: "Samling 3 – ETL og ELT"
description: "Staging, datakvalitet, feilhåndtering, inkrementell vs. full lasting, logging og overvåkning."
order: 4
---

# Samling 3 – ETL og ELT

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Mappeinnlevering 1 levert. Alle har `NordhandelShop` og en tom `NordhandelDW` (kjør `case/02-dw-skjema.sql` på nytt før samlingen så alle har samme skjema).
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.3, `case/03-etl.sql` (demo-delene vises live; hele filen deles ut etter lab), Kimball & Ross kap. 19.

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Forklare forskjellen på ETL og ELT, og begrunne hvorfor transformasjon i SQL er valgt her
- (b) Beskrive og begrunne standard lastesekvens: logg → extract → valider → dimensjoner → fakta → vannmerke → logg
- (c) Implementere SCD type 1 og 2 i SQL med korrekt håndtering av `GyldigFra`/`GyldigTil`, inkludert kanttilfellet «to endringer samme dag»
- (d) Implementere inkrementell lasting med vannmerke, og forklare hvorfor vannmerket er uttrekkets *starttid* og ikke `MAX(SistEndret)`
- (e) Skille datakvalitetsavvik i tre alvorsgrader (korrigert / lastet med advarsel / avvist) og rute dem til en karantenetabell uten å stoppe lastingen
- (f) Skrive en idempotent faktalasting (`MERGE` på forretningsnøkkel) og forklare hvorfor `WHEN NOT MATCHED BY SOURCE` er farlig med inkrementell kilde
- (g) Bruke `TRY…CATCH`, `XACT_ABORT` og én transaksjon slik at datavarehuset aldri står halvlastet
- (h) Lese ETL-loggen og oppdage avvik i radantall

---

## Bolk 1 (0:00–0:45): Prinsipper

### 0:00–0:10 Oppsummering og utdeling

Kommenter mappeinnlevering 1 kort (2–3 fellestrekk, ingen navn). Si at alle nå bruker *samme* DDL (`02-dw-skjema.sql`) resten av kurset, uansett hva de leverte, slik at ETL-koden blir sammenlignbar. Alle kjører skriptet nå.

### 0:10–0:25 ETL vs. ELT

Tegn de to:

```
ETL:  Kilde ──extract──► [ETL-server: transformer] ──load──► DW          (SSIS, Informatica, Talend, Python)
ELT:  Kilde ──extract──► DW.staging ──transform (SQL)──► DW.dw           (dbt, stored procedures, Snowflake/Synapse/Fabric)
```

| | ETL | ELT |
|---|---|---|
| Transformasjon skjer | I eget verktøy, utenfor databasen | I måldatabasen, med SQL |
| Styrke | Kan lese alt (filer, API, mainframe); grafisk oversikt | Bruker databasens regnekraft; SQL er versjonerbart, testbart, kjent |
| Svakhet | Egen server, egen kompetanse, pakker er vanskelige å diffe i Git | Alt må kunne uttrykkes i SQL; «extract» til staging må fortsatt gjøres av noe |
| Dominerer når | Mange heterogene kilder, mye radvis logikk | Moderne skyplattformer, dataingeniører med SQL-bakgrunn |

Vi gjør **ELT i T-SQL**: kilden er en SQL Server på samme instans, så «extract» er en `INSERT … SELECT` over databasenavn. I virkeligheten ville extract vært en linked server, Azure Data Factory-kopi, eller en Python-jobb som skriver CSV/Parquet – men *alt etter staging er identisk*. Det er poenget.

### 0:25–0:45 Lastesekvensen og hvorfor rekkefølgen er som den er

Skriv de sju stegene på tavla og still «hva går galt hvis vi bytter om?» for hvert:

| # | Steg | Hvis du hopper over / bytter om |
|---|---|---|
| 1 | **Start logg** | Du vet ikke at jobben startet og hang. Første spørsmål i drift er «kjørte den?» |
| 2 | **Extract → staging** (rå kopi) | Transformerer du rett fra kilden, holder du låser i kilden mens du regner, og når transformasjonen feiler halvveis, må du lese kilden på nytt – som da har endret seg |
| 3 | **Valider → karantene** | Feil rader stopper jobben (hvis du `THROW`-er) eller forsvinner stille (hvis du filtrerer). Begge er galt |
| 4 | **Dimensjoner** (SCD) | Må være før fakta – fakta slår opp nøklene. Laster du fakta først, blir alle nøkler `-1` |
| 5 | **Fakta** (upsert) | — |
| 6 | **Vannmerke** | Settes *sist*, inne i transaksjonen. Settes det først og jobben feiler, hopper neste kjøring over radene |
| 7 | **Avslutt logg** | Status, varighet, radantall. Grunnlaget for overvåkning |

**Full vs. inkrementell** (5 min). Nordhandel har 580 000 ordrelinjer; full lasting tar 40 sekunder. Spør: *«Hvorfor skal vi bry oss med inkrementell lasting?»* Svar: (1) i dag 40 s, om tre år 400 s, om seks år 4 000 s; (2) kilden belastes av fulle uttrekk hver natt; (3) SCD type 2 *krever* at vi vet hva som endret seg – med full lasting av dimensjoner er det greit (vi sammenligner mot DW), men vi vil ikke sammenligne 580 000 faktarader hver natt. Regel: **dimensjoner kan lastes fullt (små), fakta inkrementelt (store).** Og: *behold alltid muligheten til full relasting* (`@FullLast = 1`) – det er din redning når noe har gått galt.

**Vannmerket** (5 min). Tegn tidslinjen:

```
            Forrige kjøring                       Denne kjøringen
            ─────┬─────                           ────┬────
  SistEndret:    22:00:00 ─── jobben leser ─── 22:00:45
                                 ▲
                   Rad X endres 22:00:20, SistEndret = 22:00:20
```

Hvis vannmerket settes til `MAX(SistEndret)` av det vi leste (22:00:45), og rad X ble committet *etter* at vi leste den tabellen men *før* jobben var ferdig – da har X `SistEndret = 22:00:20 < 22:00:45` og hoppes over neste gang. Den er tapt. Løsning: vannmerket = **starttiden for uttrekket** (22:00:00), og uttrekket henter `SistEndret > forrige vannmerke AND SistEndret <= starttid`. Rad X blir med neste natt. (Ekte systemer bruker gjerne CDC eller `rowversion` i stedet for en `SistEndret`-kolonne applikasjonen *må huske* å oppdatere – nevn det.)

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): Demo – `etl.LastDimKunde` bygges steg for steg

**Lærernotat:** Dette er samlingens kjerne. Ikke vis hele `03-etl.sql` – åpne en tom spørring og bygg prosedyren opp i rekkefølgen under, kjør hvert fragment mot staging og vis resultatet. Kjør først del 0–4 av `03-etl.sql` (tabeller, logg, `etl.Extract`) så staging er fylt: `DECLARE @v DATETIME2; EXEC etl.Extract 0, 1, @v OUTPUT;`.

### Steg 1 – Forbered (5.1 i skriptet)

```sql
SELECT  k.KundeId, k.Navn, k.PostnummerRaa, k.PostnummerRenset,
        Postnummer = ISNULL(p.Postnummer, '0000'),
        Poststed   = ISNULL(p.Poststed,   N'Ukjent'),
        Kommune    = ISNULL(p.Kommune,    N'Ukjent'),
        Fylke      = ISNULL(p.Fylke,      N'Ukjent'),
        k.Kundesegment, k.KundeSiden,
        FunnetIRegister = CASE WHEN p.Postnummer IS NULL THEN 0 ELSE 1 END
INTO    #Kunde
FROM (
    SELECT  KundeId,
            Navn = TRIM(Fornavn) + N' ' + TRIM(Etternavn),
            PostnummerRaa = Postnummer,
            PostnummerRenset = CASE
                WHEN Postnummer IS NULL THEN NULL
                WHEN LEN(TRIM(REPLACE(Postnummer, 'O', '0'))) = 3 THEN '0' + TRIM(REPLACE(Postnummer, 'O', '0'))
                ELSE TRIM(REPLACE(Postnummer, 'O', '0')) END,
            Kundesegment = ISNULL(NULLIF(TRIM(Kundesegment), N''), N'Ukjent'),
            KundeSiden   = CAST(Opprettet AS DATE)
    FROM stg.Kunde
) k
LEFT JOIN stg.Postnummer p ON p.Postnummer = k.PostnummerRenset;
```

| Linje | Hva | Hvorfor |
|---|---|---|
| Indre `SELECT … FROM stg.Kunde` | Rens og normaliser kildekolonnene | Alle regler for «hva er et gyldig postnummer» står ett sted |
| `REPLACE(Postnummer, 'O', '0')` | Bokstaven O → tallet 0 | Regelbasert *automatisk korreksjon*. Trygt fordi et postnummer aldri inneholder bokstaver |
| `LEN(TRIM(…)) = 3 THEN '0' + …` | Tapt ledende null | Også trygg: norske postnummer er alltid fire siffer |
| `ISNULL(NULLIF(TRIM(Kundesegment), N''), N'Ukjent')` | `NULL` *og* tom streng → `'Ukjent'` | Dimensjonsattributter er aldri `NULL`. `NULLIF(x, '')` gjør tom streng til `NULL` så `ISNULL` fanger begge |
| `LEFT JOIN stg.Postnummer` | Berik med kommune og fylke fra registeret | Kilden har bare poststed; fylke er det rapportene trenger |
| `ISNULL(p.Fylke, N'Ukjent')` | Ukjent postnummer → `'Ukjent'`-fylke, `'0000'`-postnummer | Kunden lastes likevel. Et salg til en kunde med ukjent fylke er fortsatt et salg |
| `FunnetIRegister` | Flagg for karantene i neste steg | Vi skiller «korrigert og funnet» fra «ikke funnet» |
| `INTO #Kunde` | Midlertidig tabell | Vi bruker resultatet i fire påfølgende setninger. Temp-tabell (ikke tabellvariabel) fordi den får statistikk – samling 6 |

Kjør `SELECT * FROM #Kunde WHERE PostnummerRaa <> Postnummer OR Postnummer = '0000'` og vis korreksjonene.

### Steg 2 – Karantene (5.2)

Vis strukturen i `etl.Karantene` og de tre alvorsgradene:

| Alvor | Betyr | Eksempel |
|---|---|---|
| **Info** | Korrigert automatisk eller bare til orientering. Raden er lastet riktig | `[O566] → 0566`, mulig dublett |
| **Advarsel** | Lastet, men med `'Ukjent'` eller en antakelse. Noen bør se på kilden | Postnummer ikke i register, produkt uten kategori |
| **Feil** | **Ikke lastet.** Raden er avvist og må rettes i kilden | Ordredato i fremtiden, antall ≤ 0 |

```sql
INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
SELECT @KjoringId, N'Kunde', k.KundeId, r.Regel, r.Alvor, r.Verdi
FROM #Kunde k
CROSS APPLY (
    SELECT N'Postnummer korrigert automatisk' AS Regel, N'Info' AS Alvor,
           CONCAT(N'[', k.PostnummerRaa, N'] → ', k.Postnummer) AS Verdi
    WHERE k.FunnetIRegister = 1 AND k.PostnummerRaa IS NOT NULL
      AND CAST(k.PostnummerRaa AS VARBINARY(20)) <> CAST(CAST(k.Postnummer AS NVARCHAR(10)) AS VARBINARY(20))
    UNION ALL
    SELECT N'Postnummer finnes ikke i register', N'Advarsel', CONCAT(N'[', k.PostnummerRaa, N']')
    WHERE k.FunnetIRegister = 0 AND k.PostnummerRaa IS NOT NULL
    UNION ALL
    SELECT N'Postnummer mangler', N'Info', NULL
    WHERE k.PostnummerRaa IS NULL
    UNION ALL
    SELECT N'Mulig dublett (…)', N'Info', (SELECT STRING_AGG(k2.KundeId, ',') FROM #Kunde k2 WHERE …)
    WHERE k.Postnummer <> '0000' AND EXISTS (…)
) r
WHERE NOT EXISTS (SELECT 1 FROM etl.Karantene q
                  WHERE q.Kilde = N'Kunde' AND q.KildeId = k.KundeId AND q.Regel = r.Regel);
```

| Del | Hvorfor |
|---|---|
| `CROSS APPLY (SELECT … WHERE … UNION ALL SELECT … WHERE …)` | Én rad per *regel som slår til* per kunde. Hver `SELECT … WHERE` gir 0 eller 1 rad. Mønsteret skalerer: ny regel = ny `UNION ALL`-blokk |
| `CAST(… AS VARBINARY)` | Binær sammenligning. Vanlig `<>` sier at `'0566 '` = `'0566'` (SQL Server ignorerer mellomrom bak). Vi *vil* logge at vi fjernet et mellomrom |
| `WHERE NOT EXISTS (… samme Kilde, KildeId, Regel)` | **Ikke spam karantenen.** Samme avvik logges én gang, ikke hver natt. Ellers har du 365 rader om samme kunde etter ett år, og ingen leser den |
| `Behandlet BIT` i tabellen | Noen må kunne krysse av «sett». Karantenen er en *arbeidsliste*, ikke bare en logg |

**Lærernotat om dublettregelen:** Fortell historien. Første versjon («samme navn og postnummer») ga **1 990 treff på 5 050 kunder** – 40 %. Med 20 fornavn × 20 etternavn i testdataene kolliderer navnene hele tiden. Med krav om registrering innen 31 dager: ~300 treff, hvorav ~100 er de 50 plantede parene. Fremdeles 2/3 falske positive. Lærdom: *dublettdeteksjon produserer kandidater for et menneske*. Automatisk sammenslåing av kunder er noe av det farligste man kan gjøre i et datavarehus.

### Steg 3 – Type 1 (5.3)

```sql
UPDATE d
SET    Navn = k.Navn, OppdatertKjoringId = @KjoringId
FROM   dw.DimKunde d
JOIN   #Kunde k ON k.KundeId = d.KundeId
WHERE  d.Navn <> k.Navn;
```
- Ingen `ErGjeldende = 1`: type 1 overskriver **alle versjoner**. Hvis Kari het «Kari Hansen» i Stavanger-versjonen og retter stavefeilen etter at hun flyttet, skal begge versjoner vise det nye navnet. Ellers ser rapport 4 ut som om to ulike personer flyttet.
- `WHERE d.Navn <> k.Navn`: oppdater bare det som er endret. Ellers skriver vi 5 050 rader hver natt, vedlikeholder indekser og fyller transaksjonsloggen for ingenting. Fungerer bare fordi begge sider er `NOT NULL` (steg 1).
- `OppdatertKjoringId`: revisjonsspor. «Hvilken kjøring endret denne raden?» er det første du spør når noe ser rart ut.

### Steg 4 – Type 2: oppdag, utløp, sett inn (5.4–5.5)

```sql
-- 4a. Hvilke gjeldende rader har endret type 2-attributter?
SELECT  d.KundeKey, d.KundeId,
        SammeDag = CASE WHEN d.GyldigFra = @LastDato THEN 1 ELSE 0 END
INTO    #Endret
FROM    dw.DimKunde d
JOIN    #Kunde k ON k.KundeId = d.KundeId
WHERE   d.ErGjeldende = 1
  AND  (d.Postnummer <> k.Postnummer OR d.Poststed <> k.Poststed OR d.Kommune <> k.Kommune
        OR d.Fylke <> k.Fylke OR d.Kundesegment <> k.Kundesegment);
```
- Her brukes `ErGjeldende = 1` *riktig*: vi sammenligner kilden med *siste kjente tilstand*.
- `SammeDag`: kanttilfellet. Hvis versjonen ble opprettet i dag (`GyldigFra = i dag`) og attributtet endres igjen i dag, kan vi ikke lage en ny versjon med `GyldigFra = i dag` og sette den gamle til `GyldigTil = i går` – da er `GyldigTil < GyldigFra`. Løsning: overskriv dagens versjon (4b). Korn for historikk er *én dag*; to endringer samme dag kollapser. Si det eksplisitt – det er en designbeslutning.

```sql
-- 4b. Samme dag: overskriv (kan ikke ha to versjoner på én dato)
UPDATE d SET Postnummer = k.Postnummer, Poststed = k.Poststed, Kommune = k.Kommune, Fylke = k.Fylke,
             Kundesegment = k.Kundesegment, OppdatertKjoringId = @KjoringId
FROM dw.DimKunde d
JOIN #Endret e ON e.KundeKey = d.KundeKey AND e.SammeDag = 1
JOIN #Kunde  k ON k.KundeId  = e.KundeId;

-- 4c. Utløp gammel versjon: gyldig til og med i går
UPDATE d SET GyldigTil = DATEADD(day, -1, @LastDato), ErGjeldende = 0, OppdatertKjoringId = @KjoringId
FROM dw.DimKunde d
JOIN #Endret e ON e.KundeKey = d.KundeKey AND e.SammeDag = 0;
```
- `GyldigTil = i går`, ikke i dag: intervallene skal være sammenhengende og ikke overlappe. Dato D hører til *én* versjon.

```sql
-- 4d. Sett inn: nye versjoner (fra 4c) OG helt nye kunder – begge mangler nå en gjeldende rad
INSERT INTO dw.DimKunde (KundeId, Navn, Postnummer, …, OpprinneligKundesegment, KundeSiden, GyldigFra, GyldigTil, ErGjeldende, InnsattKjoringId)
SELECT  k.KundeId, k.Navn, k.Postnummer, …,
        OpprinneligKundesegment = ISNULL(f.OpprinneligKundesegment, k.Kundesegment),   -- type 0: arv fra første versjon
        KundeSiden              = ISNULL(f.KundeSiden, k.KundeSiden),
        GyldigFra               = CASE WHEN f.KundeId IS NULL THEN '19000101' ELSE @LastDato END,
        GyldigTil               = '99991231',
        ErGjeldende             = 1,
        InnsattKjoringId        = @KjoringId
FROM    #Kunde k
LEFT JOIN (SELECT KundeId, MAX(OpprinneligKundesegment) AS OpprinneligKundesegment, MIN(KundeSiden) AS KundeSiden
           FROM dw.DimKunde GROUP BY KundeId) f ON f.KundeId = k.KundeId
WHERE NOT EXISTS (SELECT 1 FROM dw.DimKunde d WHERE d.KundeId = k.KundeId AND d.ErGjeldende = 1);
```
- Elegansen: etter 4c har de endrede kundene *ingen* gjeldende rad – akkurat som helt nye kunder. Ett `INSERT` dekker begge, `NOT EXISTS` er filteret.
- `GyldigFra`: `'1900-01-01'` for en ny kunde (så alle gamle ordrer treffer), `@LastDato` for en ny versjon. Spør: *«Hvorfor ikke bruke kildens `SistEndret` som `GyldigFra`?»* Svar: fordi vi ikke kan stole på at den reflekterer *når adressen endret seg* – den endres av alt mulig. Datavarehuset registrerer endringen når det *ser* den. (Avansert alternativ: kilder med ekte endringshistorikk.)
- Type 0: `OpprinneligKundesegment` og `KundeSiden` arves fra første versjon via `f`. For en ny kunde er `f` tom → kildens verdi brukes.

**Lærernotat – `MERGE`-varianten:** Studentene vil ha hørt om `MERGE` og det berømte «INSERT over MERGE med OUTPUT»-mønsteret for SCD2. Vis det gjerne som en fotnote, men ikke bruk det for dimensjoner: det er vanskeligere å lese, `MERGE` har en lang liste kjente feil (søk «MERGE bugs Aaron Bertrand»), og den eksplisitte varianten over er lettere å debugge steg for steg. Vi bruker `MERGE` for *fakta* (steg 7.4), der den passer: enkel upsert på én nøkkel.

### Steg 5 – Kjør, endre, kjør igjen

Nå kjør hele `03-etl.sql` og deretter:

```sql
EXEC etl.KjorAlt @FullLast = 1;
SELECT * FROM etl.vKjoringer ORDER BY KjoringId, Steg;
```
Vis loggen: Extract 781 343 lest, DimKunde 5 050 innsatt, DimProdukt 800, FaktSalg 580 057 innsatt, ~42 s totalt.

```sql
EXEC etl.KjorAlt;          -- kjøring 2: ingenting endret
```
**0 innsatt, 0 oppdatert, 0 slettet i alle steg.** Det er idempotens. Si: *«Dette er den viktigste testen dere kan gjøre på en ETL-jobb: kjør den to ganger. Hvis tallene endrer seg, er den feil.»*

```sql
-- Kunde 1 flytter (kilden), produkt 1 får ny pris
UPDATE NordhandelShop.dbo.Kunde   SET Postnummer = '9008', Poststed = 'Tromsø', SistEndret = SYSDATETIME() WHERE KundeId = 1;
UPDATE NordhandelShop.dbo.Produkt SET Salgspris = Salgspris + 100, SistEndret = SYSDATETIME() WHERE ProduktId = 1;
EXEC etl.KjorAlt;          -- kjøring 3

SELECT KundeKey, Fylke, GyldigFra, GyldigTil, ErGjeldende FROM dw.DimKunde WHERE KundeId = 1 ORDER BY GyldigFra;
```
| KundeKey | Fylke | GyldigFra | GyldigTil | ErGjeldende |
|---|---|---|---|---|
| 1896 | Møre og Romsdal | 1900-01-01 | *i går* | 0 |
| 5051 | Troms | *i dag* | 9999-12-31 | 1 |

Og det viktigste: `SELECT COUNT(*) FROM dw.FaktSalg WHERE KundeKey = 1896` – alle kunde 1s gamle ordrer peker *fortsatt* på Møre og Romsdal-versjonen. Historikken er bevart uten at en eneste faktarad ble rørt.

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:45): Lab 3

Studentene har nå `etl.Extract`, `etl.LastDimKunde`, loggtabellene og `etl.KjorAlt` (del 0–5 og 9 av skriptet). De skal skrive `LastDimProdukt` og `LastFaktSalg` selv. Fasit = del 6–8 i `03-etl.sql`, deles ut etter plenum.

### Oppgave G (grunnleggende): `etl.LastDimProdukt`

Skriv prosedyren etter samme mønster som `LastDimKunde`:
1. Forbered: flat ut kategorihierarkiet (rekursiv CTE fra samling 1), normaliser merke, `'Ukjent'` for manglende/slettet kategori
2. Karantene: produkter uten kategori (Advarsel), produkter som peker på `SLETTET`-kategori (Advarsel), merke normalisert (Info), salgspris < innkjøpspris (Advarsel)
3. Type 1: `Varenummer`, `Navn`, `Merke`, `Aktiv`
4. Type 2: `Hovedkategori`, `Kategori`, `Underkategori`, `Innkjopspris`, `Salgspris`
5. Logg steget

Test: kjør `EXEC etl.LastDimProdukt 0` to ganger. Andre gang skal 0 rader settes inn. Endre pris på ett produkt i kilden, kjør `etl.Extract` + `etl.LastDimProdukt` igjen, vis to versjoner.

**Fasit G:** Del 6 i `03-etl.sql`. Vurderingspunkter:

| Krav | Godkjent når |
|---|---|
| Hierarki | Rekursiv CTE som gir `Hovedkategori`/`Kategori`/`Underkategori` for *alle* nivåer. Produkt på nivå 2 får `Underkategori = Kategori` – ikke `NULL`, ikke `'Ukjent'` |
| Merke | Normalisert så `'NORRØNA'`, `'Norrøna '` og `'Norrøna'` blir én verdi. Fasitens løsning: velg skrivemåten flest produkter bruker (`ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(Merke)) ORDER BY COUNT(*) DESC)`). **Felle:** `GROUP BY TRIM(Merke)` under CI-kollasjon slår `'Osprey'` og `'OSPREY'` sammen og returnerer en vilkårlig etikett – første versjon av fasiten ga «OSPREY» i rapportene. Løsning: `COLLATE Latin1_General_BIN2` i grupperingen, og `COLLATE DATABASE_DEFAULT` på vei ut igjen. Enklere løsning (`UPPER(TRIM(Merke))` → `'NORRØNA'`) godtas, men gir stygge rapporter |
| Slettet kategori | Behandles som ukjent *og* logges. Ikke lastet med `Hovedkategori = 'SLETTET - gamle varer'` |
| Type 1 vs. 2 | Som angitt. Særlig: `Navn` endres på *alle* versjoner |
| Idempotens | 0 innsatt ved rekjøring |

**Vanlig feil:** `WHERE d.Merke <> p.Merke` når én side kan være `NULL` → `NULL <> 'X'` er `UNKNOWN`, ikke `TRUE`, og endringen oppdages aldri. Løsningen er å normalisere til `NOT NULL` i forbered-steget – ikke `ISNULL` på begge sider i hver sammenligning.

### Oppgave V (viderekommen): `etl.LastFaktSalg`

Skriv faktalastingen:
1. Karantene (Feil): ordrer med dato i fremtiden, linjer med `Antall <= 0`. Disse skal **ikke** lastes
2. Slå opp surrogatnøkler for **riktig versjon** (`Ordredato BETWEEN GyldigFra AND GyldigTil`), `-1` for ukjent, og logg Advarsel for hver `-1`
3. Beregn `BruttoBelop`, `RabattBelop`, `NettoBelop`, `Kostnad` (antall × innkjøpspris *fra dimensjonsversjonen*)
4. Fordel frakt (koden fra samling 2 lab V)
5. Upsert på `OrdrelinjeId` – rekjøring skal gi 0 innsatt, statusendring skal gi oppdatert
6. Logg

Test: full last → rekjør (0/0) → sett en ordre til `Returnert` i kilden → inkrementell kjøring → vis at faktaradene har ny `OrdreinfoKey`.

**Fasit V:** Del 7 i `03-etl.sql`. Gjennomgang av de vanskelige delene:

```sql
LEFT JOIN dw.DimKunde k ON k.KundeId = o.KundeId
                       AND CAST(o.Ordredato AS DATE) BETWEEN k.GyldigFra AND k.GyldigTil
```
- `LEFT JOIN` + `ISNULL(k.KundeKey, -1)`: ukjent kunde → ukjent-raden. `INNER JOIN` ville *mistet salget*.
- `BETWEEN GyldigFra AND GyldigTil` – ikke `ErGjeldende = 1`! En ordre fra 2024 skal peke på 2024-versjonen av kunden. Dette er grunnen til at `GyldigTil = '9999-12-31'` (ikke `NULL`) er praktisk.
- Indeksen `UX_DimKunde_Versjon (KundeId, GyldigFra) INCLUDE (GyldigTil)` fra DDL-en er laget for akkurat dette oppslaget.

```sql
Kostnad = CAST(ol.Antall * ISNULL(p.Innkjopspris, 0) AS DECIMAL(12,2))
```
- Innkjøpsprisen kommer fra *dimensjonsversjonen på salgstidspunktet*, ikke fra kilden. Dermed gir `Dekningsbidrag` riktig margin også etter at innkjøpsprisen har endret seg. (Første last har bare én versjon av hvert produkt, så dette slår først inn over tid – si det.)

```sql
MERGE dw.FaktSalg AS t
USING (…#Linje med frakt…) AS s ON t.OrdrelinjeId = s.OrdrelinjeId
WHEN MATCHED AND (t.OrdreinfoKey <> s.OrdreinfoKey OR … ) THEN UPDATE SET …
WHEN NOT MATCHED BY TARGET THEN INSERT (…) VALUES (…)
OUTPUT $action INTO @Resultat;
```
- `MATCHED AND (noe er endret)`: oppdater bare rader som faktisk endret seg. Uten `AND` oppdateres alle matchende rader hver natt.
- `OUTPUT $action` → tell `INSERT` og `UPDATE` separat til loggen.
- **Ingen `WHEN NOT MATCHED BY SOURCE THEN DELETE`.** Spør: *«Hva ville skjedd?»* Kilden (`#Linje`) inneholder bare *endrede* ordrer. Alt som ikke er endret i natt, er «not matched by source» → **hele faktatabellen slettes unntatt nattens rader.** Dette er den farligste linjen i T-SQL for datavarehus. Sletting håndteres i 7.5 – begrenset til ordrer vi faktisk hentet.

### Oppgave U (utfordring): Slettinger og overvåkning

1. En ordrelinje slettes i kilden (ordren får ny `SistEndret`). Fanges det av din `LastFaktSalg`? Hvis ikke: fiks det.
2. En hel ordre slettes hardt (både `Ordre` og `Ordrelinje`). Fanges det? Hvorfor ikke? Skriv en egen avstemmingsprosedyre som finner og fjerner faktarader uten motpart i kilden, og diskuter hvor ofte den bør kjøre.
3. Skriv en overvåkningsspørring mot `etl.KjoringSteg` som flagger kjøringer der radantallet i `LastFaktSalg` avviker mer enn 50 % fra snittet av de sju forrige kjøringene.
4. I `etl.KjorAlt` skrives karantene- og steglogg *inne i* transaksjonen. Hva skjer med dem ved `ROLLBACK`? Er det et problem? Foreslå en løsning.

**Fasit U:**

1. Steg 7.5: `DELETE f FROM dw.FaktSalg f WHERE EXISTS (ordren er i stg.Ordre) AND NOT EXISTS (linjen er i #Linje)`. Begrenset til ordrer vi hentet, så det er trygt med inkrementell kilde. Fanger også linjer som er blitt ugyldige (antall satt til 0).

2. **Nei.** En hardslettet ordre har ingen rad i kilden med `SistEndret > vannmerke` – den er borte, og inkrementell lasting ser bare det som *finnes*. Dette er den fundamentale svakheten med vannmerkebasert lasting, og grunnen til at kilder bør bruke *soft delete* (`Slettet BIT`) eller CDC. Når kilden ikke gjør det: `etl.AvstemSlettinger` (del 8) henter *alle* nøkler fra kilden (bare `OrdrelinjeId`, 580 000 × 4 byte = 2 MB – billig) og sletter fakta uten motpart. Kjør den ukentlig eller etter behov, ikke hver natt, fordi den skalerer med hele kilden. Demoen: kjøring 4 med `@MedAvstemming = 1` fant og fjernet de tre linjene fra den hardslettede ordren, og loggførte dem i karantene som Info.

3.
```sql
WITH Steg AS (
    SELECT s.KjoringId, s.Steg, s.RaderInnsatt + s.RaderOppdatert AS Rader,
           AVG(CAST(s.RaderInnsatt + s.RaderOppdatert AS FLOAT))
               OVER (PARTITION BY s.Steg ORDER BY s.KjoringId ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS Snitt7
    FROM etl.KjoringSteg s
    JOIN etl.Kjoring k ON k.KjoringId = s.KjoringId
    WHERE k.Status = N'OK' AND k.Jobb <> N'Full last'
)
SELECT KjoringId, Steg, Rader, CAST(Snitt7 AS DECIMAL(10,1)) AS Snitt7,
       CASE WHEN Snitt7 IS NULL                              THEN 'Ingen historikk'
            WHEN Snitt7 = 0 AND Rader > 0                    THEN 'AVVIK: var 0'
            WHEN Snitt7 > 0 AND ABS(Rader - Snitt7) / Snitt7 > 0.5 THEN 'AVVIK > 50 %'
            ELSE 'OK' END AS Vurdering
FROM Steg
WHERE Steg = N'LastFaktSalg'
ORDER BY KjoringId;
```
- `ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING`: de sju *forrige* kjøringene, ikke inkludert denne. (Vindusfunksjoner er neste ukes tema – dette er en smakebit.)
- Ekskluder full last fra snittet, ellers ødelegger 580 000 referansen.
- I praksis: legg dette i en jobb som sender e-post/Teams-melding ved AVVIK. De fleste kildefeil («noen slettet alle ordrer fra i går ved en feil», «API-et returnerte tom liste») viser seg som radantall nær 0.

4. Ved `ROLLBACK` forsvinner karantene- og stegrader for den feilede kjøringen – bare `etl.Kjoring`-raden (skrevet før `BEGIN TRY`) overlever, med `Status = 'Feil'` og `Feilmelding`. Det er **akseptabelt for steglogg** (kjøringen gjorde jo ingenting), men **tap av karantenerader er uheldig**: hvis årsaken til feilen *var* dårlige data, er sporene borte. Løsninger: (a) skriv karantene *før* transaksjonen starter (krever at valideringen skilles ut i et eget steg – god arkitektur uansett); (b) bruk en tabellvariabel for karantene og `INSERT` den etter `ROLLBACK` i `CATCH` (tabellvariabler påvirkes ikke av rollback); (c) i ekte systemer: logg over en separat tilkobling (loopback linked server, eller la orkestreringsverktøyet logge). Demoen: kjøring 6 (sabotert med en `CHECK`-begrensning) viser `Status = 'Feil'`, uendret vannmerke, uendrede fakta – og ingen stegrader.

---

## Bolk 4 (2:45–3:00): Plenum og avslutning

### Gjennomgang (7 min)

Vis hele `etl.KjorAlt` (del 9) og forklar de tre linjene studentene oftest hopper over:
- `SET XACT_ABORT ON` – gjør at *enhver* feil (også de som normalt bare gir en advarsel) avbryter transaksjonen. Uten den kan en feil i én setning la transaksjonen fortsette i udefinert tilstand.
- `EXEC etl.Extract` *utenfor* `BEGIN TRANSACTION` – staging er engangsdata; vi vil ikke holde en transaksjon åpen mot kilden i 10 sekunder.
- `THROW` til slutt i `CATCH` – ellers tror jobbplanleggeren (SQL Agent, ADF, Airflow) at alt gikk bra.

### Python/pandas-innslag (5 min)

Vis samme SCD2-logikk i pandas, bare for å avmystifisere:

```python
import pandas as pd
stg = pd.read_sql("SELECT * FROM stg.Kunde", con)                   # extract → staging (allerede gjort)
dim = pd.read_sql("SELECT * FROM dw.DimKunde WHERE ErGjeldende = 1", con)

m = stg.merge(dim, on="KundeId", how="left", suffixes=("", "_dw"))
nye     = m[m["KundeKey"].isna()]                                    # finnes ikke → INSERT
endret  = m[(m["KundeKey"].notna()) & (m["Postnummer"] != m["Postnummer_dw"])]   # type 2-endring

# Utløp gamle, sett inn nye – skrives tilbake med to SQL-setninger eller to to_sql-kall
```
Poenget: *stegene er identiske*. Forbered, sammenlign mot gjeldende, utløp, sett inn. Verktøyet er sekundært. Det SQL har som pandas mangler: transaksjonen – i pandas må du selv sørge for at utløp og innsetting enten begge skjer eller ingen.

### Diskusjon (3 min)

*«En feilrad i karantene er fortsatt en feil ingen ser på. Hvem skal få varselet, og hva skal de gjøre?»* – Styr mot: Feil-rader → systemeier for kilden (de må rette). Advarsel-rader → dataeier (de må bestemme regel). Info-rader → ingen, men tell dem i et dashbord. Og: karantene uten `Behandlet`-flagg og uten eier er bare en logg.

### Hjemmearbeid

1. Fullfør lab V og U. Dette er kjernen i **mappeinnlevering 2** (leveres etter samling 4): fungerende `etl.*`-prosedyrer + testdokumentasjon på formen «vi endret X i kilden, kjørte, og fikk Y i DW» for minst fem scenarier (ny kunde, flyttet kunde, ny pris, statusendring, slettet linje).
2. Les Ben-Gan, *T-SQL Window Functions*, kap. 1–2 (ca. 60 sider). Neste uke er vindusfunksjoner – dere har allerede brukt tre (`SUM() OVER`, `ROW_NUMBER()`, `AVG() OVER … ROWS BETWEEN`).

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| Fakta lastes før dimensjoner | Rekkefølgen er ikke forstått | Alle nøkler blir `-1`. La dem se det |
| `JOIN dw.DimKunde k ON k.KundeId = o.KundeId AND k.ErGjeldende = 1` i faktalastingen | Blander «sammenlign med siste tilstand» (dimensjonslasting) med «finn versjonen på salgstidspunktet» (faktalasting) | Vis at alle kunde 1s ordrer peker på Tromsø etter flyttingen – inkludert de fra 2023 |
| `INNER JOIN` i nøkkeloppslaget | Mister salg med ukjent kunde/produkt | Tell rader i `#Linje` mot `stg.Ordrelinje` |
| Vannmerke = `MAX(SistEndret)` | Tidslinjen fra bolk 1 | Tegn den igjen |
| Vannmerke oppdateres før/utenfor transaksjonen | Feil → neste kjøring hopper over rader | Kjøring 6-demoen: vannmerket står stille |
| `THROW` i valideringssteget | Én dårlig rad stopper hele lastingen | Karantene med Alvor |
| Karantene uten `NOT EXISTS` | Samme avvik logges hver natt | Vis tabellen etter tre kjøringer |
| `WHERE d.Merke <> p.Merke` med `NULL` på én side | Endringer oppdages ikke | Normaliser til `NOT NULL` i forbered-steget |
| Type 1-oppdatering bare på `ErGjeldende = 1` | Gamle versjoner beholder stavefeilen | Rapport 4 viser «to» personer |
| `GyldigTil = @LastDato` (ikke i går) | Overlapp: dagens dato matcher to versjoner | `BETWEEN` returnerer to rader → fakta dobles |
| `WHEN NOT MATCHED BY SOURCE THEN DELETE` | Sletter alt som ikke er i nattens batch | Still spørsmålet før noen kjører det. Ta backup først hvis du vil demonstrere |
| Ren `INSERT` i faktalastingen | Dubletter ved rekjøring | «Kjør den to ganger»-testen. `UX_FaktSalg_Ordrelinje` feiler – det er derfor den finnes |
| `MERGE` med dubletter i kilden | «attempted to UPDATE or DELETE the same row more than once» | Dedupliser i staging/forbered. Her: `OrdrelinjeId` er unik i kilden, så det skjer ikke – men i andre kilder gjør det det |
| Tabellvariabel for `#Linje` | 580 000 rader estimeres som 1 → elendig plan | Samling 6. Bruk temp-tabell |
| Glemmer `SET QUOTED_IDENTIFIER ON` | Prosedyren feiler ved `MERGE` mot tabell med filtrert indeks | Øverst i skriptet |

---

## Vedlegg: hurtigreferanse for læreren

**Verifiserte tall** (SQL Server 2022, laptop):

| Kjøring | Hva | Resultat |
|---|---|---|
| 1 – full last | 781 343 rader lest, 5 050 + 800 dimensjonsrader, 580 057 faktarader | 42 s (Extract 9 s, FaktSalg 31 s) |
| 2 – rekjøring | Ingen endringer | 0 / 0 / 0 i alle steg |
| 3 – inkrementell etter 5 endringer | 1 ny kundeversjon, 1 ny produktversjon (+ 2 type 1-oppdateringer), 1 faktarad innsatt, 5 oppdatert, 1 slettet | < 2 s |
| 4 – med avstemming | 3 faktarader fra hardslettet ordre fjernet | |
| 5 – endring samme dag | Overskriver versjon fra i dag, ingen ny rad | |
| 6 – sabotert med `CHECK` | `Status = 'Feil'`, vannmerke og fakta uendret | |

**Karantene etter full last:**

| Kilde | Regel | Alvor | Antall |
|---|---|---|---|
| Kunde | Postnummer korrigert automatisk | Info | 102 |
| Kunde | Postnummer mangler | Info | 141 |
| Kunde | Mulig dublett | Info | ~300 |
| Produkt | Kategori mangler / slettet kategori | Advarsel | 19 + 7 |
| Produkt | Merke normalisert | Info | 25 |
| Produkt | Salgspris < innkjøpspris | Advarsel | 22 |
| Ordre | Ordredato i fremtiden | Feil | 150 |
| Ordrelinje | Antall ≤ 0 | Feil | 1 174 |

580 057 = 581 675 linjer − 1 174 (antall ≤ 0) − 444 (linjer på de 150 fremtidsordrene).

**Hvis noe går galt:**
- *`Invalid object name 'NordhandelShop.dbo.Kunde'`*: Databasen heter noe annet, eller studenten kjører mot en annen instans. Extract er det eneste stedet kildenavnet forekommer – vis at det er lett å bytte til linked server eller en fil.
- *`MERGE statement conflicted with …`*: Studenten har egne `CHECK`-begrensninger. Les `etl.Kjoring.Feilmelding` – det er derfor den finnes.
- *Alle `KundeKey = -1`*: Fakta lastet før dimensjoner, eller `GyldigFra` for nye kunder satt til i dag i stedet for 1900-01-01.
- *Dobbelt antall faktarader etter andre kjøring*: `UX_FaktSalg_Ordrelinje` mangler (egen DDL) og lastingen er ren `INSERT`.
