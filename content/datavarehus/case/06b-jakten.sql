/* =====================================================================
   Nordhandel AS – optimaliseringsjakten (lab 6)
   Fil: case/06b-jakten.sql
   Mot den EKTE dw.FaktSalg (clustered på SalgKey + indekser på
   OrdreDatoKey, KundeKey, ProduktKey, OrdreId) – slik 02-dw-skjema.sql lager den.

   Til studentene: del ut bare «J1 FØR» … «J8 FØR». De skal finne feilen,
   rette den, og dokumentere lesninger/CPU før og etter.
   Til læreren: FASIT-blokkene. Minst én «feil» (J3) er en korrekthetsfeil,
   ikke en ytelsesfeil – studentene skal oppdage at tallet er galt.
   ===================================================================== */
USE NordhandelDW;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO

------------------------------------------------------------------------
PRINT '=== J1 FØR: omsetning én dag – dato som tekst ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktSalg WHERE CONVERT(VARCHAR(8), OrdreDatoKey) LIKE '20250312%';
SET STATISTICS IO OFF;
PRINT '=== J1 FASIT: sammenlign tallet med tallet, ikke en tekstversjon av det ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktSalg WHERE OrdreDatoKey = 20250312;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
PRINT '=== J2 FØR: per produkt – datoen for produktets største enkeltsalg, som korrelert subspørring per rad ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT p.Varenummer, p.Navn,
       (SELECT TOP (1) f.OrdreDatoKey FROM dw.FaktSalg f WHERE f.ProduktKey = p.ProduktKey ORDER BY f.NettoBelop DESC) AS StorsteSalgDato
FROM dw.DimProdukt p
WHERE p.ErGjeldende = 1;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
PRINT '=== J2 FASIT: vindusfunksjon – én gjennomlesning av fakta, rangér innenfor produkt ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
WITH Rangert AS (
    SELECT ProduktKey, OrdreDatoKey,
           ROW_NUMBER() OVER (PARTITION BY ProduktKey ORDER BY NettoBelop DESC) AS Rn
    FROM dw.FaktSalg
)
SELECT p.Varenummer, p.Navn, r.OrdreDatoKey AS StorsteSalgDato
FROM dw.DimProdukt p
LEFT JOIN Rangert r ON r.ProduktKey = p.ProduktKey AND r.Rn = 1
WHERE p.ErGjeldende = 1;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO
------------------------------------------------------------------------
PRINT '=== J3 FØR: omsetning per fylke 2025 – kjører raskt, men … ===';
SET STATISTICS IO ON;
SELECT k.Fylke, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
JOIN dw.DimDato d  ON d.DatoKey = f.OrdreDatoKey
WHERE d.Aar = 2025 AND k.ErGjeldende = 1
GROUP BY k.Fylke ORDER BY Omsetning DESC;
SET STATISTICS IO OFF;
PRINT '=== J3 FASIT: dette er ikke en ytelsesfeil – det er en KORREKTHETSFEIL. Totalen er for lav. ===';
SELECT Riktig = (SELECT SUM(f.NettoBelop) FROM dw.FaktSalg f JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey WHERE d.Aar = 2025),
       MedFeil = (SELECT SUM(f.NettoBelop) FROM dw.FaktSalg f JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey WHERE d.Aar = 2025 AND k.ErGjeldende = 1);
GO

------------------------------------------------------------------------
CREATE INDEX IX_Jakt_Postnummer ON dw.DimKunde (Postnummer) INCLUDE (KundeKey, ErGjeldende);
GO
PRINT '=== J4 FØR: kunder i Oslo sentrum – parameter fra applikasjonen kommer som NVARCHAR ===';
DECLARE @Postnummer NVARCHAR(10) = N'0150';
SET STATISTICS IO ON;
SELECT COUNT(*) AS Ordrelinjer
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
WHERE k.Postnummer = @Postnummer;
SET STATISTICS IO OFF;
GO
PRINT '=== J4 FASIT: parameterens type skal matche kolonnens (CHAR(4)) – eller konverter PARAMETEREN, aldri kolonnen ===';
DECLARE @Postnummer CHAR(4) = '0150';
SET STATISTICS IO ON;
SELECT COUNT(*) AS Ordrelinjer
FROM dw.FaktSalg f
JOIN dw.DimKunde k ON k.KundeKey = f.KundeKey
WHERE k.Postnummer = @Postnummer;
SET STATISTICS IO OFF;
GO
DROP INDEX IX_Jakt_Postnummer ON dw.DimKunde;
GO

------------------------------------------------------------------------
PRINT '=== J5 FØR: «fleksibel» rapportprosedyre med valgfrie filtre ===';
GO
CREATE OR ALTER PROCEDURE dw.Jakt_Rapport @Dato INT = NULL, @KundeKey INT = NULL AS
    SELECT COUNT(*), SUM(NettoBelop)
    FROM dw.FaktSalg
    WHERE (@Dato IS NULL OR OrdreDatoKey = @Dato)
      AND (@KundeKey IS NULL OR KundeKey = @KundeKey);
GO
SET STATISTICS IO ON;
EXEC dw.Jakt_Rapport @Dato = 20250312;
SET STATISTICS IO OFF;
GO
PRINT '=== J5 FASIT: OPTION (RECOMPILE) – planen lages for de faktiske parameterne ===';
GO
CREATE OR ALTER PROCEDURE dw.Jakt_Rapport @Dato INT = NULL, @KundeKey INT = NULL AS
    SELECT COUNT(*), SUM(NettoBelop)
    FROM dw.FaktSalg
    WHERE (@Dato IS NULL OR OrdreDatoKey = @Dato)
      AND (@KundeKey IS NULL OR KundeKey = @KundeKey)
    OPTION (RECOMPILE);
GO
SET STATISTICS IO ON;
EXEC dw.Jakt_Rapport @Dato = 20250312;
SET STATISTICS IO OFF;
DROP PROCEDURE dw.Jakt_Rapport;
GO

------------------------------------------------------------------------
PRINT '=== J6 FØR: årsrapport satt sammen med UNION (settene er disjunkte – UNION sorterer og dedupliserer for ingenting) ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT 2023 AS Aar, KundeKey, SUM(NettoBelop) AS Omsetning FROM dw.FaktSalg WHERE OrdreDatoKey BETWEEN 20230101 AND 20231231 GROUP BY KundeKey
UNION
SELECT 2024, KundeKey, SUM(NettoBelop) FROM dw.FaktSalg WHERE OrdreDatoKey BETWEEN 20240101 AND 20241231 GROUP BY KundeKey
UNION
SELECT 2025, KundeKey, SUM(NettoBelop) FROM dw.FaktSalg WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231 GROUP BY KundeKey;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
PRINT '=== J6 FASIT: UNION ALL når settene ikke overlapper – eller enda bedre: én GROUP BY ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT OrdreDatoKey / 10000 AS Aar, KundeKey, SUM(NettoBelop) AS Omsetning
FROM dw.FaktSalg
WHERE OrdreDatoKey BETWEEN 20230101 AND 20251231
GROUP BY OrdreDatoKey / 10000, KundeKey;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO

------------------------------------------------------------------------
PRINT '=== J7 FØR: omsetning i butikk per måned – join på en nøkkel FaktSalg ikke har indeks på ===';
SET STATISTICS IO ON;
SELECT f.OrdreDatoKey / 100 AS AarMaaned, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
WHERE oi.Kanal = N'Butikk' AND oi.ErGyldigSalg = 1
GROUP BY f.OrdreDatoKey / 100;
SET STATISTICS IO OFF;
PRINT '=== J7 FASIT: indeks på fremmednøkkelen – alle fire dimensjonsnøkler i en faktatabell skal ha en ===';
CREATE INDEX IX_FaktSalg_OrdreinfoKey ON dw.FaktSalg (OrdreinfoKey) INCLUDE (OrdreDatoKey, NettoBelop);
GO
SET STATISTICS IO ON;
SELECT f.OrdreDatoKey / 100 AS AarMaaned, SUM(f.NettoBelop) AS Omsetning
FROM dw.FaktSalg f
JOIN dw.DimOrdreinfo oi ON oi.OrdreinfoKey = f.OrdreinfoKey
WHERE oi.Kanal = N'Butikk' AND oi.ErGyldigSalg = 1
GROUP BY f.OrdreDatoKey / 100;
SET STATISTICS IO OFF;
DROP INDEX IX_FaktSalg_OrdreinfoKey ON dw.FaktSalg;
GO

------------------------------------------------------------------------
PRINT '=== J8 FØR: dekningsgrad via skalar funksjon – «ryddig», men kjøres rad for rad ===';
GO
CREATE OR ALTER FUNCTION dw.fnDekningsgrad (@Netto DECIMAL(12,2), @Kostnad DECIMAL(12,2))
RETURNS DECIMAL(5,2)
WITH INLINE = OFF          -- slik alle skalarfunksjoner oppførte seg før SQL Server 2019
AS BEGIN
    RETURN CASE WHEN @Netto = 0 THEN NULL ELSE CAST(100.0 * (@Netto - @Kostnad) / @Netto AS DECIMAL(5,2)) END;
END;
GO
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT OrdreDatoKey / 100 AS AarMaaned, AVG(dw.fnDekningsgrad(NettoBelop, Kostnad)) AS SnittDG
FROM dw.FaktSalg
WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231
GROUP BY OrdreDatoKey / 100;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO
PRINT '=== J8 FASIT: uttrykket inline (eller WITH INLINE = ON / 2019+ gjør det selv) – og forresten: AVG av forholdstall er feil, bruk SUM/SUM ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT OrdreDatoKey / 100 AS AarMaaned,
       CAST(100.0 * SUM(NettoBelop - Kostnad) / NULLIF(SUM(NettoBelop), 0) AS DECIMAL(5,2)) AS DG
FROM dw.FaktSalg
WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231
GROUP BY OrdreDatoKey / 100;
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
DROP FUNCTION dw.fnDekningsgrad;
GO
PRINT 'Jakten ferdig.';

