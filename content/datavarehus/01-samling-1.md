---
title: "Samling 1 – Fra kildesystem til datavarehus"
description: "Hvorfor datavarehus? OLTP vs. OLAP, arkitektur, data marts og data lake vs. data warehouse."
order: 2
---

# Samling 1 – Fra kildesystem til datavarehus: hvorfor og hvordan

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Studentene har SQL Server + SSMS installert og har kjørt `case/00-oltp-skjema.sql` og `case/01-oltp-testdata.sql` før samlingen.
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.1, tavle/whiteboard, prosjektor med SSMS.

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Forklare minst fire konkrete grunner til at man ikke rapporterer rett fra OLTP-databasen, med eksempler fra Nordhandel
- (b) Tegne en trelags datavarehusarkitektur (staging, kjerne, mart) og forklare hva hvert lag gjør og hvorfor det finnes
- (c) Plassere data lake, data warehouse og data mart i en arkitekturskisse og gi ett eksempel på når hver er riktig valg
- (d) Analysere et kildeskjema og identifisere kandidater til fakta og dimensjoner
- (e) Skrive SQL som avdekker datakvalitetsproblemer i en kildedatabase (nullverdier, format, referanser, dubletter, logiske feil)

---

## Før samlingen: sjekkliste til studentene

Send ut én uke før. Erfaringsmessig bruker 20 % av studentene hele første time på installasjon hvis dette ikke er gjort på forhånd.

```
[ ] SQL Server 2022 Developer Edition installert
    – ELLER Docker: docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Passord123!" \
                     -p 1433:1433 --name nordhandel -d mcr.microsoft.com/mssql/server:2022-latest
[ ] SQL Server Management Studio (SSMS) eller Azure Data Studio installert
[ ] Koblet til serveren (localhost, Windows-autentisering eller sa/Passord123!)
[ ] Kjørt case/00-oltp-skjema.sql       (tar 1 sekund)
[ ] Kjørt case/01-oltp-testdata.sql     (tar 30–90 sekunder)
[ ] Verifisert med spørringen under – skal gi ca. 195 000 ordrer
```

```sql
USE NordhandelShop;
SELECT COUNT(*) AS AntallOrdrer, MIN(Ordredato) AS Forste, MAX(Ordredato) AS Siste FROM dbo.Ordre;
```

> **Lærernotat:** `MAX(Ordredato)` vil vise en dato i 2030 – det er de 150 fremtidsdaterte ordrene (kvalitetsfeil O1). Ikke kommenter det nå; la studentene oppdage det i bolk 2.

---

## Bolk 1 (0:00–0:45): Problemet

### 0:00–0:15 Introduksjon

**Si dette** (5 min): Presenter emnet med én setning: *«Dere skal bygge et datavarehus fra bunnen av for en nettbutikk, og lære hvorfor hvert eneste designvalg er som det er.»* Vis figuren fra `00-oversikt.md` kap. 1 (seks samlinger, én rød tråd). Forklar vurderingen (mappe 60 %, quiz 40 %) og at mappeinnlevering 1 bygger direkte på det de gjør i dag og neste uke.

**Sjekk oppsett** (5 min): Alle kjører verifiseringsspørringen. Gå rundt. De som mangler databasen, setter seg sammen med en som har den – de bruker pausen på installasjon.

**Presenter caset** (5 min): Vis ER-diagrammet for `NordhandelShop` (tegn det, eller bruk SSMS → Database Diagrams). Fem tabeller: `Kunde`, `Kategori`, `Produkt`, `Ordre`, `Ordrelinje`, pluss referansetabellen `Postnummer`. Si: *«Dette er en helt vanlig, godt normalisert nettbutikkdatabase. Den har ingenting galt med seg – som nettbutikk.»*

### 0:15–0:25 «Prøv selv»: månedsrapporten

**Oppgave til studentene (10 min, i par):**

> Markedssjefen i Nordhandel vil ha en rapport som viser **omsetning per måned per hovedkategori for 2025**. Hovedkategori er øverste nivå i kategorihierarkiet (Klær, Fottøy, Utstyr, Sekker). Skriv spørringen mot `NordhandelShop`.

**Lærernotat:** Ikke hjelp dem. Målet er at de skal kjenne på friksjonen. Typiske ting som skjer:
- De joiner `Produkt → Kategori` og får *Jakker*, *Telt* osv., ikke hovedkategori. Noen oppdager at `Kategori` er et hierarki og stopper opp.
- De bruker `Produkt.Salgspris` i stedet for `Ordrelinje.EnhetsprisEksMva` og får feil tall.
- De glemmer rabatt, eller tar med kansellerte ordrer, eller inkluderer frakt.
- Noen skriver `WHERE YEAR(Ordredato) = 2025` (helt greit nå – blir et poeng i samling 6).

Etter 10 min: *«Hvem fikk til hovedkategori? Hvem er sikre på at tallet er riktig?»* Få svar fra noen få par og noter frustrasjonene på tavla.

### 0:25–0:45 Gjennomgang: hva som egentlig kreves

**Demo 1.1 – rapporten slik den må skrives mot OLTP.** Kjør denne og gå gjennom den linje for linje:

```sql
USE NordhandelShop;

WITH Hierarki AS (
    -- Ankerdel: toppnivået i hierarkiet. Hver toppkategori er sin egen hovedkategori.
    SELECT KategoriId, Navn, ForelderId, Navn AS Hovedkategori, 1 AS Nivaa
    FROM dbo.Kategori
    WHERE ForelderId IS NULL

    UNION ALL

    -- Rekursiv del: gå nedover. Hvert barn arver Hovedkategori fra forelderen.
    SELECT k.KategoriId, k.Navn, k.ForelderId, h.Hovedkategori, h.Nivaa + 1
    FROM dbo.Kategori k
    JOIN Hierarki h ON h.KategoriId = k.ForelderId
)
SELECT
    YEAR(o.Ordredato)  AS Aar,
    MONTH(o.Ordredato) AS Maaned,
    ISNULL(h.Hovedkategori, 'Ukjent') AS Hovedkategori,
    SUM(ol.Antall * ol.EnhetsprisEksMva * (1 - ol.RabattProsent / 100.0)) AS Omsetning
FROM dbo.Ordre o
JOIN dbo.Ordrelinje ol  ON ol.OrdreId   = o.OrdreId
JOIN dbo.Produkt p      ON p.ProduktId  = ol.ProduktId
LEFT JOIN Hierarki h    ON h.KategoriId = p.KategoriId
WHERE o.Ordredato >= '2025-01-01' AND o.Ordredato < '2026-01-01'
  AND o.Status NOT IN ('Kansellert', 'Returnert')
GROUP BY YEAR(o.Ordredato), MONTH(o.Ordredato), ISNULL(h.Hovedkategori, 'Ukjent')
ORDER BY Aar, Maaned, Hovedkategori;
```

**Forklaring linje for linje** (si dette mens du peker):

| Del | Hva skjer | Hvorfor det er et problem |
|---|---|---|
| `WITH Hierarki AS (…)` | En **rekursiv CTE** (recursive common table expression) som går fra toppkategoriene og nedover og «drar med seg» navnet på toppnivået til hvert barn | En markedssjef i Power BI kan ikke skrive dette. Og det må skrives *på nytt i hver eneste rapport* som trenger hovedkategori |
| `WHERE ForelderId IS NULL` | Ankeret: start med rader uten forelder | Legg merke til at kategori 20 «SLETTET» også er en toppkategori – den blir en egen «hovedkategori» i rapporten. Er det riktig? |
| `UNION ALL … JOIN Hierarki h` | Rekursjonen: finn barn av det vi har så langt, gjenta til det ikke finnes flere | Fungerer, men er tungt å lese og vedlikeholde |
| `ISNULL(h.Hovedkategori, 'Ukjent')` | Produkter uten kategori (P1) ville forsvunnet med `INNER JOIN` | Hvem bestemte at det skal hete «Ukjent»? Neste analytiker skriver `'Mangler'`, og tallene stemmer ikke lenger med hverandre |
| `SUM(ol.Antall * ol.EnhetsprisEksMva * (1 - ol.RabattProsent / 100.0))` | Definisjonen av omsetning: antall × pris × (1 − rabatt) | Dette er **forretningslogikk kodet inn i en rapport**. Er omsetning med eller uten frakt? Eks. mva? Tre analytikere, tre definisjoner |
| `ol.EnhetsprisEksMva`, ikke `p.Salgspris` | Vi må bruke prisen på ordrelinjen, fordi `Produkt.Salgspris` er *dagens* pris | Vi var heldige: kilden lagret prisen på linjen. Det gjør den ikke med postnummer, kategori eller kundesegment |
| `AND o.Status NOT IN ('Kansellert', 'Returnert')` | Ekskluder ordrer som ikke ble til salg | Igjen en definisjon. Skal returnerte ordrer trekkes fra i den måneden de ble *solgt*, eller den måneden de ble *returnert*? Kilden har bare én status og én dato – den kan ikke svare |
| `WHERE o.Ordredato >= … AND < …` | Filtrer på 2025 | Dette er riktig skrevet. Men: det finnes ordrer i 2030 (O1). Skal de med? Rapporten skjuler dem stille |
| Hele spørringen | Leser alle ordrelinjer for 2025 med tre joins + rekursjon | Kjører mot **produksjonsdatabasen**, samtidig med kassesystemet |

**Demo 1.2 – blokkering (valgfri, 5 min, men svært effektiv).** Åpne to spørrevinduer.

Vindu A – simuler kassesystemet som er midt i en transaksjon:
```sql
BEGIN TRANSACTION;
UPDATE dbo.Ordre SET Status = 'Betalt' WHERE OrdreId = 1000;
-- IKKE kjør COMMIT ennå
```

Vindu B – kjør månedsrapporten fra Demo 1.1. Den **henger**. Forklar: under standard isolasjonsnivå (`READ COMMITTED`) venter rapporten på at kassesystemet skal bli ferdig. Snu det: la rapporten holde en lang lesing, og kassesystemet venter. *Dette er hva som skjer når analytikere kjører rapporter mot produksjon.* Kjør `ROLLBACK` i vindu A.

> **Lærernotat:** Dette virker fordi rapporten leser `Ordre` og treffer raden med `OrdreId = 1000` som er låst. Hvis den ikke henger (f.eks. fordi `READ_COMMITTED_SNAPSHOT` er på), si det heller: «på denne serveren er snapshot isolation slått på, som løser akkurat dette – men ikke de andre problemene».

**De tre umulige spørsmålene** (5 min). Avslutt bolken med å stille tre spørsmål rapportbestilleren garantert kommer med neste uke, og la studentene prøve å finne svaret i skjemaet:

1. *«Hva var salgsprisen på Norrøna Lofoten Pro i mars 2023?»* – `Produkt.Salgspris` er dagens pris. Vi kan gjette ut fra ordrelinjer *hvis* det ble solgt i mars 2023, men hvis ikke, er informasjonen borte for alltid.
2. *«Hvor mye solgte vi til kunder i Rogaland i 2023?»* – `Kunde.Postnummer` er dagens postnummer. En kunde som flyttet fra Stavanger til Oslo i 2024 får all sin 2023-omsetning flyttet til Oslo.
3. *«Hvorfor viser din rapport 14,2 millioner og økonomiavdelingens 13,8?»* – Fordi de ekskluderte frakt og du ikke gjorde det. Eller omvendt. Ingen vet.

Oppsummer på tavla: **ytelse/konflikt, manglende historikk, kompleksitet, definisjonskaos** – og legg til **flere kilder** (kommer i bolk 2). Dette er de fem grunnene fra `00-oversikt.md` 3.1.

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): Løsningen

### 0:55–1:20 Teori: OLTP vs. OLAP, Inmon og arkitektur

**OLTP vs. OLAP** (8 min). Tegn tabellen fra `00-oversikt.md` 3.1 med tom høyre kolonne og la studentene fylle ut. Nøkkelsetning: *«OLTP-systemet er optimalisert for å skrive én ordre riktig. Analysen trenger å lese en million ordrer raskt. Det er to forskjellige problemer, og de trenger to forskjellige databaser.»*

**Inmons definisjon** (7 min). Skriv de fire ordene og koble hvert til problemene fra bolk 1:

| Egenskap | Betyr | Løser |
|---|---|---|
| **Subject-oriented** | Organisert etter forretningsbegrep (kunde, produkt, salg), ikke etter applikasjon | Kompleksitet – «Salg» er én ting, ikke fem tabeller |
| **Integrated** | Data fra flere kilder er harmonisert: samme nøkler, samme koder, samme definisjon | Flere kilder, definisjonskaos |
| **Time-variant** | Hver rad er gyldig i et tidsrom; historikk bevares | Manglende historikk – de umulige spørsmålene 1 og 2 |
| **Non-volatile** | Data lastes inn og leses – oppdateres ikke av brukere | Ytelse/konflikt – ingen låser fra kassesystemet |

**Trelagsarkitekturen** (10 min). Tegn figuren fra `00-oversikt.md` 3.1 gradvis, ett lag om gangen, og still spørsmålet *«hvorfor ikke hoppe over dette laget?»* for hvert:

- **Staging** – *«Hvorfor ikke transformere rett fra kilden?»* Fordi (1) uttrekket kan feile midtveis, og da vil du ikke lese kilden på nytt; (2) kilden kan endre seg mens du transformerer, og du vil ha ett konsistent øyeblikksbilde; (3) når tallene er feil om tre uker, vil du se *hva kilden faktisk leverte den dagen*. Staging er en rå kopi, ofte uten indekser, ofte tømt før hver lasting.
- **Kjerne / DW** – *«Hvorfor ikke lage rapportene rett fra staging?»* Fordi staging ser ut som kilden – med alle problemene fra bolk 1. Kjernen er der vi (1) integrerer kilder, (2) legger på historikk, (3) fastsetter definisjoner én gang. Her bor stjerneskjemaet (samling 2).
- **Data mart / presentasjon** – *«Hvorfor ikke la alle lese kjernen?»* Fordi økonomi vil ha omsetning inkl. frakt og markedsføring vil ha det uten, og begge skal ha rett. En mart er en avgrenset, ofte forenklet utsikt for ett formål: et sett views, et Power BI-datasett eller en egen schema. **Konformerte dimensjoner** (conformed dimensions) – at alle marts deler samme `DimKunde` og `DimDato` – er det som gjør at tall fra økonomi og markedsføring kan legges side om side.

**Data lake, data warehouse, lakehouse** (må ikke ta mer enn 5 min – studentene vil gjerne diskutere dette i timevis). Bruk tabellen fra `00-oversikt.md` 3.1. Nøkkelsetning: *«Data lake er et lagringssted. Data warehouse er en modell. Dere kan bygge et stjerneskjema som Parquet-filer i en lake – da kaller vi det lakehouse. Det dere lærer i dette emnet, gjelder uansett hvor filene ligger.»*

### 1:20–1:40 Demo 1.3: Datakvalitet i kilden

**Si dette:** *«Før vi kan bygge noe, må vi vite hva vi bygger på. Datavarehusprosjekter feiler oftere på datakvalitet enn på teknologi. Nå skal vi være detektiver.»*

Kjør hver spørring, vis resultatet, og la studentene foreslå hva som er galt før du sier det.

**1.3a – Postnummer: lengde og format**
```sql
SELECT
    LEN(Postnummer)                                  AS Lengde,
    CASE WHEN Postnummer IS NULL              THEN 'NULL'
         WHEN Postnummer LIKE '%[^0-9]%'      THEN 'Inneholder ikke-siffer'
         WHEN LEN(Postnummer) <> 4            THEN 'Feil lengde'
         ELSE 'OK' END                               AS Vurdering,
    COUNT(*)                                         AS Antall,
    MIN(Postnummer)                                  AS Eksempel
FROM dbo.Kunde
GROUP BY LEN(Postnummer),
         CASE WHEN Postnummer IS NULL              THEN 'NULL'
              WHEN Postnummer LIKE '%[^0-9]%'      THEN 'Inneholder ikke-siffer'
              WHEN LEN(Postnummer) <> 4            THEN 'Feil lengde'
              ELSE 'OK' END
ORDER BY Antall DESC;
```
- `LIKE '%[^0-9]%'` – mønsteret `[^0-9]` betyr «ett tegn som ikke er et siffer». Fanger både bokstaven O (K2) og det etterfølgende mellomrommet (K4), så «Inneholder ikke-siffer» blir ca. 100 rader.
- `LEN(Postnummer) <> 4` fanger tapt ledende null (K3). Merk at `LEN()` **ignorerer etterfølgende mellomrom** – `LEN('0566 ')` = 4 – så lengdesjekken alene ville *ikke* fanget K4. Spør studentene: *«Hvordan skiller vi O-feilen fra mellomromsfeilen?»* → `DATALENGTH(Postnummer) <> DATALENGTH(RTRIM(Postnummer))` gir mellomrommene (ca. 50), resten er O-er. Poeng: verktøyene lyver litt; man må kjenne funksjonenes definisjon.
- Vi må gjenta `CASE` i `GROUP BY` fordi alias ikke kan brukes der (logisk evalueringsrekkefølge – `GROUP BY` kjører før `SELECT`). Alternativet er en CTE eller `CROSS APPLY` – vis gjerne begge hvis tid.

**1.3b – Postnummer som ikke finnes i registeret**
```sql
SELECT k.Postnummer, k.Poststed, COUNT(*) AS AntallKunder
FROM dbo.Kunde k
LEFT JOIN dbo.Postnummer p ON p.Postnummer = k.Postnummer
WHERE p.Postnummer IS NULL
  AND k.Postnummer IS NOT NULL
GROUP BY k.Postnummer, k.Poststed
ORDER BY AntallKunder DESC;
```
- Standardmønsteret for «finn rader uten match»: `LEFT JOIN` + `WHERE høyre.nøkkel IS NULL`.
- Legg merke til: `'0566 '` (med mellomrom) *matcher* `'0566'` i SQL Server fordi strengsammenligning ignorerer etterfølgende mellomrom. Men `'566'` og `'O566'` matcher ikke. Så den samme feilen kan være usynlig i én sjekk og synlig i en annen.
- Pek på at `k.Postnummer` er `NVARCHAR(10)` og `p.Postnummer` er `CHAR(4)`. Det fungerer, men koster – vi kommer tilbake til det i samling 6 (implisitt konvertering).

**1.3c – Produkter uten gyldig kategori**
```sql
SELECT
    CASE WHEN p.KategoriId IS NULL       THEN 'Mangler kategori'
         WHEN k.Navn LIKE 'SLETTET%'     THEN 'Peker på slettet kategori'
         ELSE 'OK' END                    AS Vurdering,
    COUNT(*)                              AS AntallProdukter,
    SUM(CASE WHEN p.Aktiv = 1 THEN 1 ELSE 0 END) AS HvoravAktive
FROM dbo.Produkt p
LEFT JOIN dbo.Kategori k ON k.KategoriId = p.KategoriId
GROUP BY CASE WHEN p.KategoriId IS NULL       THEN 'Mangler kategori'
              WHEN k.Navn LIKE 'SLETTET%'     THEN 'Peker på slettet kategori'
              ELSE 'OK' END;
```
- Fremmednøkkelen garanterer at `KategoriId` enten er `NULL` eller finnes. Den garanterer *ikke* at kategorien er en det gir mening å bruke. «Slettet»-kategorien er typisk: noen ville rydde, turte ikke slette pga. FK, og omdøpte den i stedet.
- `SUM(CASE WHEN … THEN 1 ELSE 0 END)` er det klassiske mønsteret for «tell de som oppfyller et vilkår» – studentene bør kunne det utenat. (Fra SQL Server 2022: `COUNT_IF` finnes ikke, men `COUNT(CASE WHEN … THEN 1 END)` gjør det samme.)

**1.3d – Inkonsistente merkenavn (og hvorfor databasen skjuler dem)**

Kjør først den «opplagte» spørringen:
```sql
SELECT Merke, COUNT(*) AS Antall
FROM dbo.Produkt
WHERE Merke IS NOT NULL
GROUP BY Merke
ORDER BY Merke;
```
- Resultatet ser rent ut: ni merker. Men se på etikettene – noen står i STORE BOKSTAVER («HILLEBERG», «FJÄLLRÄVEN») og «Bergans» har et mellomrom bak seg. Spør: *«Hvorfor skriver databasen Hilleberg med store bokstaver?»*
- Svar: databasens **kollasjon** (collation) er `SQL_Latin1_General_CP1_CI_AS` – `CI` betyr *case-insensitive*. `GROUP BY` ser «Hilleberg» og «HILLEBERG» som samme verdi og velger en vilkårlig representant som etikett. Etterfølgende mellomrom ignoreres *alltid* ved sammenligning i SQL Server (uavhengig av kollasjon), så «Bergans » og «Bergans» slås også sammen. Vis med `SELECT CAST(DATABASEPROPERTYEX('NordhandelShop', 'Collation') AS NVARCHAR(100))`.

Avslør så variantene ved å tvinge binær sammenligning og skille på bytelengde:
```sql
SELECT '[' + Merke + ']' AS Merke, COUNT(*) AS Antall, DATALENGTH(Merke) AS Bytes
FROM (SELECT Merke COLLATE Latin1_General_BIN2 AS Merke
      FROM dbo.Produkt
      WHERE Merke IS NOT NULL) x
GROUP BY Merke, DATALENGTH(Merke)
ORDER BY UPPER(TRIM(Merke)), Merke, Bytes;
```
- `COLLATE Latin1_General_BIN2` i den avledede tabellen gjør at `GROUP BY` sammenligner byte for byte → store og små bokstaver blir ulike grupper. (Den må stå i en avledet tabell eller CTE fordi `SELECT`-listen ellers refererer en annen kollasjon enn `GROUP BY`.)
- `DATALENGTH(Merke)` i `GROUP BY` skiller «Bergans» (14 byte) fra «Bergans » (16 byte) – det er den eneste måten å få `GROUP BY` til å se trailing space på.
- `'[' + Merke + ']'` gjør mellomrommet synlig i resultatet.
- Nå vises 23 varianter i stedet for 9. Sorteringen på `UPPER(TRIM(Merke))` legger dem ved siden av hverandre.
- **Poenget**: datakvalitet er ikke bare «hva som ligger i cellen», men «hva databasen gjør med det». SQL Server med CI-kollasjon gjemmer feilen; Python, Snowflake eller en case-sensitive database ser 23 merker, og Power BI-slicere får 23 valg. Datavarehuset må normalisere eksplisitt (`UPPER(TRIM(...))`, eller bedre: en oppslagstabell over godkjente merkenavn) så det er likt *uansett* hvor dataene leses.

**1.3e – Logiske feil i ordrer**
```sql
SELECT 'Ordredato i fremtiden'       AS Feil, COUNT(*) AS Antall
FROM dbo.Ordre WHERE Ordredato > SYSDATETIME()
UNION ALL
SELECT 'Ordre uten betalingsmåte',           COUNT(*)
FROM dbo.Ordre WHERE Betalingsmate IS NULL
UNION ALL
SELECT 'Ordrelinje med antall <= 0',         COUNT(*)
FROM dbo.Ordrelinje WHERE Antall <= 0
UNION ALL
SELECT 'Produkt med salgspris < innkjøp',    COUNT(*)
FROM dbo.Produkt WHERE Salgspris < Innkjopspris
UNION ALL
SELECT 'Ordre før kunden ble opprettet',     COUNT(*)
FROM dbo.Ordre o JOIN dbo.Kunde k ON k.KundeId = o.KundeId
WHERE o.Ordredato < k.Opprettet;
```
- `UNION ALL` av enkle tellinger er en lettvint «kvalitetsrapport». Dette blir utgangspunktet for lab-oppgaven og, i samling 3, for valideringssteget i ETL.
- Diskuter hver linje: *Er dette en feil i dataene, eller en feil i vår forståelse?* «Ordre uten betalingsmåte» kan være lovlig for ordrer med status `Ny`. «Salgspris < innkjøp» kan være bevisst (lokkevare). «Ordre før kunden ble opprettet» er sannsynligvis en migreringsfeil. **Datakvalitet krever domenekunnskap** – SQL finner avvikene, mennesker avgjør om de er feil.

**1.3f – Prishistorikken som ikke finnes**
```sql
SELECT TOP (1) p.ProduktId, p.Navn, p.Salgspris AS DagensPris,
       (SELECT COUNT(DISTINCT ol.EnhetsprisEksMva)
        FROM dbo.Ordrelinje ol WHERE ol.ProduktId = p.ProduktId) AS AntallUlikePriserISalg
FROM dbo.Produkt p
ORDER BY (SELECT COUNT(*) FROM dbo.Ordrelinje ol WHERE ol.ProduktId = p.ProduktId) DESC;

-- Sett inn ProduktId fra forrige resultat:
SELECT YEAR(o.Ordredato) AS Aar, MONTH(o.Ordredato) AS Maaned,
       MIN(ol.EnhetsprisEksMva) AS Lavest, MAX(ol.EnhetsprisEksMva) AS Hoyest, COUNT(*) AS Linjer
FROM dbo.Ordrelinje ol
JOIN dbo.Ordre o ON o.OrdreId = ol.OrdreId
WHERE ol.ProduktId = 1   -- <-- bytt ut
GROUP BY YEAR(o.Ordredato), MONTH(o.Ordredato)
ORDER BY Aar, Maaned;
```
- Første spørring finner det mest solgte produktet og teller hvor mange ulike priser det er solgt for. Svaret er typisk 100+ – prisen har endret seg mange ganger.
- Andre spørring viser prisen over tid – og at den stiger fra ~80 % til 100 % av dagens pris. Men vi kan bare se dette fordi *noen kjøpte produktet* den måneden. For et produkt uten salg i mars 2023 er prisen i mars 2023 **ukjent for alltid**.
- Dette er det sterkeste argumentet for et datavarehus med historikk: **kilden glemmer. Datavarehuset husker.** I samling 2 lærer vi teknikken (SCD type 2), i samling 3 implementerer vi den.

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:45): Lab 1

Grupper på 2–3. Alle gjør **G**. De fleste rekker **V**. **U** er for grupper som er ferdige, og kan fullføres hjemme. Fasit deles ut etter plenum.

### Oppgave G (grunnleggende): Kvalitetsrapport for `NordhandelShop`

Skriv én spørring (bruk `UNION ALL`-mønsteret fra demo 1.3e) som gir en rad per kontroll med kolonnene `Kontroll`, `Antall` og `Prosent` (andel av tabellen kontrollen gjelder). Kontrollene skal dekke:

1. Kunder uten postnummer
2. Kunder med postnummer som ikke finnes i `Postnummer`-registeret (ekskluder `NULL`)
3. Kunder uten kundesegment
4. Produkter uten kategori eller med kategori som heter `SLETTET%`
5. Produkter uten merke
6. Ordrer med dato i fremtiden
7. Ordrelinjer med `Antall <= 0`
8. Ordrelinjer der ordren er `Kansellert` – er dette en feil? Svar i en kommentar.

**Fasit G:**
```sql
USE NordhandelShop;

WITH Antall AS (
    SELECT (SELECT COUNT(*) FROM dbo.Kunde)      AS Kunder,
           (SELECT COUNT(*) FROM dbo.Produkt)    AS Produkter,
           (SELECT COUNT(*) FROM dbo.Ordre)      AS Ordrer,
           (SELECT COUNT(*) FROM dbo.Ordrelinje) AS Linjer
),
Kontroller AS (
    SELECT 1 AS Nr, 'Kunder uten postnummer' AS Kontroll, COUNT(*) AS Antall, 'Kunder' AS Tabell
    FROM dbo.Kunde WHERE Postnummer IS NULL
    UNION ALL
    SELECT 2, 'Kunder med ukjent postnummer', COUNT(*), 'Kunder'
    FROM dbo.Kunde k
    LEFT JOIN dbo.Postnummer p ON p.Postnummer = k.Postnummer
    WHERE k.Postnummer IS NOT NULL AND p.Postnummer IS NULL
    UNION ALL
    SELECT 3, 'Kunder uten segment', COUNT(*), 'Kunder'
    FROM dbo.Kunde WHERE Kundesegment IS NULL
    UNION ALL
    SELECT 4, 'Produkter uten gyldig kategori', COUNT(*), 'Produkter'
    FROM dbo.Produkt p
    LEFT JOIN dbo.Kategori k ON k.KategoriId = p.KategoriId
    WHERE p.KategoriId IS NULL OR k.Navn LIKE 'SLETTET%'
    UNION ALL
    SELECT 5, 'Produkter uten merke', COUNT(*), 'Produkter'
    FROM dbo.Produkt WHERE Merke IS NULL
    UNION ALL
    SELECT 6, 'Ordrer med dato i fremtiden', COUNT(*), 'Ordrer'
    FROM dbo.Ordre WHERE Ordredato > SYSDATETIME()
    UNION ALL
    SELECT 7, 'Ordrelinjer med antall <= 0', COUNT(*), 'Linjer'
    FROM dbo.Ordrelinje WHERE Antall <= 0
    UNION ALL
    SELECT 8, 'Ordrelinjer på kansellerte ordrer', COUNT(*), 'Linjer'
    FROM dbo.Ordrelinje ol
    JOIN dbo.Ordre o ON o.OrdreId = ol.OrdreId
    WHERE o.Status = 'Kansellert'
)
SELECT k.Nr, k.Kontroll, k.Antall,
       CAST(100.0 * k.Antall /
            CASE k.Tabell WHEN 'Kunder'    THEN a.Kunder
                          WHEN 'Produkter' THEN a.Produkter
                          WHEN 'Ordrer'    THEN a.Ordrer
                          ELSE a.Linjer END
            AS DECIMAL(5,2)) AS Prosent
FROM Kontroller k
CROSS JOIN Antall a
ORDER BY k.Nr;
```

**Løsningsforklaring:**
- CTE-en `Antall` henter totalene én gang. `CROSS JOIN` mot en én-rads CTE er et vanlig triks for å gjøre konstanter tilgjengelige i alle rader.
- `100.0 *` (ikke `100 *`) tvinger desimalaritmetikk. `100 * 150 / 195000` gir `0` i heltallsdivisjon – en klassisk feil som flere grupper vil gjøre.
- Kontroll 8: **Nei, dette er ikke en feil.** En kansellert ordre har fortsatt linjer – det er det som ble kansellert. Det er heller et *definisjonsspørsmål* for datavarehuset: skal kansellerte linjer være med i `FaktSalg` (med et flagg) eller filtreres bort i ETL? Vi tar dette i samling 2. Poenget med oppgaven er å øve skillet mellom *datafeil* og *forretningsregel*.
- Forventede tall (varierer litt fordi testdataene er tilfeldige): 1: ~3 %, 2: ~1 %, 3: ~10 %, 4: ~3,5 %, 5: ~4 %, 6: 150 stk, 7: ~0,2 %, 8: ~5 %.

### Oppgave V (viderekommen): Klassifiser kilden

Lag en tabell (i Markdown, Excel eller på papir) med én rad per kolonne i `NordhandelShop`, og klassifiser hver som:

- **Faktum** (fact / measure) – et tall som gir mening å summere eller snitte
- **Dimensjonsattributt** – noe man filtrerer eller grupperer på
- **Nøkkel** – identifikator (forretningsnøkkel eller fremmednøkkel)
- **Teknisk / ikke relevant** for analyse

Begrunn de vanskelige tilfellene med én setning. Svar deretter: hvilken tabell er kandidat til faktatabell, og hvilke blir dimensjoner?

**Fasit V:**

| Tabell.Kolonne | Klasse | Kommentar |
|---|---|---|
| `Kunde.KundeId` | Nøkkel | Forretningsnøkkel til `DimKunde` |
| `Kunde.Epost` | Dimensjonsattributt (sensitivt) | Identifiserende – vurder om den skal inn i DW i det hele tatt (GDPR). Kan brukes til dublettdeteksjon i ETL |
| `Kunde.Fornavn`, `Etternavn` | Dimensjonsattributt (sensitivt) | Samme vurdering |
| `Kunde.Postnummer`, `Poststed` | Dimensjonsattributt | Grunnlag for geografi (kommune, fylke via register). **Endrer seg** → SCD type 2-kandidat |
| `Kunde.Kundesegment` | Dimensjonsattributt | Endrer seg sjelden; SCD type 1 eller 2 – diskuteres i samling 2 |
| `Kunde.Opprettet` | Dimensjonsattributt / teknisk | «Kunde siden»-dato er nyttig for kohortanalyse. Men vi så den er upålitelig (K7) |
| `Kunde.SistEndret` | Teknisk | Brukes av ETL for inkrementell lasting (vannmerke), ikke i rapporter |
| `Kategori.*` | Dimensjonsattributt | Flates ut i `DimProdukt` som Hovedkategori / Kategori / Underkategori |
| `Produkt.ProduktId`, `Varenummer` | Nøkkel | Forretningsnøkler. `Varenummer` er den brukerne kjenner igjen |
| `Produkt.Navn`, `Merke` | Dimensjonsattributt | Type 1 (stavefeil rettes, ingen trenger gammelt navn) |
| `Produkt.Innkjopspris`, `Salgspris` | **Begge deler** | Dette er det vanskelige tilfellet. Som attributt i `DimProdukt`: «hva er listeprisen nå/da» (SCD type 2). Som faktum i `FaktSalg`: «hva var kostnaden for akkurat denne linjen» (`Antall × Innkjopspris` på salgstidspunktet). I praksis gjør man ofte begge |
| `Produkt.Aktiv` | Dimensjonsattributt | Flagg |
| `Ordre.OrdreId` | Nøkkel | Blir **degenerert dimensjon** (degenerate dimension) i `FaktSalg` – ordrenummeret ligger i faktatabellen uten egen dimensjonstabell, så man kan telle ordrer og gruppere linjer |
| `Ordre.KundeId` | Nøkkel (FK) | Erstattes av surrogatnøkkel `KundeKey` i fakta |
| `Ordre.Ordredato` | Nøkkel (FK) til datodimensjon | Blir `OrdreDatoKey`. Klokkeslettet: egen tidsdimensjon eller droppes |
| `Ordre.Status`, `Betalingsmate`, `Kanal` | Dimensjonsattributt | Tre små attributter med få verdier → **junk dimension** `DimOrdreinfo` (samling 2) |
| `Ordre.Fraktkostnad` | Faktum – men på **ordrenivå** | Problem: kornet i `FaktSalg` er ordrelinje. Frakten må enten fordeles på linjene (allokeres), legges i egen `FaktOrdre`, eller bare telles på første linje. Dette er lab-oppgave V i samling 2 |
| `Ordre.SistEndret` | Teknisk | Vannmerke |
| `Ordrelinje.OrdrelinjeId` | Nøkkel | Forretningsnøkkel for faktaraden – brukes av ETL for å unngå dubletter |
| `Ordrelinje.Antall` | **Faktum** | Additivt |
| `Ordrelinje.EnhetsprisEksMva` | **Faktum** (ikke-additivt) | Man summerer ikke enhetspriser. Men `Antall × Pris` = bruttobeløp er additivt – det beregnes i ETL og lagres som egen kolonne |
| `Ordrelinje.RabattProsent` | **Faktum** (ikke-additivt) | Samme: lagre `Rabattbeløp` = `Antall × Pris × Rabatt%` som additivt faktum |

**Konklusjon:** `Ordrelinje` (+ `Ordre` for dato, kunde, status) → `FaktSalg`. `Kunde` → `DimKunde`. `Produkt` + `Kategori` → `DimProdukt`. `Ordredato` → `DimDato`. `Status`/`Betalingsmate`/`Kanal` → `DimOrdreinfo`.

**Lærernotat:** De fleste grupper klassifiserer `Salgspris` som bare faktum eller bare attributt. Det er den beste anledningen i hele emnet til å forklare at *samme tall kan ha to roller avhengig av spørsmålet*: «hva koster produktet» (attributt) vs. «hva tjente vi på denne linjen» (faktum). Bruk tid på det i plenum.

### Oppgave U (utfordring): Arkitektur med flere kilder

Nordhandel kjøper CRM-systemet HubSpot. Der ligger kundene også – med egen `ContactId`, e-post, telefon, «lead source» og en salgsansvarlig. ~70 % av kundene finnes i begge systemer, matchet på e-post (men e-post er skrevet med ulik bruk av store/små bokstaver). I tillegg kommer det en månedlig Excel-fil fra regnskapsbyrået med faktisk innbetalt beløp per ordre.

Tegn en arkitektur (staging → kjerne → mart) som håndterer alle tre kildene. Svar på:
1. Hvor skjer matchingen av kunder på e-post, og hvorfor der?
2. Hva gjør dere med kunder som bare finnes i ett av systemene?
3. Excel-filen gir «innbetalt beløp» per ordre, mens vår `FaktSalg` er per ordrelinje. Hvor i arkitekturen løses det, og hvordan?
4. Bør Excel-filene lagres i en data lake? Hvorfor/hvorfor ikke?

**Fasit U (eksempel på godt svar):**

```
Kilder                   Staging (rått, 1:1)          Kjerne (integrert)             Mart
─────────────────        ────────────────────         ─────────────────────          ───────────────
NordhandelShop  ──SQL──► stg.Shop_Kunde          ┐
                         stg.Shop_Ordre          │    dw.DimKunde                    mart.vSalg
                         stg.Shop_Ordrelinje     │      (KundeKey, ShopKundeId,       mart.vKundeoversikt
                         stg.Shop_Produkt        ├──►    CrmContactId, Epost,         mart.vInnbetaling
HubSpot CRM     ──API──► stg.Crm_Contact         │       Fylke, Segment, LeadSource,
                                                 │       Salgsansvarlig, GyldigFra/Til)
Regnskap (xlsx) ──fil──► stg.Regnskap_Innbetaling┘    dw.DimProdukt, dw.DimDato, dw.DimOrdreinfo
   │                                                   dw.FaktSalg        (korn: ordrelinje)
   └─► lake/regnskap/2025/11/innbetalinger.xlsx        dw.FaktInnbetaling (korn: ordre × innbetalingsdato)
       (arkiv av originalfilen)
```

1. **Matchingen skjer i lastingen fra staging til kjerne** (`etl.LastDimKunde`). Ikke i staging – staging skal være rå. Ikke i mart – da ville hver mart matche ulikt. Kjernen er *definert* som stedet integrasjon skjer (Inmon: *integrated*). Teknisk: `LOWER(TRIM(Epost))` på begge sider før join, lagre begge kilde-ID-er i `DimKunde`.
2. Kunder som bare finnes i Shop: lastes med `CrmContactId = NULL`, `LeadSource = 'Ukjent'`. Kunder som bare finnes i CRM (leads som aldri kjøpte): lastes også – de er gyldige dimensjonsrader uten fakta, og nødvendige for «konverteringsrate»-rapporter. Alle kundene får én `KundeKey` uansett hvor mange kilder de finnes i. Det er hele poenget med surrogatnøkkelen.
3. **Egen faktatabell** `FaktInnbetaling` med korn «én rad per ordre per innbetaling». Ikke forsøk å presse det inn i `FaktSalg` – kornet er ulikt (ordre vs. linje), og en ordre kan ha flere delinnbetalinger. De to faktatabellene deler `DimKunde`, `DimDato` og den degenererte dimensjonen `OrdreId`, så man kan sammenligne «fakturert» og «innbetalt» per kunde per måned (det kalles *drill-across*). Dette er konformerte dimensjoner i praksis.
4. **Ja, arkiver originalfilen.** Excel-filer er upålitelige (noen redigerer dem, kolonner bytter plass). Når tallene er feil om fire måneder, vil du se nøyaktig hva regnskapsbyrået sendte. Et «lake»-lag (blob storage / filmappe med dato i stien) er den riktige plassen for rådata i originalformat. Men: filen *lastes fremdeles inn* i staging og modelleres i kjernen. Lake er arkivet, ikke rapportkilden.

**Vurdering av U:** Godt svar har (a) matching i kjernen, (b) begge ID-er bevart, (c) egen faktatabell for innbetaling, (d) begrunnet lake-arkiv. Svært godt svar nevner i tillegg at matching på e-post er usikkert (samme person, to e-poster) og at det trengs en «gylden post»-regel (survivorship rule) for konflikt: hvis Shop sier «Oslo» og CRM sier «Bergen», hvem vinner? (Vanlig svar: nyeste `SistEndret`.)

---

## Bolk 4 (2:45–3:00): Plenum og avslutning

### Gjennomgang (10 min)

1. Vis fasit G og sammenlign tall. Spør: *«Var noe av dette overraskende? Hva ville dere gjort med kontroll 8?»* Styr mot skillet datafeil / forretningsregel.
2. Vis fasit V. Bruk 5 minutter på `Salgspris`-dobbeltrollen og `Fraktkostnad`-kornproblemet – det siste er neste ukes tema.

### Diskusjon (5 min)

Velg én:
- *«Nordhandel har 200 000 ordrer per år. Trenger de egentlig et datavarehus, eller holder det med en lesereplika (read replica) av produksjonsdatabasen?»* – Styr mot: replika løser *ytelse/konflikt*, men ingen av de andre fire problemene. Og når CRM-systemet kommer, hjelper den ikke i det hele tatt.
- *«Hvem i Nordhandel bør eie definisjonen av «omsetning»?»* – Styr mot: ikke IT. Økonomisjefen, med IT som rådgiver om hva som er teknisk mulig. Datavarehuset *implementerer* definisjonen; det *bestemmer* den ikke.

### Hjemmearbeid

1. Les Kimball & Ross kap. 1 og 2 (ca. 50 sider). Les spesielt om *grain* (korn) i kap. 2.
2. Skriv maks én side: **«Hva er kornet i Nordhandels faktatabell, og hvorfor?»** Drøft minst to alternativer. Ta med hva dere gjør med fraktkostnad. Dette er utkastet til mappeinnlevering 1.
3. Fullfør oppgave U hvis dere ikke rakk den.
4. (Valgfritt) Se Brent Ozars *How to Think Like the SQL Server Engine*, del 1 (20 min). Vi trenger det i samling 5, men det er lurt å ha sett det tidlig.

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| «Kan vi ikke bare legge til indekser i `NordhandelShop`?» | Tror problemet er ytelse alene | Gå tilbake til de tre umulige spørsmålene – ingen indeks gir deg prisen i mars 2023 |
| «Vi lager et view med den rekursive CTE-en, så slipper alle å skrive den» | Fornuftig tanke! Men løser bare kompleksitet, ikke historikk eller konflikt | Anerkjenn det – et view-lag er faktisk et første skritt mot en mart. Spør så: «hva med prisen i mars 2023?» |
| Klassifiserer `Ordredato` som attributt, ikke nøkkel | Har ikke tenkt på datodimensjonen ennå | Helt greit nå; rett det i samling 2 |
| Setter `Epost` som dimensjonsattributt uten å nevne personvern | Har ikke koblet DW til GDPR | Still spørsmålet eksplisitt: «hvem skal se e-postadresser i Power BI?» |
| Heltallsdivisjon i prosentberegningen (`100 * a / b` = 0) | Klassisk T-SQL-felle | La dem finne det selv ved å sammenligne med fasit |
| `LEN()` «finner ikke» mellomrom-feilen | Vet ikke at `LEN` trimmer | Vis `DATALENGTH` – og bruk det som poeng om at verktøy lyver |
| Oppgave U: matcher kunder i staging | Blander rå kopi og transformasjon | Tegn opp hva som skjer når matchingreglene endres – du må kunne kjøre dem på nytt mot rådata |
| Oppgave U: presser innbetaling inn i `FaktSalg` | Ikke forstått korn ennå | Spør: «ordren har tre linjer og to delinnbetalinger – hvilken linje får hvilken innbetaling?» |

---

## Vedlegg: hurtigreferanse for læreren

**Tall å forvente fra testdataene** (verifisert mot SQL Server 2022; varierer ±5 % pga. tilfeldig generering):

| Måling | Ca. verdi |
|---|---|
| Kunder | 5 050 |
| Produkter | 800 |
| Ordrer | 194 000 |
| Ordrelinjer | 580 000 |
| Ordrer per måned | ~3 500 (jan–mar), ~6 000 (apr–des) |
| Omsetning 2025 (eks. kansellert/returnert, eks. frakt) | ~770 MNOK |
| Kunder uten postnummer | 150 |
| Kunder med postnummer som ikke finnes i registeret | ~55 (≈ 48 med bokstaven O + 7 med tapt null) |
| Kunder med mellomrom bak postnummer | 50 |
| Ordrer i fremtiden | 150 |
| Ordrelinjer med antall 0 | ~1 150 |
| Ordrer datert før kunden ble opprettet | ~1 150 (40 kunder × ~29 ordrer) |
| Ulike priser mest solgte produkt er solgt for | ~4 000 av ~6 300 linjer |
| Merkevarianter: vanlig `GROUP BY` / binær + `DATALENGTH` | 9 / 23 |

**Kjøretid for `01-oltp-testdata.sql`:** 25–40 sekunder på en vanlig laptop.

**Hvis noe går galt:**
- *Testdataskriptet feiler på `dbo.Tall`:* Noen kjørte det to ganger med en halvferdig tabell. `DROP TABLE dbo.Tall` og kjør igjen.
- *Demo 1.2 (blokkering) henger ikke:* Sjekk `SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = 'NordhandelShop'`. Hvis `1`: `ALTER DATABASE NordhandelShop SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE`. Eller bruk det som poeng.
- *Studentene har Azure Data Studio uten «Database Diagrams»:* Tegn ER-diagrammet på tavla, eller del ut som bilde på forhånd.
