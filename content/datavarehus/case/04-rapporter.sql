/* =====================================================================
   Nordhandel AS – analytisk SQL: demoer og de seks rapportene
   Fil: case/04-rapporter.sql
   Forutsetter fylt NordhandelDW (03-etl.sql + 04a-simuler-endringer.sql).
   Fasit for lab 4 og rapport-delen av mappeinnlevering 2.

   Innhold
     Demo 4.1  OVER() trinn for trinn: total, PARTITION BY, løpende sum, ROWS vs RANGE
     Demo 4.2  ROW_NUMBER / RANK / DENSE_RANK / NTILE
     Demo 4.3  LAG / LEAD – måned mot måned, samme måned i fjor
     Demo 4.4  CTE vs. subspørring, rekursiv CTE
     Demo 4.5  SCD type 2 i rapporter: riktig (A, B) og galt (C) i stor skala
     Rapport 1 Omsetning og dekningsbidrag per måned per hovedkategori (med ROLLUP)
     Rapport 2 Topp 10 produkter per kvartal med endring i rangering
     Rapport 3 Kundeomsetning år-over-år med vekstprosent
     Rapport 4 Kunder som har flyttet – omsetning før og etter
     Rapport 5 Rullerende 30-dagers omsetning per kanal (naiv vs. riktig)
     Rapport 6 Returandel per merke per kvartal
     Utfordring Kohortanalyse
   ===================================================================== */
USE NordhandelDW;
GO
SET NOCOUNT ON;

------------------------------------------------------------------------
-- Demo 4.1  OVER() trinn for trinn – på kunde 1 (den mest aktive)
------------------------------------------------------------------------
-- Først: aggreger til ordrenivå. Vindusfunksjoner jobber på RADER, og vi vil ha én rad per ordre.
WITH Ordre AS (
    SELECT f.OrdreId, f.OrdreDatoKey, d.Aar, SUM(f.NettoBelop) AS Belop
    FROM dw.FaktSalg f
    JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
    JOIN dw.DimDato d  ON d.DatoKey = f.OrdreDatoKey
    WHERE k.KundeId = 1 AND d.Aar = 2023
    GROUP BY f.OrdreId, f.OrdreDatoKey, d.Aar
)
SELECT TOP (12)
    OrdreId, OrdreDatoKey, Belop,
    -- 1. Hele vinduet: totalen gjentatt på hver rad → andel
    SUM(Belop) OVER ()                                              AS Total,
    CAST(100.0 * Belop / SUM(Belop) OVER () AS DECIMAL(5,2))        AS AndelPst,
    -- 2. Partisjon: én sum per kvartal
    SUM(Belop) OVER (PARTITION BY OrdreDatoKey / 100)               AS MaanedTotal,
    -- 3. ORDER BY uten ramme = RANGE UNBOUNDED PRECEDING: like datoer får SAMME løpende sum
    SUM(Belop) OVER (ORDER BY OrdreDatoKey)                         AS LopendeRANGE,
    -- 4. ROWS: én rad om gangen, uansett like datoer
    SUM(Belop) OVER (ORDER BY OrdreDatoKey
                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS LopendeROWS,
    -- 5. Glidende: denne og de to forrige ordrene
    AVG(Belop) OVER (ORDER BY OrdreDatoKey, OrdreId
                     ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)         AS Snitt3
FROM Ordre
ORDER BY OrdreDatoKey, OrdreId;
GO

------------------------------------------------------------------------
-- Demo 4.2  Rangering – produkter etter antall solgt i mars 2025 (heltall → mange like verdier)
------------------------------------------------------------------------
WITH Salg AS (
    SELECT p.Varenummer, p.Navn, SUM(f.Antall) AS Antall
    FROM dw.FaktSalg f
    JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
    JOIN dw.DimDato d    ON d.DatoKey = f.OrdreDatoKey
    WHERE d.AarMaaned = '2025-03'
    GROUP BY p.Varenummer, p.Navn
)
SELECT TOP (15)
    Varenummer, Antall,
    ROW_NUMBER() OVER (ORDER BY Antall DESC)  AS RowNumber,   -- 1,2,3,4,5…  alltid unik, vilkårlig ved likhet
    RANK()       OVER (ORDER BY Antall DESC)  AS Rank,        -- 1,2,2,4,5…  hull etter likhet
    DENSE_RANK() OVER (ORDER BY Antall DESC)  AS DenseRank,   -- 1,2,2,3,4…  ingen hull
    NTILE(4)     OVER (ORDER BY Antall DESC)  AS Kvartil      -- deler i 4 like store grupper
FROM Salg
ORDER BY Antall DESC, Varenummer;
GO

------------------------------------------------------------------------
-- Demo 4.3  LAG / LEAD – månedsomsetning med endring
------------------------------------------------------------------------
WITH Maaned AS (
    SELECT d.AarMaaned, d.Aar, d.Maaned, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar BETWEEN 2023 AND 2025
    GROUP BY d.AarMaaned, d.Aar, d.Maaned
)
SELECT AarMaaned, Omsetning,
       ForrigeMaaned  = LAG(Omsetning)  OVER (ORDER BY AarMaaned),
       EndringPst     = CAST(100.0 * (Omsetning - LAG(Omsetning) OVER (ORDER BY AarMaaned))
                             / NULLIF(LAG(Omsetning) OVER (ORDER BY AarMaaned), 0) AS DECIMAL(6,1)),
       -- Samme måned i fjor: LAG(…, 12) forutsetter at ALLE måneder finnes. Tryggere: PARTITION BY Maaned ORDER BY Aar
       SammeMaanedIFjor = LAG(Omsetning) OVER (PARTITION BY Maaned ORDER BY Aar),
       AarOverAarPst  = CAST(100.0 * (Omsetning - LAG(Omsetning) OVER (PARTITION BY Maaned ORDER BY Aar))
                             / NULLIF(LAG(Omsetning) OVER (PARTITION BY Maaned ORDER BY Aar), 0) AS DECIMAL(6,1)),
       NesteMaaned    = LEAD(Omsetning) OVER (ORDER BY AarMaaned)
FROM Maaned
ORDER BY AarMaaned;
GO

------------------------------------------------------------------------
-- Demo 4.4  CTE vs. subspørring; rekursiv CTE
------------------------------------------------------------------------
-- 4.4a Samme spørsmål («kunder som handlet for mer enn snittet i 2025») på to måter
-- Nøstede subspørringer: må leses innenfra og ut
SELECT k.KundeId, x.Belop
FROM (SELECT f.KundeKey, SUM(f.NettoBelop) AS Belop
      FROM dw.FaktSalg f JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey
      WHERE d.Aar = 2025 GROUP BY f.KundeKey) x
JOIN dw.DimKunde k ON k.KundeKey = x.KundeKey
WHERE x.Belop > (SELECT AVG(Belop) FROM
                   (SELECT SUM(f.NettoBelop) AS Belop
                    FROM dw.FaktSalg f JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey
                    WHERE d.Aar = 2025 GROUP BY f.KundeKey) y)
ORDER BY x.Belop DESC;

-- CTE: leses ovenfra og ned, hvert steg har et navn, ingen gjentakelse
WITH PerKunde AS (
    SELECT k.KundeId, SUM(f.NettoBelop) AS Belop           -- NB: KundeId, ikke KundeKey – slå sammen versjoner
    FROM dw.FaktSalg f
    JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
    JOIN dw.DimDato d  ON d.DatoKey = f.OrdreDatoKey
    WHERE d.Aar = 2025
    GROUP BY k.KundeId
),
Snitt AS (
    SELECT AVG(Belop) AS SnittBelop FROM PerKunde
)
SELECT p.KundeId, p.Belop, s.SnittBelop
FROM PerKunde p
CROSS JOIN Snitt s
WHERE p.Belop > s.SnittBelop
ORDER BY p.Belop DESC;

-- 4.4b Rekursiv CTE: kategorihierarkiet som sti. I DW trengs den ikke – ETL har flatet ut.
WITH H AS (
    SELECT KategoriId, Navn, ForelderId, 1 AS Nivaa, CAST(Navn AS NVARCHAR(400)) AS Sti
    FROM stg.Kategori WHERE ForelderId IS NULL
    UNION ALL
    SELECT k.KategoriId, k.Navn, k.ForelderId, h.Nivaa + 1, CAST(h.Sti + N' > ' + k.Navn AS NVARCHAR(400))
    FROM stg.Kategori k JOIN H h ON h.KategoriId = k.ForelderId
)
SELECT KategoriId, Nivaa, REPLICATE('   ', Nivaa - 1) + Navn AS Innrykk, Sti
FROM H ORDER BY Sti;

-- Samme informasjon i DW: ingen rekursjon
SELECT DISTINCT Hovedkategori, Kategori, Underkategori FROM dw.DimProdukt WHERE Hovedkategori <> N'Ukjent' ORDER BY 1, 2, 3;
GO

------------------------------------------------------------------------
-- Demo 4.5  SCD type 2 i rapporter – omsetning per fylke, alle år
------------------------------------------------------------------------
-- A: fylke på kjøpstidspunktet (bare join på surrogatnøkkel)
SELECT k.Fylke, SUM(f.NettoBelop) AS Omsetning, COUNT(*) AS Linjer
FROM dw.FaktSalg f JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
GROUP BY k.Fylke ORDER BY Omsetning DESC;

-- B: kundens nåværende fylke (hopp til gjeldende versjon via forretningsnøkkelen)
SELECT kn.Fylke, SUM(f.NettoBelop) AS Omsetning, COUNT(*) AS Linjer
FROM dw.FaktSalg f
JOIN dw.DimKunde k  ON k.KundeKey = f.KundeKey
JOIN dw.DimKunde kn ON kn.KundeId = k.KundeId AND kn.ErGjeldende = 1
GROUP BY kn.Fylke ORDER BY Omsetning DESC;

-- C: FEIL – filteret kaster alle faktarader som peker på utløpte versjoner
SELECT k.Fylke, SUM(f.NettoBelop) AS Omsetning, COUNT(*) AS Linjer
FROM dw.FaktSalg f JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
WHERE k.ErGjeldende = 1
GROUP BY k.Fylke ORDER BY Omsetning DESC;

-- Hvor mye forsvant i C?
SELECT Totalt = (SELECT SUM(NettoBelop) FROM dw.FaktSalg),
       MedC   = (SELECT SUM(f.NettoBelop) FROM dw.FaktSalg f JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey WHERE k.ErGjeldende = 1),
       Tapt   = (SELECT SUM(NettoBelop) FROM dw.FaktSalg)
              - (SELECT SUM(f.NettoBelop) FROM dw.FaktSalg f JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey WHERE k.ErGjeldende = 1);
GO

------------------------------------------------------------------------
-- Rapport 1  Omsetning og dekningsbidrag per måned per hovedkategori, 2025
--            ROLLUP gir delsummer per måned og totalsum; GROUPING() skiller delsum fra data
------------------------------------------------------------------------
SELECT  CASE WHEN GROUPING(d.AarMaaned) = 1 THEN N'Totalt 2025' ELSE d.AarMaaned END   AS Maaned,
        CASE WHEN GROUPING(p.Hovedkategori) = 1 THEN N'Alle kategorier' ELSE p.Hovedkategori END AS Hovedkategori,
        SUM(f.NettoBelop)                                                  AS Omsetning,
        SUM(f.Dekningsbidrag)                                              AS Dekningsbidrag,
        CAST(100.0 * SUM(f.Dekningsbidrag) / NULLIF(SUM(f.NettoBelop), 0) AS DECIMAL(5,1)) AS DGPst,
        COUNT(DISTINCT f.OrdreId)                                          AS Ordrer
FROM    dw.FaktSalg f
JOIN    dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
JOIN    dw.DimProdukt p    ON p.ProduktKey = f.ProduktKey
JOIN    dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
WHERE   d.Aar = 2025 AND oi.ErGyldigSalg = 1
GROUP BY ROLLUP (d.AarMaaned, p.Hovedkategori)
ORDER BY GROUPING(d.AarMaaned), d.AarMaaned, GROUPING(p.Hovedkategori), p.Hovedkategori;
GO

------------------------------------------------------------------------
-- Rapport 2  Topp 10 produkter per kvartal, med endring i rangering fra forrige kvartal
------------------------------------------------------------------------
WITH PerKvartal AS (
    SELECT d.KvartalNavn, p.ProduktId, MAX(p.Varenummer) AS Varenummer, MAX(p.Navn) AS Navn,   -- ProduktId: slå sammen versjoner
           SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimProdukt p    ON p.ProduktKey = f.ProduktKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar = 2025
    GROUP BY d.KvartalNavn, p.ProduktId
),
Rangert AS (
    SELECT *,
           Plass = DENSE_RANK() OVER (PARTITION BY KvartalNavn ORDER BY Omsetning DESC)
    FROM PerKvartal
),
MedForrige AS (
    SELECT *,
           ForrigePlass = LAG(Plass) OVER (PARTITION BY ProduktId ORDER BY KvartalNavn)   -- produktets plass forrige kvartal (blant ALLE produkter)
    FROM Rangert
)
SELECT KvartalNavn, Plass, Varenummer, Navn, Omsetning,
       ForrigePlass,
       Endring = CASE WHEN ForrigePlass IS NULL THEN N'ny'
                      WHEN ForrigePlass > Plass THEN CONCAT(N'▲ ', ForrigePlass - Plass)
                      WHEN ForrigePlass < Plass THEN CONCAT(N'▼ ', Plass - ForrigePlass)
                      ELSE N'=' END
FROM MedForrige
WHERE Plass <= 10                 -- kan ikke stå i Rangert: vindusfunksjon kan ikke filtreres der den defineres
ORDER BY KvartalNavn, Plass;
GO

------------------------------------------------------------------------
-- Rapport 3  Kundeomsetning år-over-år med vekstprosent (topp 20 etter 2025-omsetning)
------------------------------------------------------------------------
WITH PerAar AS (
    SELECT k.KundeId, MAX(k.Navn) AS Navn, d.Aar, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimKunde k      ON k.KundeKey = f.KundeKey
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar BETWEEN 2023 AND 2025
    GROUP BY k.KundeId, d.Aar
),
MedForrige AS (
    SELECT *,
           ForrigeAar      = LAG(Aar)       OVER (PARTITION BY KundeId ORDER BY Aar),
           ForrigeOmsetning = LAG(Omsetning) OVER (PARTITION BY KundeId ORDER BY Aar)
    FROM PerAar
),
Beregnet AS (
    SELECT KundeId, Navn, Aar, Omsetning,
           -- Fellen: LAG gir forrige RAD. Hvis kunden ikke handlet i fjor, er forrige rad to år gammel.
           IFjor = CASE WHEN ForrigeAar = Aar - 1 THEN ForrigeOmsetning END,
           VekstPst = CASE WHEN ForrigeAar = Aar - 1
                           THEN CAST(100.0 * (Omsetning - ForrigeOmsetning) / NULLIF(ForrigeOmsetning, 0) AS DECIMAL(7,1)) END
    FROM MedForrige
)
SELECT TOP (20) KundeId, Navn, Aar, Omsetning, IFjor, VekstPst
FROM Beregnet
WHERE Aar = 2025
ORDER BY Omsetning DESC;
GO

------------------------------------------------------------------------
-- Rapport 4  Kunder som har flyttet mellom fylker – omsetning før og etter
------------------------------------------------------------------------
WITH Flyttet AS (
    SELECT KundeId FROM dw.DimKunde GROUP BY KundeId HAVING COUNT(DISTINCT Fylke) > 1
)
SELECT  k.KundeId, k.Navn, k.Fylke,
        Periode = CASE WHEN k.ErGjeldende = 1 THEN N'Etter flytting' ELSE N'Før flytting' END,
        k.GyldigFra, k.GyldigTil,
        Omsetning = SUM(f.NettoBelop),
        Ordrer    = COUNT(DISTINCT f.OrdreId),
        SnittPerOrdre = CAST(SUM(f.NettoBelop) / NULLIF(COUNT(DISTINCT f.OrdreId), 0) AS DECIMAL(10,0))
FROM    dw.FaktSalg f
JOIN    dw.DimKunde k ON k.KundeKey = f.KundeKey            -- versjonen på kjøpstidspunktet – INGEN ErGjeldende-filter
JOIN    Flyttet fl    ON fl.KundeId = k.KundeId
GROUP BY k.KundeId, k.Navn, k.Fylke, k.ErGjeldende, k.GyldigFra, k.GyldigTil
ORDER BY k.KundeId, k.GyldigFra;
GO

------------------------------------------------------------------------
-- Rapport 5  Rullerende 30-dagers omsetning per kanal
------------------------------------------------------------------------
-- 5a NAIV: ROWS 29 PRECEDING teller RADER. Finnes det dager uten salg, dekker vinduet mer enn 30 dager.
WITH Daglig AS (
    SELECT oi.Kanal, d.Dato, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar = 2025
    GROUP BY oi.Kanal, d.Dato
)
SELECT Kanal, Dato, Omsetning,
       Rull30Naiv = SUM(Omsetning) OVER (PARTITION BY Kanal ORDER BY Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
       DagerIVindu = DATEDIFF(day, LAG(Dato, 29) OVER (PARTITION BY Kanal ORDER BY Dato), Dato) + 1   -- skal være 30
FROM Daglig
WHERE Dato >= '2025-02-01'
ORDER BY Kanal, Dato;

-- 5b RIKTIG: bygg et «datostativ» (date spine) av alle dager × alle kanaler, LEFT JOIN salget, så ROWS 29 PRECEDING = 30 dager
WITH Stativ AS (
    SELECT d.Dato, k.Kanal
    FROM dw.DimDato d
    CROSS JOIN (SELECT DISTINCT Kanal FROM dw.DimOrdreinfo WHERE Kanal <> N'Ukjent') k
    WHERE d.Aar = 2025
),
Daglig AS (
    SELECT oi.Kanal, d.Dato, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar = 2025
    GROUP BY oi.Kanal, d.Dato
)
SELECT s.Kanal, s.Dato,
       Omsetning = ISNULL(dg.Omsetning, 0),
       Rull30    = SUM(ISNULL(dg.Omsetning, 0)) OVER (PARTITION BY s.Kanal ORDER BY s.Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
       Snitt30   = CAST(AVG(ISNULL(dg.Omsetning, 0)) OVER (PARTITION BY s.Kanal ORDER BY s.Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS DECIMAL(12,0))
FROM Stativ s
LEFT JOIN Daglig dg ON dg.Kanal = s.Kanal AND dg.Dato = s.Dato
WHERE s.Dato >= '2025-02-01'
ORDER BY s.Kanal, s.Dato;

-- 5c Fellen gjort synlig: samme teknikk på en glissen serie (Devold i Butikk), bare dagene der naiv ≠ riktig
WITH Daglig AS (
    SELECT d.Dato, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSalg f
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    JOIN dw.DimProdukt p    ON p.ProduktKey = f.ProduktKey
    WHERE oi.ErGyldigSalg = 1 AND d.Aar = 2025 AND oi.Kanal = N'Butikk' AND p.Merke = N'Devold'
    GROUP BY d.Dato
),
Naiv AS (
    SELECT Dato, Omsetning,
           Rull30Naiv = SUM(Omsetning) OVER (ORDER BY Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),
           DagerIVindu = DATEDIFF(day, LAG(Dato, 29) OVER (ORDER BY Dato), Dato) + 1
    FROM Daglig
),
Riktig AS (
    SELECT d.Dato,
           Rull30 = SUM(ISNULL(dg.Omsetning, 0)) OVER (ORDER BY d.Dato ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
    FROM dw.DimDato d
    LEFT JOIN Daglig dg ON dg.Dato = d.Dato
    WHERE d.Aar = 2025
)
SELECT TOP (10) n.Dato, n.Omsetning, n.Rull30Naiv, r.Rull30, Avvik = n.Rull30Naiv - r.Rull30, n.DagerIVindu
FROM Naiv n JOIN Riktig r ON r.Dato = n.Dato
WHERE n.Rull30Naiv <> r.Rull30
ORDER BY ABS(n.Rull30Naiv - r.Rull30) DESC;
GO

------------------------------------------------------------------------
-- Rapport 6  Returandel per merke per kvartal
------------------------------------------------------------------------
SELECT  d.KvartalNavn, p.Merke,
        Salg      = SUM(f.NettoBelop),
        Returnert = SUM(CASE WHEN oi.ErReturnert = 1 THEN f.NettoBelop ELSE 0 END),
        ReturandelPst = CAST(100.0 * SUM(CASE WHEN oi.ErReturnert = 1 THEN f.NettoBelop ELSE 0 END)
                             / NULLIF(SUM(f.NettoBelop), 0) AS DECIMAL(5,2)),
        -- Bonus: merkets plassering i kvartalet etter returandel (vindusfunksjon over et aggregat)
        Plass = RANK() OVER (PARTITION BY d.KvartalNavn
                             ORDER BY SUM(CASE WHEN oi.ErReturnert = 1 THEN f.NettoBelop ELSE 0 END) / NULLIF(SUM(f.NettoBelop), 0) DESC)
FROM    dw.FaktSalg f
JOIN    dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
JOIN    dw.DimProdukt p    ON p.ProduktKey = f.ProduktKey
JOIN    dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
WHERE   oi.ErGyldigSalg = 1 AND d.Aar = 2025
GROUP BY d.KvartalNavn, p.Merke
ORDER BY d.KvartalNavn, Plass;
GO

------------------------------------------------------------------------
-- Utfordring  Kohortanalyse: omsetning per kundens første-kjøps-måned × måneder siden første kjøp
------------------------------------------------------------------------
WITH Ordre AS (
    SELECT k.KundeId, d.Dato, d.AarMaaned, f.NettoBelop
    FROM dw.FaktSalg f
    JOIN dw.DimKunde k      ON k.KundeKey = f.KundeKey
    JOIN dw.DimDato d       ON d.DatoKey = f.OrdreDatoKey
    JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
    WHERE oi.ErGyldigSalg = 1
),
MedKohort AS (
    SELECT *,
           KohortMaaned = MIN(AarMaaned) OVER (PARTITION BY KundeId),          -- kundens første kjøpsmåned
           ForsteDato   = MIN(Dato)      OVER (PARTITION BY KundeId)
    FROM Ordre
),
Beregnet AS (
    SELECT KohortMaaned, KundeId, NettoBelop,
           MaanederSiden = DATEDIFF(month, ForsteDato, Dato)
    FROM MedKohort
    WHERE KohortMaaned >= '2025-01'                                            -- kohorter rekruttert i 2025
),
Kohort AS (
    SELECT KohortMaaned,
           AntallKunder = COUNT(DISTINCT KundeId),
           MaanederSiden,
           Omsetning = SUM(NettoBelop)
    FROM Beregnet
    GROUP BY KohortMaaned, MaanederSiden
)
SELECT KohortMaaned,
       Kunder = MAX(CASE WHEN MaanederSiden = 0 THEN AntallKunder END),
       M0 = SUM(CASE WHEN MaanederSiden = 0 THEN Omsetning END),
       M1 = SUM(CASE WHEN MaanederSiden = 1 THEN Omsetning END),
       M2 = SUM(CASE WHEN MaanederSiden = 2 THEN Omsetning END),
       M3 = SUM(CASE WHEN MaanederSiden = 3 THEN Omsetning END),
       M4 = SUM(CASE WHEN MaanederSiden = 4 THEN Omsetning END),
       M5 = SUM(CASE WHEN MaanederSiden = 5 THEN Omsetning END)
FROM Kohort
GROUP BY KohortMaaned
ORDER BY KohortMaaned;
GO
