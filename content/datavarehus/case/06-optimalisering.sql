/* =====================================================================
   Nordhandel AS – spørringsoptimalisering: målte eksperimenter
   Fil: case/06-optimalisering.sql
   Forutsetter samling 5 (dw.FaktLab clustered på (OrdreDatoKey, SalgKey),
   dw.FaktLabCS columnstore). Kjør i SSMS med Ctrl+M på.

   Innhold
     S   Statistikk: utdatert histogram → feil estimat → feil plan
     F1  Ikke-SARGable predikat
     F2  Implisitt konvertering
     F3  SELECT * ødelegger covering
     F4  OR på tvers av kolonner
     F5  Tabellvariabel vs. temp-tabell
     F6  Parameter sniffing
     F7  Manglende indeks på fremmednøkkel
     P   Partisjonering: elimination, SWITCH IN, og prisen
   ===================================================================== */
USE NordhandelDW;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;   -- DimKunde har filtrert indeks
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- S  Statistikk
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktStat;
SELECT * INTO dw.FaktStat FROM dw.FaktLab WHERE OrdreDatoKey < 20260101;      -- alt t.o.m. 2025
CREATE CLUSTERED INDEX CX ON dw.FaktStat (SalgKey);
CREATE INDEX IX_Dato ON dw.FaktStat (OrdreDatoKey);                            -- gir statistikk på OrdreDatoKey
GO
PRINT '=== S1 Histogrammets siste trinn FØR ny data (RANGE_HI_KEY) ===';
DBCC SHOW_STATISTICS ('dw.FaktStat', 'IX_Dato') WITH HISTOGRAM, NO_INFOMSGS;
GO
-- Legg inn 20 000 rader for januar 2026 – UNDER auto-update-terskelen (sqrt(1000 × 580 000) ≈ 24 000)
INSERT INTO dw.FaktStat
SELECT TOP (20000) SalgKey + 10000000, 20260100 + 1 + (SalgKey % 28), KundeKey, ProduktKey, OrdreinfoKey, OrdreId, OrdrelinjeId + 10000000,
       Antall, BruttoBelop, RabattBelop, NettoBelop, Kostnad, FraktAllokert, Enhetspris, RabattProsent
FROM dw.FaktLab ORDER BY SalgKey;
GO
PRINT '=== S2 Spørring på 2026 med UTDATERT statistikk, NY kardinalitetsestimator (2014+): bruker modification_counter → fornuftig estimat → scan ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktStat WHERE OrdreDatoKey >= 20260101;
SET STATISTICS IO OFF;
GO
PRINT '=== S3 Samme spørring med GAMMEL estimator (før 2014, og fortsatt i mange databaser med gammelt kompatibilitetsnivå): verdier over histogrammets maks estimeres til 1 rad → seek + 20 000 lookups ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktStat WHERE OrdreDatoKey >= 20260101
OPTION (USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
SET STATISTICS IO OFF;
GO
PRINT '=== S3b Hva vet optimalisereren? modification_counter = 20 000, under terskelen sqrt(1000 × rader) ≈ 24 000 ===';
SELECT s.name, sp.last_updated, sp.rows, sp.rows_sampled, sp.modification_counter,
       Terskel = CAST(SQRT(1000.0 * sp.rows) AS INT)
FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = OBJECT_ID('dw.FaktStat') AND s.name = 'IX_Dato';
GO
UPDATE STATISTICS dw.FaktStat IX_Dato WITH FULLSCAN;
GO
PRINT '=== S4 Gammel estimator med OPPDATERT statistikk → riktig estimat → scan ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktStat WHERE OrdreDatoKey >= 20260101
OPTION (USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
SET STATISTICS IO OFF;
GO
PRINT '=== S5 Histogrammets siste trinn ETTER ===';
DBCC SHOW_STATISTICS ('dw.FaktStat', 'IX_Dato') WITH HISTOGRAM, NO_INFOMSGS;
GO
DROP TABLE dw.FaktStat;
GO

------------------------------------------------------------------------
-- F1  Ikke-SARGable: funksjon på kolonnen i WHERE
------------------------------------------------------------------------
PRINT '=== F1a Funksjon på kolonnen: OrdreDatoKey / 100 = 202503 → scan ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey / 100 = 202503;
SET STATISTICS IO OFF;
PRINT '=== F1b Samme filter som område → seek ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
PRINT '=== F1c Via DimDato med YEAR()/MONTH() – ser riktig ut, men… ===';
SET STATISTICS IO ON;
SELECT SUM(f.NettoBelop) FROM dw.FaktLab f JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey
WHERE YEAR(d.Dato) = 2025 AND MONTH(d.Dato) = 3;
SET STATISTICS IO OFF;
PRINT '=== F1d …kolonnene finnes ferdig beregnet i dimensjonen ===';
SET STATISTICS IO ON;
SELECT SUM(f.NettoBelop) FROM dw.FaktLab f JOIN dw.DimDato d ON d.DatoKey = f.OrdreDatoKey
WHERE d.AarMaaned = '2025-03';
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- F2  Implisitt konvertering: varchar-kolonne mot nvarchar-verdi
------------------------------------------------------------------------
CREATE INDEX IX_DimKunde_Postnummer ON dw.DimKunde (Postnummer) INCLUDE (KundeId, Navn, ErGjeldende);   -- dekker spørringen, så bare konverteringen skiller a og b
GO
PRINT '=== F2a WHERE Postnummer = N''0150'' (NVARCHAR mot CHAR-kolonne) → CONVERT_IMPLICIT på kolonnen → scan + varsel i planen ===';
SET STATISTICS IO ON;
SELECT KundeId, Navn FROM dw.DimKunde WHERE Postnummer = N'0150' AND ErGjeldende = 1;
SET STATISTICS IO OFF;
PRINT '=== F2b WHERE Postnummer = ''0150'' → seek ===';
SET STATISTICS IO ON;
SELECT KundeId, Navn FROM dw.DimKunde WHERE Postnummer = '0150' AND ErGjeldende = 1;
SET STATISTICS IO OFF;
PRINT '=== F2c Samme problem i en join: NordhandelShop.Kunde.Postnummer (NVARCHAR) mot Postnummer-register (CHAR) ===';
SET STATISTICS IO ON;
SELECT COUNT(*) FROM NordhandelShop.dbo.Kunde k JOIN NordhandelShop.dbo.Postnummer p ON p.Postnummer = k.Postnummer;
SET STATISTICS IO OFF;
DROP INDEX IX_DimKunde_Postnummer ON dw.DimKunde;
GO

------------------------------------------------------------------------
-- F3  SELECT * ødelegger covering
------------------------------------------------------------------------
CREATE INDEX IX_FaktLab_Kunde ON dw.FaktLab (KundeKey) INCLUDE (OrdreDatoKey, NettoBelop);
GO
PRINT '=== F3a Bare kolonnene vi trenger → covering seek ===';
SET STATISTICS IO ON;
SELECT OrdreDatoKey, NettoBelop FROM dw.FaktLab WHERE KundeKey = 2777;
SET STATISTICS IO OFF;
PRINT '=== F3b SELECT * → 1 134 key lookups (eller scan) ===';
SET STATISTICS IO ON;
SELECT * FROM dw.FaktLab WHERE KundeKey = 2777;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- F4  «Catch-all»-spørringen: (@p IS NULL OR kolonne = @p)
--     Én plan skal passe alle kombinasjoner av parametere → scan.
--     (Merk: vanlig OR mellom to INDEKSERTE kolonner løser optimalisereren selv med index union.)
------------------------------------------------------------------------
CREATE INDEX IX_FaktLab_Produkt ON dw.FaktLab (ProduktKey) INCLUDE (NettoBelop);   -- IX_FaktLab_Kunde finnes fra F3
GO
DECLARE @Kunde INT = 2777, @Produkt INT = NULL;
PRINT '=== F4a (@Kunde IS NULL OR KundeKey = @Kunde) AND (@Produkt IS NULL OR ProduktKey = @Produkt) → scan, selv om @Kunde er satt ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab
WHERE (@Kunde IS NULL OR KundeKey = @Kunde) AND (@Produkt IS NULL OR ProduktKey = @Produkt);
SET STATISTICS IO OFF;
PRINT '=== F4b OPTION (RECOMPILE): planen lages for DISSE verdiene; IS NULL-grenene forsvinner → seek ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab
WHERE (@Kunde IS NULL OR KundeKey = @Kunde) AND (@Produkt IS NULL OR ProduktKey = @Produkt)
OPTION (RECOMPILE);
SET STATISTICS IO OFF;
GO
------------------------------------------------------------------------
-- F5  Tabellvariabel vs. temp-tabell
--     Før SQL Server 2019: tabellvariabel estimeres til 1 rad uansett innhold.
--     2019+ (kompat. 150): «deferred compilation» gir riktig antall. Vi viser begge.
------------------------------------------------------------------------
CREATE INDEX IX_FaktLab_OrdreId ON dw.FaktLab (OrdreId) INCLUDE (NettoBelop);
GO
DECLARE @Nokler TABLE (OrdreId INT PRIMARY KEY);
INSERT INTO @Nokler SELECT DISTINCT TOP (50000) OrdreId FROM dw.FaktLab ORDER BY OrdreId;

PRINT '=== F5a Tabellvariabel, gammel oppførsel: estimat 1 rad → Nested Loops → 50 000 seeks ===';
SET STATISTICS IO ON;
SELECT COUNT(*), SUM(f.NettoBelop) FROM dw.FaktLab f JOIN @Nokler n ON n.OrdreId = f.OrdreId
OPTION (USE HINT('DISABLE_DEFERRED_COMPILATION_TV'));
SET STATISTICS IO OFF;

PRINT '=== F5b Tabellvariabel, 2019+: riktig estimat → Merge/Hash Join → én gjennomlesning ===';
SET STATISTICS IO ON;
SELECT COUNT(*), SUM(f.NettoBelop) FROM dw.FaktLab f JOIN @Nokler n ON n.OrdreId = f.OrdreId;
SET STATISTICS IO OFF;
GO
PRINT '=== F5c Temp-tabell: har statistikk, har alltid virket, og kan indekseres fritt ===';
DROP TABLE IF EXISTS #Nokler;
CREATE TABLE #Nokler (OrdreId INT PRIMARY KEY);
INSERT INTO #Nokler SELECT DISTINCT TOP (50000) OrdreId FROM dw.FaktLab ORDER BY OrdreId;
SET STATISTICS IO ON;
SELECT COUNT(*), SUM(f.NettoBelop) FROM dw.FaktLab f JOIN #Nokler n ON n.OrdreId = f.OrdreId;
SET STATISTICS IO OFF;
DROP TABLE #Nokler;
DROP INDEX IX_FaktLab_OrdreId ON dw.FaktLab;
GO
------------------------------------------------------------------------
-- F6  Parameter sniffing
--     På en tabell clustered på SalgKey med NC på dato (ikke covering) – slik FaktSalg
--     faktisk er i 02-dw-skjema.sql – blir «én dag»-planen seek + lookup.
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktSniff;
SELECT * INTO dw.FaktSniff FROM dw.FaktLab;
CREATE CLUSTERED INDEX CX ON dw.FaktSniff (SalgKey);
CREATE INDEX IX_Dato ON dw.FaktSniff (OrdreDatoKey);
GO
CREATE OR ALTER PROCEDURE dw.OmsetningPeriode @Fra INT, @Til INT AS
    SELECT p.Hovedkategori, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSniff f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
    WHERE f.OrdreDatoKey BETWEEN @Fra AND @Til
    GROUP BY p.Hovedkategori;
GO
CREATE OR ALTER PROCEDURE dw.OmsetningPeriode_Recompile @Fra INT, @Til INT AS
    SELECT p.Hovedkategori, SUM(f.NettoBelop) AS Omsetning
    FROM dw.FaktSniff f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
    WHERE f.OrdreDatoKey BETWEEN @Fra AND @Til
    GROUP BY p.Hovedkategori
    OPTION (RECOMPILE);
GO
PRINT '=== F6a Første kall: ÉN DAG. Planen kompileres for ~400 rader → Index Seek + Key Lookup ===';
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
SET STATISTICS IO ON;
EXEC dw.OmsetningPeriode 20250312, 20250312;
SET STATISTICS IO OFF;
PRINT '=== F6b Andre kall: HELE ÅRET med den gjenbrukte «én dag»-planen → 194 000 lookups ===';
SET STATISTICS IO ON;
EXEC dw.OmsetningPeriode 20250101, 20251231;
SET STATISTICS IO OFF;
PRINT '=== F6c Tøm cache, kall med HELE ÅRET først → scan-plan ===';
DBCC FREEPROCCACHE WITH NO_INFOMSGS;
SET STATISTICS IO ON;
EXEC dw.OmsetningPeriode 20250101, 20251231;
SET STATISTICS IO OFF;
PRINT '=== F6d …og ÉN DAG med års-planen → scan for 400 rader (motsatt problem, mindre dramatisk) ===';
SET STATISTICS IO ON;
EXEC dw.OmsetningPeriode 20250312, 20250312;
SET STATISTICS IO OFF;
PRINT '=== F6e OPTION (RECOMPILE): riktig plan hver gang, mot en kompileringskostnad per kall ===';
SET STATISTICS IO ON;
EXEC dw.OmsetningPeriode_Recompile 20250312, 20250312;
EXEC dw.OmsetningPeriode_Recompile 20250101, 20251231;
SET STATISTICS IO OFF;
GO
DROP PROCEDURE dw.OmsetningPeriode, dw.OmsetningPeriode_Recompile;
DROP TABLE dw.FaktSniff;
GO
------------------------------------------------------------------------
-- F7  Manglende indeks på fremmednøkkel i faktatabellen
------------------------------------------------------------------------
DROP INDEX IX_FaktLab_Produkt ON dw.FaktLab;
GO
PRINT '=== F7a Join til DimProdukt filtrert på ett varenummer, uten indeks på FaktLab.ProduktKey → scan av fakta ===';
SET STATISTICS IO ON;
SELECT SUM(f.NettoBelop) FROM dw.FaktLab f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey WHERE p.Varenummer = 'NH-00005';
SET STATISTICS IO OFF;
CREATE INDEX IX_FaktLab_Produkt ON dw.FaktLab (ProduktKey) INCLUDE (NettoBelop);
GO
PRINT '=== F7b Med indeks → seek på dimensjonen, seek på fakta ===';
SET STATISTICS IO ON;
SELECT SUM(f.NettoBelop) FROM dw.FaktLab f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey WHERE p.Varenummer = 'NH-00005';
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- P  Partisjonering på år
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktPart, dw.FaktPart_2026;
IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'PS_Aar') DROP PARTITION SCHEME PS_Aar;
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'PF_Aar') DROP PARTITION FUNCTION PF_Aar;
GO
-- RANGE RIGHT: grensen hører til partisjonen til høyre → 20250101 er første dag i partisjon «2025»
CREATE PARTITION FUNCTION PF_Aar (INT) AS RANGE RIGHT FOR VALUES (20240101, 20250101, 20260101, 20270101);
CREATE PARTITION SCHEME PS_Aar AS PARTITION PF_Aar ALL TO ([PRIMARY]);   -- i produksjon: én filgruppe per partisjon
GO
CREATE TABLE dw.FaktPart (
    SalgKey BIGINT NOT NULL, OrdreDatoKey INT NOT NULL, KundeKey INT NOT NULL, ProduktKey INT NOT NULL, OrdreinfoKey INT NOT NULL,
    OrdreId INT NOT NULL, OrdrelinjeId INT NOT NULL, Antall INT NOT NULL, BruttoBelop DECIMAL(12,2) NOT NULL,
    RabattBelop DECIMAL(12,2) NOT NULL, NettoBelop DECIMAL(12,2) NOT NULL, Kostnad DECIMAL(12,2) NOT NULL,
    FraktAllokert DECIMAL(12,2) NOT NULL, Enhetspris DECIMAL(10,2) NOT NULL, RabattProsent DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_FaktPart PRIMARY KEY CLUSTERED (OrdreDatoKey, SalgKey) ON PS_Aar (OrdreDatoKey)
);
INSERT INTO dw.FaktPart SELECT * FROM dw.FaktLab WHERE OrdreDatoKey < 20260101;    -- 2023–2025; 2026 kommer via SWITCH
GO
PRINT '=== P1 Rader per partisjon ===';
SELECT $PARTITION.PF_Aar(OrdreDatoKey) AS Partisjon, MIN(OrdreDatoKey) AS Fra, MAX(OrdreDatoKey) AS Til, COUNT(*) AS Rader
FROM dw.FaktPart GROUP BY $PARTITION.PF_Aar(OrdreDatoKey) ORDER BY 1;
GO
PRINT '=== P2 Partition elimination: filter på partisjonskolonnen → bare 2025-partisjonen leses (se Actual Partition Count i planen) ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktPart WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231;
SET STATISTICS IO OFF;
PRINT '=== P3 Prisen: filter som IKKE bruker partisjonskolonnen → alle partisjoner skannes (Scan count = antall partisjoner) ===';
SET STATISTICS IO ON;
SELECT * FROM dw.FaktPart WHERE SalgKey = 123456;
SET STATISTICS IO OFF;
PRINT '=== P3b Sammenlign: samme oppslag på upartisjonert FaktLab (clustered på dato) ===';
SET STATISTICS IO ON;
SELECT * FROM dw.FaktLab WHERE SalgKey = 123456;
SET STATISTICS IO OFF;
GO
PRINT '=== P4 SWITCH IN: last 2026 i en egen tabell, så bytt den inn som partisjon – metadataoperasjon, uansett størrelse ===';
CREATE TABLE dw.FaktPart_2026 (
    SalgKey BIGINT NOT NULL, OrdreDatoKey INT NOT NULL, KundeKey INT NOT NULL, ProduktKey INT NOT NULL, OrdreinfoKey INT NOT NULL,
    OrdreId INT NOT NULL, OrdrelinjeId INT NOT NULL, Antall INT NOT NULL, BruttoBelop DECIMAL(12,2) NOT NULL,
    RabattBelop DECIMAL(12,2) NOT NULL, NettoBelop DECIMAL(12,2) NOT NULL, Kostnad DECIMAL(12,2) NOT NULL,
    FraktAllokert DECIMAL(12,2) NOT NULL, Enhetspris DECIMAL(10,2) NOT NULL, RabattProsent DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_FaktPart_2026 PRIMARY KEY CLUSTERED (OrdreDatoKey, SalgKey) ON [PRIMARY],
    CONSTRAINT CK_FaktPart_2026 CHECK (OrdreDatoKey >= 20260101 AND OrdreDatoKey < 20270101)   -- beviser for motoren at radene hører hjemme
);
INSERT INTO dw.FaktPart_2026 SELECT * FROM dw.FaktLab WHERE OrdreDatoKey >= 20260101;
DECLARE @P INT = $PARTITION.PF_Aar(20260101);
DECLARE @T0 DATETIME2 = SYSDATETIME();
ALTER TABLE dw.FaktPart_2026 SWITCH TO dw.FaktPart PARTITION @P;
SELECT SwitchMs = DATEDIFF(millisecond, @T0, SYSDATETIME()), RaderI2026Partisjon = (SELECT COUNT(*) FROM dw.FaktPart WHERE $PARTITION.PF_Aar(OrdreDatoKey) = @P),
       RaderIgjenIStaging = (SELECT COUNT(*) FROM dw.FaktPart_2026);
GO
PRINT '=== P5 SWITCH OUT: arkiver 2023 på samme måte (tom tabell ← partisjon) ===';
DROP TABLE IF EXISTS dw.FaktPart_Arkiv2023;
CREATE TABLE dw.FaktPart_Arkiv2023 (
    SalgKey BIGINT NOT NULL, OrdreDatoKey INT NOT NULL, KundeKey INT NOT NULL, ProduktKey INT NOT NULL, OrdreinfoKey INT NOT NULL,
    OrdreId INT NOT NULL, OrdrelinjeId INT NOT NULL, Antall INT NOT NULL, BruttoBelop DECIMAL(12,2) NOT NULL,
    RabattBelop DECIMAL(12,2) NOT NULL, NettoBelop DECIMAL(12,2) NOT NULL, Kostnad DECIMAL(12,2) NOT NULL,
    FraktAllokert DECIMAL(12,2) NOT NULL, Enhetspris DECIMAL(10,2) NOT NULL, RabattProsent DECIMAL(5,2) NOT NULL,
    CONSTRAINT PK_FaktPart_Arkiv2023 PRIMARY KEY CLUSTERED (OrdreDatoKey, SalgKey) ON [PRIMARY]
);
ALTER TABLE dw.FaktPart SWITCH PARTITION $PARTITION.PF_Aar(20230101) TO dw.FaktPart_Arkiv2023;
SELECT Arkivert2023 = (SELECT COUNT(*) FROM dw.FaktPart_Arkiv2023), IgjenIFaktPart = (SELECT COUNT(*) FROM dw.FaktPart);
GO
-- Rydd
DROP TABLE IF EXISTS dw.FaktPart_2026, dw.FaktPart_Arkiv2023, dw.FaktPart;
DROP PARTITION SCHEME PS_Aar; DROP PARTITION FUNCTION PF_Aar;
DROP INDEX IF EXISTS IX_FaktLab_Kunde ON dw.FaktLab;
DROP INDEX IF EXISTS IX_FaktLab_Produkt ON dw.FaktLab;
PRINT 'Ferdig.';

