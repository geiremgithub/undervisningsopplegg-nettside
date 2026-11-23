---
title: "Quiz – test deg selv"
description: "30 spørsmål, fem per samling. Fasit ligger skjult bak «Vis fasit»."
order: 8
---

# Quiz – Datavarehus og dataintegrasjon

30 spørsmål, 5 per samling. Blanding av flervalg (F), kortsvar (K) og analyse (A). Åpen bok, ingen database. Veiledende tid: 60 minutter. Poeng i parentes; totalt 60.

Fasit følger etter hvert spørsmål, merket **Fasit**. Fjern fasit før utdeling.

---

## Samling 1 – Datavarehus og arkitektur

**1. (F, 1 p)** Hvilken av disse er *ikke* en av Inmons fire egenskaper ved et datavarehus?
a) Subject-oriented b) Integrated c) Normalized d) Time-variant e) Non-volatile

**Fasit:** c. Normalisering er en OLTP-egenskap; Inmon sier ingenting om normaliseringsgrad i definisjonen (selv om han anbefaler 3NF i kjernen).

**2. (K, 2 p)** Nordhandels markedssjef spør: «Hvor mye solgte vi til kunder i Rogaland i 2023?» Forklar med én–to setninger hvorfor kildesystemet `NordhandelShop` ikke kan gi et pålitelig svar.

**Fasit:** `Kunde.Postnummer` er kundens *nåværende* postnummer. En kunde som har flyttet fra Stavanger til Oslo etter 2023, får hele sin 2023-omsetning tilordnet Oslo. Kilden har ingen adressehistorikk.

**3. (F, 1 p)** Hva er hovedformålet med et staging-lag?
a) Å gjøre rapportene raskere b) Å frikoble uttrekk fra transformasjon, slik at feil i transformasjonen ikke krever ny lesing av kilden c) Å lagre historikk d) Å gi forretningsbrukere tilgang til rådata

**Fasit:** b. Staging er en rå, midlertidig kopi. Historikk ligger i kjernen; brukere skal ikke lese staging.

**4. (A, 3 p)** En kollega foreslår å erstatte datavarehuset med en lesereplika (read replica) av produksjonsdatabasen, «siden problemet bare er at rapportene belaster kassesystemet». Gi ett argument for og to argumenter mot.

**Fasit:** For: løser ytelses-/konfliktproblemet umiddelbart, uten modellering eller ETL. Mot (to av): (1) ingen historikk – prisen i mars i fjor er fortsatt borte; (2) ingen integrasjon – når CRM-data skal inn, finnes det ikke et sted å sette det; (3) ingen felles definisjoner – hver analytiker beregner «omsetning» selv; (4) kompleksiteten (rekursivt kategorihierarki osv.) er den samme.

**5. (K, 2 p)** `LEN('0566 ')` returnerer 4 i SQL Server. Hvilken funksjon avslører det etterfølgende mellomrommet, og hvorfor er dette relevant for datakvalitetskontroll?

**Fasit:** `DATALENGTH` (returnerer antall byte, inkludert mellomrom: 10 for NVARCHAR). Relevant fordi kontroller basert på `LEN` eller `=` (som også ignorerer mellomrom bak) vil rapportere verdien som gyldig, mens andre systemer (Python, case-sensitive databaser) ser en annen verdi. Datakvalitet avhenger av hvordan verktøyet tolker dataene.

---

## Samling 2 – Dimensjonsmodellering

**6. (F, 1 p)** Hva er «korn» (grain) i en faktatabell?
a) Antall rader b) Hva én rad representerer c) Primærnøkkelen d) Antall dimensjoner

**Fasit:** b.

**7. (A, 3 p)** `Ordre.Fraktkostnad` er per ordre; kornet i `FaktSalg` er ordrelinje. Nevn de tre vanlige måtene å håndtere dette på, og angi hvilken `NordhandelDW` valgte og hvorfor.

**Fasit:** (i) Egen faktatabell `FaktOrdre` med korn ordre; (ii) legg hele frakten på én linje (første), 0 på resten; (iii) alloker proporsjonalt (etter netto) på linjene. `NordhandelDW` valgte (iii) som `FraktAllokert`: summen per ordre blir riktig *og* fordelingen per kategori blir rimelig, uten å innføre en andre faktatabell. Kolonnenavnet signaliserer at det er en beregnet fordeling, ikke en målt verdi. Avrundingsrest legges på siste linje.

**8. (K, 2 p)** Hvorfor bruker vi `GyldigTil = '9999-12-31'` i stedet for `NULL` for gjeldende versjon i en SCD type 2-dimensjon?

**Fasit:** Oppslaget `WHERE @Dato BETWEEN GyldigFra AND GyldigTil` fungerer direkte. Med `NULL` må man skrive `AND (GyldigTil IS NULL OR @Dato <= GyldigTil)` – tregere, og lett å glemme.

**9. (F, 1 p)** Hvilken SCD-type passer best for `OpprinneligKundesegment` («segmentet kunden ble rekruttert i»)?
a) Type 0 b) Type 1 c) Type 2 d) Type 3

**Fasit:** a. Verdien skal aldri endres etter første lasting – det er definisjonen av attributtet.

**10. (A, 3 p)** En student har modellert `DimProdukt` som snøfnugg: `DimProdukt → DimUnderkategori → DimKategori → DimHovedkategori`, «fordi det er normalisert». Gi to argumenter for å flate det ut til stjerne, og ett tilfelle der snøfnugg likevel kan forsvares.

**Fasit:** For stjerne: (1) færre joins i hver rapport (rapport 1 går fra 5 til 2 joins) → enklere SQL og raskere; (2) forretningsbrukere i Power BI forstår en flat tabell; (3) redundansen er ufarlig fordi dimensjonen er liten (800 rader) og bare oppdateres kontrollert av ETL – oppdateringsanomalier kan ikke oppstå. Snøfnugg kan forsvares når et subhierarki deles av flere dimensjoner (f.eks. geografi brukt av både `DimKunde` og `DimButikk`), eller når dimensjonen er svært stor.

---

## Samling 3 – ETL og ELT

**11. (F, 1 p)** Vannmerket for inkrementell lasting bør settes til:
a) `MAX(SistEndret)` blant radene som ble lastet b) Starttidspunktet for uttrekket c) Sluttidspunktet for lastingen d) `GETDATE()` når jobben er ferdig

**Fasit:** b. Rader som endres mens uttrekket pågår kan ha `SistEndret` lavere enn `MAX` av det som ble lest, og vil da hoppes over med (a). Med starttid blir de med neste gang.

**12. (A, 3 p)** Forklar hva som skjer hvis `etl.LastFaktSalg` bruker `MERGE … WHEN NOT MATCHED BY SOURCE THEN DELETE` sammen med en inkrementell kilde (bare endrede ordrer i staging).

**Fasit:** Alle faktarader hvis `OrdrelinjeId` ikke finnes i *nattens* staging – altså alle uendrede ordrer, typisk 99,9 % av tabellen – blir «not matched by source» og **slettes**. Faktatabellen tømmes nesten helt. Sletting med inkrementell kilde må begrenses til ordrer man faktisk hentet (`EXISTS (… stg.Ordre …)`), og harde slettinger krever en egen avstemming mot hele nøkkelmengden.

**13. (K, 2 p)** Hvorfor skal type 1-oppdateringer (f.eks. rettet navn) treffe *alle* versjoner av en kunde, ikke bare den gjeldende?

**Fasit:** Ellers viser gamle versjoner fortsatt stavefeilen. Rapport 4 («kunder som har endret seg») ville sett ut som om to ulike personer flyttet, og filtrering på navn gir ulikt resultat avhengig av periode. Type 1 betyr «historikk er irrelevant for dette attributtet» – da skal det være likt overalt.

**14. (F, 1 p)** Hva er den beste håndteringen av en ordrelinje med `Antall = 0` i kilden?
a) Stopp lastingen og send feilmelding b) Last den med `Antall = 1` c) Hopp over den stille d) Hopp over den og logg den i karantene med alvorsgrad «Feil»

**Fasit:** d. Aldri stopp alt for én rad; aldri la en rad forsvinne usporet.

**15. (A, 3 p)** `etl.KjorAlt` skriver karantene- og steglogg *inne i* transaksjonen. Hva skjer med disse ved `ROLLBACK`, er det et problem, og nevn én løsning.

**Fasit:** De rulles tilbake og forsvinner; bare `etl.Kjoring`-raden (skrevet før `BEGIN TRY`) overlever med status Feil. Tap av steglogg er akseptabelt (ingenting ble lastet), men tap av karanteneradene er uheldig hvis dårlige data var *årsaken* til feilen – sporene er borte. Løsninger: skriv validering/karantene i et eget steg før transaksjonen; bruk en tabellvariabel (påvirkes ikke av rollback) og skriv den ut i `CATCH`; logg over separat tilkobling.

---

## Samling 4 – SQL for analyse

**16. (A, 3 p)** Spørringen `SUM(Belop) OVER (ORDER BY Dato)` gir «løpende sum». To ordrer har samme dato. Hva viser de to radene, hvorfor, og hvordan retter du det?

**Fasit:** Begge viser *samme* løpende sum (inkludert begge ordrer), fordi standardrammen med `ORDER BY` er `RANGE UNBOUNDED PRECEDING`, som inkluderer alle rader med samme sorteringsverdi (peers). Rett: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` – og legg til en tie-breaker i `ORDER BY` (f.eks. `OrdreId`) for determinisme.

**17. (F, 1 p)** Topp 10 produkter der flere kan dele en plass og man vil ha *alle* som er blant de 10 beste verdiene. Hvilken funksjon?
a) `ROW_NUMBER()` b) `RANK()` c) `DENSE_RANK()` d) `NTILE(10)`

**Fasit:** c. `RANK` gir hull etter likhet (6, 6, 8) og kan stoppe for tidlig; `ROW_NUMBER` kutter vilkårlig.

**18. (K, 2 p)** Hvorfor er `LAG(Omsetning, 12) OVER (ORDER BY AarMaaned)` en upålitelig måte å finne «samme måned i fjor» på, og hva er alternativet?

**Fasit:** `LAG(…, 12)` går 12 *rader* tilbake, ikke 12 måneder. Mangler én måned i datasettet, peker den på feil måned. Alternativ: `LAG(Omsetning) OVER (PARTITION BY Maaned ORDER BY Aar)` – eller et datostativ.

**19. (A, 3 p)** Rapporten «omsetning per fylke» skrives med `JOIN DimKunde k ON k.KundeKey = f.KundeKey WHERE k.ErGjeldende = 1`. Hva er galt, hva blir konsekvensen, og hvordan skriver du «kundens *nåværende* fylke» riktig?

**Fasit:** Filteret kaster alle faktarader som peker på utløpte versjoner – all omsetning fra *før* en kunde flyttet forsvinner (i caset 47,7 M av 2 411 M). Riktig for «nåværende fylke»: join på `KundeKey` for versjonen på salgstidspunktet, så en *andre* join til `DimKunde kn ON kn.KundeId = k.KundeId AND kn.ErGjeldende = 1`, og grupper på `kn.Fylke`. `ErGjeldende = 1` skal aldri være et filter på fakta-joinen.

**20. (K, 2 p)** Rullerende 30-dagers omsetning med `ROWS BETWEEN 29 PRECEDING AND CURRENT ROW` over daglige aggregater. Når gir dette feil svar, og hva er løsningen?

**Fasit:** Når det finnes dager uten salg – da dekker 30 *rader* mer enn 30 *dager*. Løsning: et datostativ (`DimDato CROSS JOIN` dimensjonsverdiene) med `LEFT JOIN` til aggregatet og `ISNULL(…, 0)`, så én rad alltid er én dag.

---

## Samling 5 – Indeksering

**21. (F, 1 p)** En nonclustered index på `OrdreDatoKey` finnes. Spørringen `WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331` (2 % av radene) bruker likevel Clustered Index Scan. Mest sannsynlig forklaring?
a) Indeksen er fragmentert b) Statistikken er feil c) Antall key lookups ville kostet mer enn en scan (tipping point) d) `BETWEEN` kan ikke bruke indekser

**Fasit:** c. ~11 000 lookups × 3 lesninger ≈ 33 000 > 7 900 for scan. Optimalisereren har rett.

**22. (K, 2 p)** Hva er en covering index, og hvilken klausul brukes for å gjøre en indeks dekkende uten å gjøre indeksnøkkelen bredere?

**Fasit:** En indeks som inneholder alle kolonnene en spørring trenger, slik at ingen key lookup er nødvendig. `INCLUDE (…)` legger kolonner på bladnivå uten å ta dem inn i nøkkelen (ikke sortert, ikke i mellomnivåene → billigere å vedlikeholde).

**23. (A, 3 p)** Du har indeksen `(KundeKey, OrdreDatoKey) INCLUDE (NettoBelop)`. For hver av disse: kan indeksen brukes til *seek*? Begrunn kort.
(i) `WHERE KundeKey = 5` (ii) `WHERE KundeKey = 5 AND OrdreDatoKey > 20250101` (iii) `WHERE OrdreDatoKey > 20250101`

**Fasit:** (i) Ja – ledende kolonne. (ii) Ja – likhet på ledende kolonne, deretter område på neste. (iii) **Nei** – `OrdreDatoKey` er ikke ledende; indeksen er sortert på kunde først. Blir index scan (eller tabellscan). Telefonkatalog: etternavn, så fornavn.

**24. (F, 1 p)** Hvilken tabell i `NordhandelDW` er den *dårligste* kandidaten for clustered columnstore?
a) `FaktSalg` b) `DimKunde` c) `stg.Ordrelinje` d) En fremtidig `FaktLagerbeholdning` med 50 M rader

**Fasit:** b. Dimensjoner er små, slås opp punktvis av ETL (`KundeId` + `BETWEEN`) og oppdateres radvis (SCD). Columnstore er dårlig til alt dette. (`stg.*` skal ikke ha indekser i det hele tatt, men det er ikke columnstore-spesifikt.)

**25. (A, 3 p)** Lasting av 100 000 rader tok 0,5 s uten nonclustered indekser og 3,7 s med seks. Nordhandel laster 600 rader per natt. Bør de droppe og gjenskape indeksene rundt lastingen? Begrunn med tall.

**Fasit:** Nei. 600 rader × 37 µs ≈ 22 ms ekstra per natt – ubetydelig. Drop/recreate lønner seg når nattens lasting er en stor andel av tabellen (>10–20 %) og rebuild (sekvensiell skriving) er raskere enn inkrementelt vedlikehold (tilfeldig skriving). Tallene man trenger: lastetid med indekser, lastetid uten + rebuild-tid, og nattevinduets lengde. Mål, ikke anta.

---

## Samling 6 – Spørringsoptimalisering

**26. (F, 1 p)** I en actual execution plan er «Estimated Number of Rows» 1 og «Actual Number of Rows» 20 000 for en operator. Mest sannsynlig årsak?
a) Fragmentering b) Utdatert eller manglende statistikk c) Manglende indeks d) For lite minne

**Fasit:** b. (Eller noe optimalisereren ikke kan estimere – funksjoner, tabellvariabler på eldre versjoner – men statistikk er førstevalget.)

**27. (K, 2 p)** Skriv om `WHERE YEAR(Ordredato) = 2025 AND MONTH(Ordredato) = 3` så det blir SARGable, og forklar med én setning hvorfor originalen ikke er det.

**Fasit:** `WHERE Ordredato >= '2025-03-01' AND Ordredato < '2025-04-01'`. Originalen bruker funksjoner på kolonnen; optimalisereren kan ikke oversette «rader der `YEAR()` gir 2025» til et område i indeksen uten å evaluere funksjonen for hver rad.

**28. (A, 3 p)** En rapportprosedyre med `@Fra, @Til` er lynrask noen dager og tar ti minutter andre dager, uten at data eller kode er endret. Hva heter fenomenet, hva er mekanismen, og nevn to løsninger.

**Fasit:** Parameter sniffing. Planen kompileres for parameterverdiene ved *første* kall etter at cachen ble tømt (restart, statistikkoppdatering, …) og gjenbrukes for alle senere kall. En plan laget for «én dag» (seek + lookup) brukt på «hele året» gir hundretusener av lookups. Løsninger: `OPTION (RECOMPILE)`; `OPTIMIZE FOR (@Fra UNKNOWN)`; Query Store med tvungen plan; covering index så planen er god uansett.

**29. (K, 2 p)** Hva er den *viktigste* gevinsten ved å partisjonere en stor faktatabell på dato – og hva er det *ikke*?

**Fasit:** Forvaltning: `SWITCH IN` av en ny periode og `SWITCH OUT` av gamle på millisekunder, uten låsing eller logg-vekst; vedlikehold (rebuild, statistikk, komprimering) per partisjon. Det er *ikke* primært en spørringsytelsesteknikk – en clustered index på dato gir samme partition-elimination-effekt for datofiltre, og spørringer *uten* datofilter blir tregere på en partisjonert tabell.

**30. (A, 3 p)** Du får spørringen under med beskjeden «den er treg, optimaliser den». Hva gjør du *først*, og hvorfor?

```sql
SELECT k.Fylke, SUM(f.NettoBelop)
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
JOIN dw.DimDato d  ON d.DatoKey = f.OrdreDatoKey
WHERE d.Aar = 2025 AND k.ErGjeldende = 1
GROUP BY k.Fylke;
```

**Fasit:** Først sjekker du om **svaret er riktig** – og det er det ikke: `k.ErGjeldende = 1` på fakta-joinen kaster all omsetning fra før kunders flytting (SCD2-feilen). En rask, gal rapport er verre enn en treg, riktig. Fjern filteret, verifiser totalen mot en enkel `SUM` uten dimensjonsjoin, og *deretter* mål lesninger og se på planen. Ytelsesarbeid starter alltid med å bekrefte at tallet er det rette tallet.

---

## Poengfordeling

| Samling | Spørsmål | Poeng |
|---|---|---|
| 1 | 1–5 | 9 |
| 2 | 6–10 | 10 |
| 3 | 11–15 | 10 |
| 4 | 16–20 | 11 |
| 5 | 21–25 | 10 |
| 6 | 26–30 | 11 |
| **Sum** | | **61** → skaleres til 60 |

Karaktergrenser (forslag): A ≥ 90 %, B ≥ 80 %, C ≥ 65 %, D ≥ 50 %, E ≥ 40 %.
