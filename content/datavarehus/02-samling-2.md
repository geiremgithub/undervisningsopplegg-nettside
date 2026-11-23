---
title: "Samling 2 – Dimensjonsmodellering"
description: "Stjerneskjema og snøfnuggskjema, fakta og dimensjoner, korn, surrogatnøkler og Slowly Changing Dimensions."
order: 3
---

# Samling 2 – Dimensjonsmodellering

**Varighet:** 3 timer (4 × 45 min)
**Forutsetninger:** Samling 1 gjennomført. Studentene har levert én side om korn (hjemmearbeid). `NordhandelShop` kjører.
**Materiell:** Denne filen, `00-oversikt.md` kap. 3.2, `case/02-dw-skjema.sql` (deles ut *etter* lab, som fasit), Kimball Groups *Dimensional Modeling Techniques* (utskrift til alle).

---

## Læringsmål for samlingen

Etter samlingen skal studenten kunne:

- (a) Velge og begrunne korn (grain) for en faktatabell, og forklare konsekvensene av valget for hvilke dimensjoner og fakta som gir mening
- (b) Modellere et stjerneskjema (star schema) og et snøfnuggskjema (snowflake schema) for samme case og argumentere for stjerne
- (c) Forklare hvorfor surrogatnøkler (surrogate keys) brukes, og hva som går galt uten dem
- (d) Implementere SCD type 0, 1, 2 og 3 i DDL og velge riktig type per attributt
- (e) Skille additive, semi-additive og ikke-additive fakta
- (f) Bygge en datodimensjon og forklare hvorfor den ikke erstattes av en `DATE`-kolonne
- (g) Anvende mønstrene junk dimension, degenerert dimensjon og ukjent-rad

---

## Bolk 1 (0:00–0:45): Fakta, dimensjoner og korn

### 0:00–0:10 Oppsummering av hjemmearbeidet

**Lærernotat:** Du har lest studentenes én-sidere om korn. Velg tre som illustrerer ulike valg (f.eks. én som valgte ordrelinje, én som valgte ordre, én som ville ha begge) og be dem oppsummere på 1 minutt hver. Ikke si hvem som har «rett» ennå.

Skriv de tre alternativene på tavla:

| Korn | Én rad per … | Antall rader (ca.) |
|---|---|---|
| A | ordrelinje | 580 000 |
| B | ordre | 194 000 |
| C | produkt × dag | 800 × 1 095 ≈ 500 000 (men glissent) |

Still spørsmålet: *«Hvilke av de seks rapportene fra oversikten kan hvert alternativ svare på?»*

| Rapport | A (linje) | B (ordre) | C (produkt×dag) |
|---|---|---|---|
| 1. Omsetning per måned per kategori | ✔ | ✘ (ingen produktinfo) | ✔ |
| 2. Topp 10 produkter per kvartal | ✔ | ✘ | ✔ |
| 3. Kundeomsetning år-over-år | ✔ | ✔ | ✘ (ingen kunde) |
| 4. Kunder som flyttet – før/etter | ✔ | ✔ | ✘ |
| 5. Rullerende 30 dager per kanal | ✔ | ✔ | ✘ (ingen kanal) |
| 6. Returandel per merke | ✔ | ✘ | ✔ (hvis status er med) |

Konklusjon studentene skal trekke selv: **bare det fineste kornet svarer på alt.** Og det som ikke er i kornet, kan aldri gjenskapes – men aggregater (B, C) kan alltid lages fra A senere.

### 0:10–0:45 Teori: Kimballs firetrinnsprosess, fakta og dimensjoner

**Kimballs fire trinn** (5 min). Skriv dem opp – dette er oppskriften studentene skal bruke i mappeinnlevering 1:

1. **Velg forretningsprosessen** – «salg av varer» (ikke «ordretabellen»: prosess, ikke tabell)
2. **Deklarer kornet** – «én rad per ordrelinje»
3. **Identifiser dimensjonene** – *hvem, hva, når, hvor, hvordan* for én ordrelinje: kunde, produkt, dato, (sted via kunde), ordreinfo
4. **Identifiser faktaene** – de målbare tallene for én ordrelinje: antall, beløp, kostnad

Poengter rekkefølgen: dimensjoner og fakta *følger* av kornet. Hvis noen foreslår et faktum som ikke passer kornet (fraktkostnad – som er per *ordre*), er det et signal om at enten kornet er feil, eller faktumet hører hjemme et annet sted.

**Fakta: additivitet** (8 min). Tegn tre kolonner:

| Type | Definisjon | Eksempel i Nordhandel | Hva du kan gjøre |
|---|---|---|---|
| **Additiv** | Kan summeres over alle dimensjoner | `Antall`, `NettoBelop`, `Kostnad` | `SUM` alltid riktig |
| **Semi-additiv** | Kan summeres over noen dimensjoner, ikke over tid | Lagerbeholdning (ikke i vårt case), kontosaldo | `SUM` over produkter OK; over dager gir tull – bruk siste/snitt |
| **Ikke-additiv** | Kan aldri summeres | `Enhetspris`, `RabattProsent`, margin i % | Lagre *tellerne* (beløp) og beregn forholdstall i rapporten |

Nøkkelregel: **lagre additive fakta, beregn forholdstall ved spørring.** Derfor lagrer `FaktSalg` `BruttoBelop`, `RabattBelop`, `NettoBelop` og `Kostnad` – ikke rabattprosent og margin. (Vi tar med `Enhetspris` og `RabattProsent` *også*, for sporbarhet, men merker dem som ikke-additive.)

**Dimensjoner: attributter og hierarkier** (7 min). En dimensjon er «ting man filtrerer og grupperer på». Gode dimensjonsattributter er:
- **Beskrivende tekst**, ikke koder: `'Vipps'`, ikke `2`. Forretningsbrukeren skal forstå dem.
- **Komplette**: aldri `NULL`. Bruk `'Ukjent'`, `'Ikke oppgitt'`, `'Ikke relevant'`.
- **Flate hierarkier**: `Hovedkategori`, `Kategori`, `Underkategori` som tre kolonner side om side.

Vis kategorihierarkiet fra kilden og hvordan det flates ut:

```
Kilde (normalisert, rekursiv):           DimProdukt (flat):
Kategori                                 ProduktKey | Navn            | Hovedkategori | Kategori | Underkategori
  1 Klær         (NULL)                  ───────────┼─────────────────┼───────────────┼──────────┼──────────────
  5 Jakker       (→1)                    42         | Norrøna Lofoten | Klær          | Jakker   | Skalljakker
 15 Skalljakker  (→5)                    43         | Bergans Rondane | Klær          | Bukser   | Bukser    ← nivå 2: Underkategori = Kategori
                                         44         | Primus Finse    | Utstyr        | Kokeutstyr| Kokeutstyr
```

Spør: *«Dere lærte i forrige emne at redundans er dårlig. Hvorfor er det greit her?»* Svar: (1) dimensjonen er liten (800 rader), (2) den oppdateres bare av ETL, kontrollert, så oppdateringsanomalier kan ikke oppstå, (3) hver join vi sparer er en join Power BI-brukeren slipper å forstå. Dette *er* stjerne vs. snøfnugg.

**Stjerne vs. snøfnugg** (8 min). Tegn begge for `DimProdukt`:

```
STJERNE:                            SNØFNUGG:
FaktSalg ── DimProdukt              FaktSalg ── DimProdukt ── DimUnderkategori ── DimKategori ── DimHovedkategori
            (alt flatt)                         (ProduktId,     (UnderkatId,       (KatId,          (HovedkatId,
                                                 UnderkatKey)    KatKey)             HovedkatKey)     Navn)
Rapport 1: 2 joins                  Rapport 1: 5 joins
```

Argumentene for snøfnugg som faktisk holder: (a) et subhierarki deles av flere dimensjoner (geografi brukt av både `DimKunde` og `DimButikk`) – da kan man lage `DimGeografi` og referere den; (b) dimensjonen har millioner rader og hierarkiet er stort. Ingen av delene gjelder Nordhandel. **Regel: stjerne som standard, snøfnugg bare med en konkret grunn man kan skrive ned.**

**Surrogatnøkler** (10 min). Spør: *«Hvorfor ikke bruke `KundeId` fra kilden som primærnøkkel i `DimKunde`?»* La dem prøve å svare, og skriv opp:

1. **Historikk** – om kunden skal ha én rad per adresseperiode (SCD type 2), kan `KundeId` ikke være unik. Dette er den avgjørende grunnen og den vi bruker i bolk 2.
2. **Flere kilder** – nettbutikk og CRM har ulike ID-er for samme kunde. Datavarehuset trenger sin egen identitet (oppgave U fra samling 1).
3. **Ukjent-raden** – vi trenger en rad for «ukjent kunde» med en nøkkel som garantert ikke finnes i kilden: `-1`.
4. **Størrelse og ytelse** – `INT` (4 byte) i 580 000 faktarader × 4 dimensjoner. Hvis kilden hadde brukt `UNIQUEIDENTIFIER` (16 byte) eller e-post som nøkkel, hadde faktatabellen blitt tre–tolv ganger bredere i nøkkelkolonnene.
5. **Isolasjon** – kilden kan bytte nøkkelformat; bare dimensjonen berøres.

Konvensjon i emnet: `XxxKey` = surrogatnøkkel (`INT IDENTITY`), `XxxId` = forretningsnøkkel (business key / natural key) fra kilden. **Faktatabellen inneholder kun `Key`-kolonner** (pluss degenererte dimensjoner – kommer).

---

## Pause (0:45–0:55)

---

## Bolk 2 (0:55–1:40): Slowly Changing Dimensions og de andre mønstrene

### 0:55–1:20 Teori: SCD type 0–3

**Problemet** (3 min). Kari Hansen (kunde 42) bor i Stavanger. Hun handler for 1 000 kr i mars 2024. 1. juli flytter hun til Oslo. Hun handler for 2 000 kr i september. Spørsmål: *«Hvor mye solgte vi til Rogaland i 2024?»*
- Kilden sier: 0 kr (Kari bor jo i Oslo nå).
- Markedssjefen sier: 1 000 kr (hun bodde i Stavanger da hun kjøpte).
- Daglig leder vil kanskje vite: «hva handler våre nåværende Oslo-kunder for» = 3 000 kr.

**Alle tre svar er legitime.** Et godt datavarehus kan gi alle tre. Det krever at vi bevarer *begge versjoner* av Kari.

**De fire typene** (12 min). Tegn tabellen og vis hvordan Karis rad(er) ser ut under hver:

| Type | Teknikk | Karis rad(er) etter flytting | Rogaland 2024 = | Brukes for |
|---|---|---|---|---|
| **0** | Aldri endre | `Fylke = 'Rogaland'` (for alltid) | 3 000 | Attributter som *per definisjon* er faste: fødselsdato, `OpprinneligKundesegment`, `KundeSiden` |
| **1** | Overskriv | `Fylke = 'Oslo'` | 0 | Rettelser og attributter der historikk ikke gir mening: navn (stavefeil), produktnavn, e-post |
| **2** | Ny rad | Rad 1: `Rogaland`, gyldig 1900-01-01 – 2024-06-30, `ErGjeldende = 0`<br>Rad 2: `Oslo`, gyldig 2024-07-01 – 9999-12-31, `ErGjeldende = 1` | 1 000 (eller 3 000 – du velger i spørringen) | Attributter der «hva var sant da» betyr noe: adresse, segment, pris, kategori, selgers avdeling |
| **3** | Ekstra kolonne | `Fylke = 'Oslo'`, `ForrigeFylke = 'Rogaland'` | Kan vises begge, men bare én generasjon | Omorganiseringer der alle vil sammenligne «gammel og ny inndeling» en periode, f.eks. ny salgsregioninndeling |

**Type 2 i detalj** (7 min) – dette må alle kunne. Tre styringskolonner:

```sql
GyldigFra    DATE NOT NULL,              -- første dag denne versjonen gjelder
GyldigTil    DATE NOT NULL,              -- siste dag. '9999-12-31' for gjeldende – IKKE NULL
ErGjeldende  BIT  NOT NULL               -- redundant med GyldigTil, men gjør spørringer lesbare og indekserbare
```

Hvorfor `'9999-12-31'` og ikke `NULL` for «gjeldende»? Fordi oppslaget i ETL blir `WHERE @Dato BETWEEN GyldigFra AND GyldigTil` – med `NULL` måtte man skrive `AND (GyldigTil IS NULL OR @Dato <= GyldigTil)`, som er tregere og lettere å glemme.

Konsekvensen for **fakta**: hver faktarad peker på den *versjonen* av kunden som gjaldt på salgstidspunktet. ETL (samling 3) slår opp: «finn `KundeKey` for `KundeId = 42` der `Ordredato BETWEEN GyldigFra AND GyldigTil`». Dermed peker mars-salget på rad 1 (Rogaland) og september-salget på rad 2 (Oslo) – *for alltid*, uansett hvor Kari flytter senere.

**Hvem bestemmer type?** (3 min) Ikke utvikleren. Per attributt må forretningen svare: «Hvis dette endrer seg, skal gamle salg følge gammel eller ny verdi?» Vis tabellen for `DimKunde`:

| Attributt | Type | Begrunnelse |
|---|---|---|
| `Navn` | 1 | Stavefeil rettes; ingen rapport trenger «navnet hun hadde da» |
| `Postnummer`, `Poststed`, `Kommune`, `Fylke` | 2 | Rapport 4 krever det. Geografisk omsetning skal ikke «flytte» |
| `Kundesegment` | 2 | Når en privatkunde blir bedriftskunde, skal gamle kjøp telle som privat |
| `OpprinneligKundesegment` | 0 | «Hvilket segment ble de rekruttert i» – kohortanalyse |
| `KundeSiden` | 0 | Første registreringsdato endrer seg ikke |

### 1:20–1:40 Demo 2.1 og 2.2

**Demo 2.1 – Datodimensjonen** (8 min). Kjør del 1–2 av `case/02-dw-skjema.sql` (database, schemaer, `DimDato`). Vis resultatet og pek på:

```sql
SELECT DatoKey, Dato, AarMaaned, IsoAarUke, UkedagNavn, ErHelg, HelligdagNavn, ErArbeidsdag
FROM dw.DimDato
WHERE Dato BETWEEN '2024-12-28' AND '2025-01-03'
   OR (Aar = 2025 AND ErHelligdag = 1)
ORDER BY Dato;
```

| Poeng | Hva du peker på |
|---|---|
| **Hvorfor ikke bare en `DATE`-kolonne?** | `ErHelligdag` – 17. mai, påske og pinse kan ikke beregnes med `DATEPART`. `ErArbeidsdag` brukes i «omsetning per arbeidsdag». `IsoAarUke` – uke 1 2025 starter 30. desember 2024; `YEAR()` + `DATEPART(iso_week)` gir «2024-W01», som er feil. Alt dette ligger ferdig beregnet, én gang, og alle rapporter får samme svar |
| **`DatoKey = 20250101`** | Et heltall på formen yyyymmdd. Leselig i faktatabellen uten join, sorterbart, 4 byte. Dette er det ene stedet Kimball godtar en «smart» surrogatnøkkel |
| **Påskeberegningen** | `dw.fnPaaskedag` – Meeus/Jones/Butcher-algoritmen. Ikke noe studentene må kunne, men vis at bevegelige helligdager er *mulig* å beregne og derfor bør ligge i dimensjonen |
| **17. mai 2027 = 2. pinsedag** | `HelligdagNavn = '17. mai / 2. pinsedag'`. Et ekte kanttilfelle som ville gitt duplikatnøkkel uten `STRING_AGG`. Kjør `WHERE HelligdagNavn LIKE '%/%'` og vis |
| **`SET LANGUAGE Norwegian`** | Gir norske navn i `DATENAME`, men endrer *også* hvordan `'2022-01-01'` tolkes (til år-dag-måned!). Skriptet setter `SET DATEFORMAT ymd` eksplisitt. Lærdom: bruk alltid `'yyyymmdd'` eller `DATEFROMPARTS` i kode som skal kjøre på servere med ulik språkinnstilling |
| **Ukjent-raden `19000101`** | Fakta uten gyldig dato peker hit, ikke på `NULL` |

**Demo 2.2 – SCD type 2 i praksis** (12 min). Kjør resten av `02-dw-skjema.sql` (dimensjoner, fakta, ukjent-rader). Deretter legger du inn Kari manuelt – *uten ETL* – for å vise hva ETL-en skal produsere neste uke:

```sql
USE NordhandelDW;

-- Kari Hansen: Stavanger til og med 30.6.2024, Oslo fra 1.7.2024
INSERT INTO dw.DimKunde (KundeId, Navn, Postnummer, Poststed, Kommune, Fylke, Kundesegment,
                         OpprinneligKundesegment, KundeSiden, GyldigFra, GyldigTil, ErGjeldende)
VALUES (42, N'Kari Hansen', '4006', N'Stavanger', N'Stavanger', N'Rogaland', N'Privat', N'Privat', '2022-03-15', '1900-01-01', '2024-06-30', 0),
       (42, N'Kari Hansen', '0150', N'Oslo',      N'Oslo',      N'Oslo',     N'Privat', N'Privat', '2022-03-15', '2024-07-01', '9999-12-31', 1);

SELECT KundeKey, KundeId, Fylke, GyldigFra, GyldigTil, ErGjeldende FROM dw.DimKunde WHERE KundeId = 42;
```
- To rader, samme `KundeId`, ulik `KundeKey` (1 og 2). Første versjon har `GyldigFra = '1900-01-01'` – konvensjon for «fra tidenes morgen», så alle gamle salg treffer den.
- `GyldigTil` på rad 1 er dagen *før* `GyldigFra` på rad 2. Ingen overlapp, ingen hull. ETL må garantere dette.

```sql
-- To salg: ett i mars (Stavanger-perioden), ett i september (Oslo-perioden).
-- Nøkkelen slås opp med BETWEEN – akkurat slik ETL gjør det.
DECLARE @Levert INT = (SELECT OrdreinfoKey FROM dw.DimOrdreinfo
                       WHERE Status = 'Levert' AND Betalingsmate = 'Kort' AND Kanal = 'Web');

INSERT INTO dw.FaktSalg (OrdreDatoKey, KundeKey, ProduktKey, OrdreinfoKey, OrdreId, OrdrelinjeId,
                         Antall, BruttoBelop, RabattBelop, NettoBelop, Kostnad, FraktAllokert, Enhetspris, RabattProsent)
SELECT 20240310, k.KundeKey, -1, @Levert, 900001, 9000011, 1, 1000, 0, 1000, 600, 0, 1000, 0
FROM dw.DimKunde k WHERE k.KundeId = 42 AND '2024-03-10' BETWEEN k.GyldigFra AND k.GyldigTil
UNION ALL
SELECT 20240905, k.KundeKey, -1, @Levert, 900002, 9000021, 2, 2000, 0, 2000, 1200, 0, 1000, 0
FROM dw.DimKunde k WHERE k.KundeId = 42 AND '2024-09-05' BETWEEN k.GyldigFra AND k.GyldigTil;
```
- `ProduktKey = -1` – vi har ingen produkter ennå, så vi bruker ukjent-raden. Faktatabellen godtar det fordi raden finnes. Hadde vi brukt `NULL`, ville `INNER JOIN` mot `DimProdukt` kastet raden.
- `@Levert` – junk dimension-oppslag: tre attributter → én nøkkel.

Nå de tre spørsmålene fra starten av bolken:

```sql
-- A: «Slik det VAR» – fylke på kjøpstidspunktet. Join på surrogatnøkkelen, ingenting mer.
SELECT k.Fylke, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
GROUP BY k.Fylke;
-- → Rogaland 1000, Oslo 2000

-- B: «Slik det ER» – kundens nåværende fylke. Join til kundens GJELDENDE rad via forretningsnøkkelen.
SELECT kn.Fylke, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimKunde k  ON k.KundeKey = f.KundeKey                      -- versjonen på salgstidspunktet
JOIN dw.DimKunde kn ON kn.KundeId = k.KundeId AND kn.ErGjeldende = 1 -- «hopp» til gjeldende versjon
GROUP BY kn.Fylke;
-- → Oslo 3000

-- C: FEIL – den vanligste SCD2-feilen studentene gjør
SELECT k.Fylke, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
WHERE k.ErGjeldende = 1
GROUP BY k.Fylke;
-- → Oslo 2000.  Rogaland-salget på 1000 er BORTE. Filteret kastet den gamle versjonen – og faktaraden med den.
```

**Lærernotat:** Stopp opp ved C. Dette er feilen som gir «omsetningen i rapporten er lavere enn i regnskapet» i virkelige prosjekter. Regelen: `ErGjeldende = 1` brukes *bare* når man vil liste dimensjonen (nedtrekksliste, kundeoversikt) eller hoppe til nåværende versjon (B). **Aldri som filter på en join fra fakta.**

```sql
-- D: Rapport 4 – kunder som har flyttet, omsetning før og etter
SELECT k.KundeId, k.Navn, k.Fylke, k.GyldigFra, k.GyldigTil, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
WHERE k.KundeId IN (SELECT KundeId FROM dw.DimKunde GROUP BY KundeId HAVING COUNT(*) > 1)
GROUP BY k.KundeId, k.Navn, k.Fylke, k.GyldigFra, k.GyldigTil
ORDER BY k.KundeId, k.GyldigFra;
```
- `HAVING COUNT(*) > 1` finner kunder med mer enn én versjon = de som har endret noe. Dette er hele rapport 4, ferdig, med null ekstra tabeller. *Det* er verdien av SCD type 2.

Rydd opp til slutt (ETL fyller tabellene ordentlig neste uke):
```sql
DELETE FROM dw.FaktSalg WHERE OrdreId IN (900001, 900002);
DELETE FROM dw.DimKunde WHERE KundeId = 42;
```

**Kort om de andre mønstrene** (vis i DDL-en, 1 min hver):
- **Junk dimension** `DimOrdreinfo`: `Status`, `Betalingsmate`, `Kanal` – tre attributter med 6 × 4 × 3 = 72 kombinasjoner, forhåndsfylt med `CROSS JOIN`. Alternativet var tre dimensjonstabeller med 3–6 rader hver og tre nøkler i fakta. Merk flaggene `ErGyldigSalg`, `ErReturnert`, `ErKansellert`: *forretningsregelen «hva teller som salg» er definert én gang, her*, ikke i hver rapport.
- **Degenerert dimensjon** `OrdreId` og `OrdrelinjeId` i `FaktSalg`: nøkler fra kilden uten egen dimensjonstabell. `OrdreId` lar oss telle ordrer (`COUNT(DISTINCT OrdreId)`) og gruppere linjer; `OrdrelinjeId` er faktaradens forretningsnøkkel og gjør lastingen idempotent (samling 3).
- **Ukjent-rad** `-1` i alle dimensjoner, `19000101` i dato. Vist med `SET IDENTITY_INSERT`. Fakta får aldri `NULL`-nøkler, så `INNER JOIN` er alltid trygt og tallene stemmer alltid med totalen.
- **Role-playing dimension** (nevnes): hadde vi hatt `Leveringsdato`, ville `FaktSalg` hatt `OrdreDatoKey` *og* `LeveringsDatoKey`, begge mot samme `DimDato`. I spørringer gis den to alias: `JOIN dw.DimDato od ON … JOIN dw.DimDato ld ON …`.

---

## Pause (1:40–2:00)

---

## Bolk 3 (2:00–2:45): Lab 2

Grupper på 2–3. Studentene har **ikke** fått `02-dw-skjema.sql` ennå – bare sett `DimDato` og `DimKunde` på skjerm. De skriver DDL selv. Fasit deles ut etter plenum.

### Oppgave G (grunnleggende): `DimProdukt` og `FaktSalg`

1. Skriv `CREATE TABLE dw.DimProdukt` med surrogatnøkkel, forretningsnøkkel, flatet hierarki (tre nivåer), merke, priser og SCD-styring. For hvert attributt: angi SCD-type i en kommentar og begrunn med én setning.
2. Skriv `CREATE TABLE dw.FaktSalg` med korn ordrelinje. Angi for hvert faktum om det er additivt, semi-additivt eller ikke-additivt. Inkluder fremmednøkler til alle fire dimensjoner og en unik begrensning som hindrer at samme ordrelinje lastes to ganger.
3. Legg inn ukjent-raden i `DimProdukt`.

**Fasit G:** Se del 4, 6 og 7 i `case/02-dw-skjema.sql`. Vurderingspunkter:

| Krav | Godkjent når |
|---|---|
| Surrogatnøkkel | `ProduktKey INT IDENTITY PRIMARY KEY`, og `ProduktId` som egen kolonne. **Ikke** `PRIMARY KEY (ProduktId)` |
| Hierarki | Tre kolonner, `NOT NULL`. Produkter på nivå 2 får `Underkategori = Kategori` (ikke `NULL`) |
| SCD-typer | `Navn`, `Merke`, `Aktiv` = type 1; `Hovedkategori`/`Kategori`/`Underkategori`, `Salgspris`, `Innkjopspris` = type 2. Begrunnelse for pris: «margin på gamle salg skal beregnes med den kostnaden som gjaldt da». Begrunnelse for kategori: «når Jakker flyttes fra Klær til Yttertøy, skal fjorårets salg fortsatt ligge under Klær». Studenter som velger type 1 på kategori har et *forsvarlig* standpunkt («vi vil se alle år med dagens inndeling») – godta det hvis det er begrunnet, men påpek at type 2 + spørring B gir *begge* visninger |
| Fakta | `Antall`, `BruttoBelop`, `RabattBelop`, `NettoBelop`, `Kostnad` additive. `Enhetspris`, `RabattProsent` ikke-additive (eller utelatt). Beregnet `Dekningsbidrag` er en bonus |
| Idempotens | `UNIQUE (OrdrelinjeId)` |
| FK-er | Fire `REFERENCES`. Diskuter i plenum: i store DW dropper man ofte FK-er av ytelseshensyn og lar ETL garantere integriteten – men man *starter* med dem |
| Ukjent-rad | `SET IDENTITY_INSERT … ON`, nøkkel `-1`, alle tekstfelt `'Ukjent'`, `GyldigTil = '9999-12-31'`, `ErGjeldende = 1` |

### Oppgave V (viderekommen): Junk dimension og fraktkostnad

1. Modellér `dw.DimOrdreinfo` som junk dimension for `Status`, `Betalingsmate` og `Kanal`. Fyll den med alle kombinasjoner med én `INSERT … SELECT … CROSS JOIN`. Legg til minst ett avledet flagg som koder en forretningsregel.
2. `Ordre.Fraktkostnad` er per ordre, men kornet er ordrelinje. Vurder tre alternativer og velg ett med begrunnelse:
   - (i) Egen faktatabell `FaktOrdre` med korn ordre
   - (ii) Legg frakten på første linje i ordren, `0` på resten
   - (iii) Fordel frakten på linjene proporsjonalt med `NettoBelop`
3. Hvis dere velger (iii): hva skjer med avrundingen? Skriv SQL mot `NordhandelShop` som fordeler frakt for én ordre og viser om summen av de fordelte beløpene blir lik `Fraktkostnad`.

**Fasit V:**

1. Se del 5 i `02-dw-skjema.sql`. Flagget `ErGyldigSalg` er forretningsregelen «kansellerte ordrer teller ikke som salg». Legg merke til at `Returnert` har `ErGyldigSalg = 1` – det var et salg, som senere ble returnert. Det er oppgave U.

2. Avveining:

| Alternativ | Fordel | Ulempe | Når riktig |
|---|---|---|---|
| (i) `FaktOrdre` | Rent korn, ingen allokering, kan ha ordrefakta som antall linjer, leveringstid | To faktatabeller å laste og vedlikeholde. «Omsetning inkl. frakt per kategori» krever drill-across (to spørringer som slås sammen) | Når det er mange ordrenivå-fakta (frakt, gebyr, rabattkode, leveringstid) |
| (ii) Første linje | Enkelt. Summen per ordre er riktig | Frakt per *produkt/kategori* blir vilkårlig – den kategorien som tilfeldigvis har første linje får all frakten | Aldri, egentlig. Men det er bedre enn å duplisere frakten på alle linjer (som gir 3× frakt i totalen – en feil minst én gruppe vil gjøre) |
| (iii) Proporsjonal allokering | Én faktatabell. Summen per ordre er riktig *og* fordelingen per kategori er rimelig. Power BI-brukere trenger ikke forstå to faktatabeller | Allokeringen er en *antakelse* (kunne vært etter vekt eller antall). Avrunding må håndteres | **Vårt valg.** Standard Kimball-anbefaling for «header-level facts» når det er få av dem |

Dokumentér valget i `FaktSalg`: kolonnen heter `FraktAllokert`, ikke `Fraktkostnad`, så ingen tror det er en målt verdi.

3. Avrunding – kjør mot `NordhandelShop`:

```sql
WITH Linje AS (
    SELECT ol.OrdreId, ol.OrdrelinjeId, o.Fraktkostnad,
           ol.Antall * ol.EnhetsprisEksMva * (1 - ol.RabattProsent / 100.0)                                AS Netto,
           SUM(ol.Antall * ol.EnhetsprisEksMva * (1 - ol.RabattProsent / 100.0)) OVER (PARTITION BY ol.OrdreId) AS OrdreNetto,
           COUNT(*) OVER (PARTITION BY ol.OrdreId)                                                           AS AntallLinjer,
           ROW_NUMBER() OVER (PARTITION BY ol.OrdreId ORDER BY ol.OrdrelinjeId DESC)                         AS ErSisteLinje
    FROM dbo.Ordrelinje ol
    JOIN dbo.Ordre o ON o.OrdreId = ol.OrdreId
),
Naiv AS (
    SELECT *,
           CASE WHEN OrdreNetto = 0 THEN ROUND(Fraktkostnad / AntallLinjer, 2)        -- alle linjer har Antall = 0
                ELSE ROUND(Fraktkostnad * Netto / OrdreNetto, 2) END AS FraktNaiv
    FROM Linje
),
Korrigert AS (
    SELECT *,
           CASE WHEN ErSisteLinje = 1
                THEN FraktNaiv + (Fraktkostnad - SUM(FraktNaiv) OVER (PARTITION BY OrdreId))   -- legg avrundingsresten på siste linje
                ELSE FraktNaiv END AS FraktAllokert
    FROM Naiv
)
SELECT OrdreId, OrdrelinjeId, Fraktkostnad, CAST(Netto AS DECIMAL(10,2)) AS Netto, FraktNaiv, FraktAllokert
FROM Korrigert
WHERE OrdreId = 11
ORDER BY OrdrelinjeId;
```

Resultat for ordre 11 (frakt 99,00):

| OrdrelinjeId | Netto | FraktNaiv | FraktAllokert |
|---|---|---|---|
| 38283 | 4 183,01 | 44,84 | 44,84 |
| 54962 | 3 164,42 | 33,92 | 33,92 |
| 75283 | 1 887,36 | 20,23 | **20,24** |
| **Sum** | | **98,99** | **99,00** |

- `SUM(...) OVER (PARTITION BY OrdreId)` gir ordretotalen på hver linje uten `GROUP BY` – en vindusfunksjon (window function). Studentene har ikke lært dette ennå (samling 4); forklar bare «summen for hele ordren, gjentatt på hver rad».
- Naiv avrunding gir feil sum i **29 756 av 194 000 ordrer** (15 %). Over et år er det tusenvis av kroner som «forsvinner» eller oppstår. Regnskapsavdelingen oppdager det.
- Løsningen: beregn resten (`Fraktkostnad − SUM(FraktNaiv)`) og legg den på én linje. Hvilken linje er vilkårlig – men det skal være *deterministisk* (samme hver gang ETL kjører), derfor `ORDER BY OrdrelinjeId`.
- Kanttilfelle: 16 ordrer har `OrdreNetto = 0` (alle linjer har `Antall = 0` – kvalitetsfeil L1). Deling på null må håndteres eksplisitt.
- Dette er nøyaktig koden som går inn i `etl.LastFaktSalg` neste uke.

### Oppgave U (utfordring): Modellér retur

Ordrer med `Status = 'Returnert'` er solgt og deretter returnert. Rapport 6 trenger «returandel per merke per kvartal». Vurder:

- (a) Negativ rad i `FaktSalg`: for hver returnert ordrelinje, legg til en rad med `Antall = -1 × Antall`, `NettoBelop = -…`
- (b) Egen faktatabell `FaktRetur` med korn «én rad per returnert ordrelinje»
- (c) Behold raden i `FaktSalg` som den er, og la `DimOrdreinfo.ErReturnert` gjøre jobben

Hva kan kilden faktisk fortelle oss om returen? Hva kan den *ikke*? Velg og begrunn. Skriv spørringen for rapport 6 mot din modell (den kan testes neste uke når data er lastet).

**Fasit U:**

Først det avgjørende spørsmålet: **hva vet kilden?** `Ordre.Status = 'Returnert'` og `SistEndret`. Vi vet *at* ordren ble returnert, og omtrent *når* (`SistEndret`, hvis ingen har endret noe annet etterpå). Vi vet **ikke** om hele eller deler av ordren ble returnert (status er per ordre), eller returårsaken.

| Alt. | Vurdering |
|---|---|
| (a) Negativ rad | Elegant for totaler: `SUM(NettoBelop)` gir netto etter retur automatisk. Men: (1) hvilken dato får returraden? `SistEndret` er upålitelig. (2) `COUNT(*)` og `AVG` blir feil (returraden teller som en «linje»). (3) Returandel krever at man skiller positive og negative rader uansett. (4) Vi vet ikke om hele ordren ble returnert, så beløpet er gjetning. **Forkastes** for denne kilden |
| (b) `FaktRetur` | Riktig modell *når kilden har returdata*: egen returdato (role-playing `DimDato`), returårsak-dimensjon, returnert antall per linje. Da deler den `DimKunde`, `DimProdukt`, `OrdreId` med `FaktSalg` → drill-across for returandel. **Riktig på sikt**, men vi har ikke dataene som gjør den bedre enn (c) i dag. Bygger vi den nå, fyller vi den med gjetninger |
| (c) Flagg i junk | Ærlig om hva vi vet: «dette salget ble senere returnert». Returandel = `SUM(NettoBelop) WHERE ErReturnert = 1 / SUM(NettoBelop) WHERE ErGyldigSalg = 1`, per merke per kvartal (salgskvartalet, ikke returkvartalet – det eneste vi kan). **Vårt valg nå.** Dokumentér begrensningen og planlegg (b) når kilden leverer returlinjer |

Rapport 6 mot modell (c):
```sql
SELECT d.KvartalNavn, p.Merke,
       SUM(f.NettoBelop)                                                AS Salg,
       SUM(CASE WHEN oi.ErReturnert = 1 THEN f.NettoBelop ELSE 0 END)   AS Returnert,
       CAST(100.0 * SUM(CASE WHEN oi.ErReturnert = 1 THEN f.NettoBelop ELSE 0 END)
            / NULLIF(SUM(f.NettoBelop), 0) AS DECIMAL(5,2))             AS ReturandelPst
FROM dw.FaktSalg f
JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
JOIN dw.DimProdukt p    ON p.ProduktKey = f.ProduktKey
JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
WHERE oi.ErGyldigSalg = 1
GROUP BY d.KvartalNavn, p.Merke
ORDER BY d.KvartalNavn, ReturandelPst DESC;
```
- `NULLIF(…, 0)` hindrer deling på null for merker uten salg i et kvartal.
- Returandel er et **forholdstall** – beregnes i spørringen fra to additive summer. Det er additivitetsregelen fra bolk 1 i praksis.
- Legg merke til at *definisjonen* av «salg» (`ErGyldigSalg = 1`) kommer fra dimensjonen, ikke fra en `WHERE Status NOT IN (…)` i rapporten.

**Vurdering av U:** Godt svar velger (c) eller (b) med eksplisitt begrunnelse i *hva kilden vet*. Svært godt svar peker på at (a) gjør `COUNT`/`AVG` feil, og at (b) er veien videre når kilden gir returlinjer. Svar som velger (a) uten å nevne datoproblemet, eller som bygger (b) og fyller den med `SistEndret` som returdato uten forbehold, mangler kjernen: **modellen skal ikke late som den vet mer enn kilden.**

---

## Bolk 4 (2:45–3:00): Plenum og avslutning

### Gjennomgang (10 min)

1. Vis `DimProdukt` og `FaktSalg` fra `02-dw-skjema.sql`. Be én gruppe forklare sin SCD-tabell for `DimProdukt`. Hvis noen valgte type 1 på kategori: la dem argumentere, og vis spørring B fra demoen som gir «dagens inndeling» uten å miste historikken.
2. Frakt: håndsopprekning på (i)/(ii)/(iii). Vis avrundingstabellen for ordre 11. Spør: «hvor mange kroner forsvinner per år med naiv avrunding?» (Omtrent 30 000 ordrer × gjennomsnittlig ±0,5 øre ≈ noen hundre kroner – lite, men regnskapet skal stemme på øret.)

### Diskusjon (5 min)

Velg én:
- *«Daglig leder sier «jeg vil bare vite hvor kunden bor nå». Markedssjefen sier «jeg vil vite hvor de bodde da de kjøpte». Kan begge få viljen sin? Hva koster det?»* – Ja (spørring A og B). Kostnaden er flere rader i `DimKunde`, mer kompleks ETL, og at rapportutviklere *må forstå forskjellen* – spørring C viser hva som skjer hvis de ikke gjør det.
- *«Er en junk dimension et brudd på god modellering?»* – Den bryter med «én dimensjon = ett forretningsbegrep». Men alternativet (tre mikrodimensjoner) gir en bredere faktatabell og flere joins for null gevinst. Grensen: når attributtene har 100+ verdier hver eller endrer seg uavhengig og ofte, bør de skilles.

### Hjemmearbeid: Mappeinnlevering 1 (leveres før samling 3)

Komplett DDL for `NordhandelDW` med et notat (maks 3 sider) som dekker:
1. Kornbeslutning med alternativer drøftet
2. SCD-type per attributt i `DimKunde` og `DimProdukt` med begrunnelse
3. Valg for frakt og retur med begrunnelse
4. Én ting dere er usikre på og hvorfor

**Lærernotat:** Del ut `02-dw-skjema.sql` *etter* at innleveringen er levert, ikke nå. Studentene som har skrevet DDL selv og deretter sammenligner, lærer mest. Si eksplisitt: «Fasiten er ikke den eneste riktige modellen. Dersom dere har valgt annerledes med god begrunnelse, får dere full uttelling.»

Les til neste gang: Kimball & Ross kap. 19 (ETL Subsystems), s. 443–470. Spesielt subsystem 9 (SCD manager) og 14 (surrogate key pipeline).

---

## Vanlige feil og misforståelser i denne samlingen

| Hva du ser | Hva det betyr | Hva du gjør |
|---|---|---|
| `PRIMARY KEY (KundeId)` i `DimKunde` | Har ikke forstått at SCD2 gir flere rader per kunde | Be dem legge inn Kari to ganger – feilmeldingen gjør resten |
| `GyldigTil NULL` for gjeldende rad | Fungerer, men gjør oppslag tregere og `BETWEEN` umulig | Vis `WHERE @Dato BETWEEN GyldigFra AND GyldigTil` vs. varianten med `IS NULL OR` |
| `Fylke NULL` i `DimKunde` | Tenker OLTP: «vi vet det ikke, så NULL» | Regel: dimensjonsattributter er aldri `NULL`. `'Ukjent'`. Ellers forsvinner kundene fra slicere og `GROUP BY` gir en navnløs gruppe |
| `Produktnavn NVARCHAR(200)` i `FaktSalg` | Blander attributter inn i fakta | «Er det et tall du vil summere? Nei → dimensjon» |
| `AntallSolgt INT` i `DimProdukt` | Blander fakta inn i dimensjon | «Endrer det seg hver dag? Ja → fakta» |
| `Fraktkostnad` kopiert på alle linjer | Har ikke tenkt på at `SUM` per ordre blir 3× | La dem summere frakt for én ordre med tre linjer |
| `RabattProsent` som eneste rabattfaktum | Ikke-additivt faktum uten telleren | «Hva er gjennomsnittlig rabatt i prosent for Klær i mars?» – `AVG(RabattProsent)` er feil (vekter ikke etter beløp). Trenger `RabattBelop` |
| Snøfnugg «fordi det er normalisert» | Overfører OLTP-regler til DW | Tell joins i rapport 1. Spør hvem som oppdaterer dimensjonen (bare ETL → ingen anomalier) |
| Type 2 på *alle* attributter «for sikkerhets skyld» | Tror mer historikk alltid er bedre | Vis konsekvensen: hver stavefeilretting i `Navn` gir ny `KundeKey`, nye fakta peker på ny rad, rapport 4 («kunder som har endret seg») fylles av støy |
| `DatoKey` som `DATE`-type eller `INT IDENTITY` | Har ikke sett poenget med yyyymmdd | `DATE` fungerer faktisk helt fint som nøkkel; `IDENTITY` er dårlig (ikke lesbart, ikke sorterbart uten join). Godta `DATE`, forklar hvorfor `INT yyyymmdd` er konvensjon |
| Ukjent-rad med `KundeId = 0` eller `NULL` | Vet ikke om `-1`-konvensjonen | Begge fungerer; `-1` er konvensjon fordi `0` kan være en ekte ID i noen kilder |
| Spørring C-feilen i rapport 6 eller rapport 4 | `WHERE k.ErGjeldende = 1` på fakta-join | Dette kommer igjen i samling 4. Pek på demoen |

---

## Vedlegg: hurtigreferanse for læreren

**Kjøretid `02-dw-skjema.sql`:** 2–3 sekunder. Lager 4 019 datorader (2022-01-01 – 2032-12-31 + ukjent), 73 rader i `DimOrdreinfo`, ukjent-rad i `DimKunde` og `DimProdukt`, tom `FaktSalg`.

**Sjekk av `DimDato`** (bruk i demo):
```sql
SELECT Dato, UkedagNavn, HelligdagNavn FROM dw.DimDato WHERE Aar = 2025 AND ErHelligdag = 1 ORDER BY Dato;
-- 12 rader: 1. jan, skjærtorsdag 17/4, langfredag 18/4, 1. og 2. påskedag 20–21/4, 1. mai, 17. mai,
--           Kristi himmelfart 29/5, 1. og 2. pinsedag 8–9/6, 1. og 2. juledag
SELECT Dato, IsoAarUke FROM dw.DimDato WHERE Dato IN ('20241230', '20270101');
-- 2024-12-30 → 2025-W01, 2027-01-01 → 2026-W53
```

**Hvis noe går galt:**
- *«CREATE INDEX failed because … QUOTED_IDENTIFIER»*: Studenten kjører fra `sqlcmd` eller et verktøy med `QUOTED_IDENTIFIER OFF`. Skriptet setter det `ON` øverst; hvis de kopierer deler av skriptet, må de ta med `SET QUOTED_IDENTIFIER ON`.
- *«Violation of PRIMARY KEY … (20270517)»*: Noen har fjernet `STRING_AGG`-steget. 17. mai 2027 er både nasjonaldag og 2. pinsedag.
- *«conversion of a varchar data type to a datetime … out-of-range»*: `SET LANGUAGE Norwegian` uten `SET DATEFORMAT ymd`. Et godt eksempel å vise på hvorfor man bruker `'yyyymmdd'`.
- *Demo 2.2 gir `KundeKey` 2 og 3 i stedet for 1 og 2*: Noen kjørte `INSERT` to ganger. `IDENTITY` nullstilles ikke av `DELETE`; bruk `DBCC CHECKIDENT ('dw.DimKunde', RESEED, 0)` eller ignorer – nøkkelverdiene har ingen betydning. (Det er faktisk et poeng: surrogatnøkler *skal* være meningsløse.)
