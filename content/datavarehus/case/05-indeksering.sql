/* =====================================================================
   Nordhandel AS – indeksering: målte eksperimenter
   Fil: case/05-indeksering.sql
   Forutsetter fylt NordhandelDW. Jobber på en KOPI (dw.FaktLab) så ETL
   og rapporter ikke påvirkes. Kjør i SSMS med Ctrl+M (actual plan) på.

   Hvert eksperiment: PRINT-merke → SET STATISTICS IO → spørring.
   Les «logical reads» i Messages-fanen. 1 logisk lesning = én 8 KB-side.

   Eksperimenter
     E0  Heap: table scan
     E1  Clustered index på SalgKey: scan, like mange lesninger
     E2  Nonclustered på OrdreDatoKey: seek + key lookup (én dag) vs scan (én måned) – tipping point
     E3  Covering index (INCLUDE): seek uten lookup, også for en måned
     E4  Clustered på OrdreDatoKey: range scan på sammenhengende sider
     E5  Komposittindeks: kolonnerekkefølge avgjør om den kan brukes
     E6  Columnstore: analytisk spørring vs punktoppslag
     E7  Kostnad: INSERT 100 000 rader med 0, 3 og 6 indekser; plassbruk
   ===================================================================== */
USE NordhandelDW;
GO
SET NOCOUNT ON;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- Oppsett: kopi av FaktSalg som HEAP (SELECT INTO lager ingen indekser)
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktLab;
SELECT ISNULL(SalgKey, 0) AS SalgKey,   -- ISNULL fjerner IDENTITY-egenskapen i SELECT INTO
       OrdreDatoKey, KundeKey, ProduktKey, OrdreinfoKey, OrdreId, OrdrelinjeId,
       Antall, BruttoBelop, RabattBelop, NettoBelop, Kostnad, FraktAllokert, Enhetspris, RabattProsent
INTO dw.FaktLab
FROM dw.FaktSalg;

-- Testverdier: en dag, en måned, en aktiv kunde
DECLARE @Dag INT = 20250312, @MndFra INT = 20250301, @MndTil INT = 20250331;
DECLARE @Kunde INT = (SELECT TOP 1 KundeKey FROM dw.FaktLab GROUP BY KundeKey ORDER BY COUNT(*) DESC);
SELECT 'Rader' AS Hva, COUNT(*) AS Verdi FROM dw.FaktLab
UNION ALL SELECT 'Rader på dagen',    COUNT(*) FROM dw.FaktLab WHERE OrdreDatoKey = @Dag
UNION ALL SELECT 'Rader i måneden',   COUNT(*) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN @MndFra AND @MndTil
UNION ALL SELECT 'Rader for kunden',  COUNT(*) FROM dw.FaktLab WHERE KundeKey = @Kunde
UNION ALL SELECT 'KundeKey brukt',    @Kunde;
EXEC sp_spaceused 'dw.FaktLab';
GO

------------------------------------------------------------------------
-- E0  Heap
------------------------------------------------------------------------
PRINT '=== E0 Heap: SUM for én måned ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E1  Clustered index på surrogatnøkkelen (slik 02-dw-skjema.sql gjør det)
------------------------------------------------------------------------
CREATE UNIQUE CLUSTERED INDEX CX_FaktLab_SalgKey ON dw.FaktLab (SalgKey);
PRINT '=== E1 Clustered på SalgKey: SUM for én måned (fortsatt scan) ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E2  Nonclustered på OrdreDatoKey – bare nøkkelen
------------------------------------------------------------------------
CREATE INDEX IX_FaktLab_Dato ON dw.FaktLab (OrdreDatoKey);
GO   -- indekshint lenger ned kompileres før batchen kjører; indeksen må finnes først

PRINT '=== E2a NC på dato: én DAG → Index Seek + Key Lookup ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey = 20250312;
SET STATISTICS IO OFF;

PRINT '=== E2b NC på dato: én MÅNED → optimalisereren velger Clustered Index Scan (tipping point) ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;

PRINT '=== E2c Tving seek + lookup for måneden – se hvorfor optimalisereren sa nei ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WITH (INDEX (IX_FaktLab_Dato)) WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E3  Covering index: INCLUDE kolonnen spørringen trenger
------------------------------------------------------------------------
DROP INDEX IX_FaktLab_Dato ON dw.FaktLab;
CREATE INDEX IX_FaktLab_Dato_Cover ON dw.FaktLab (OrdreDatoKey) INCLUDE (NettoBelop);

PRINT '=== E3a Covering: én måned → Index Seek, ingen lookup ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;

PRINT '=== E3b Men: be om en kolonne som IKKE er inkludert → lookup eller scan igjen ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop), SUM(Kostnad) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;

PRINT '=== E3c Hele året – covering index scan er fortsatt billigere enn tabellscan (smalere) ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250101 AND 20251231;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E4  Clustered på OrdreDatoKey i stedet: tabellen er fysisk sortert på dato
------------------------------------------------------------------------
DROP INDEX IX_FaktLab_Dato_Cover ON dw.FaktLab;
DROP INDEX CX_FaktLab_SalgKey ON dw.FaktLab;
CREATE CLUSTERED INDEX CX_FaktLab_Dato ON dw.FaktLab (OrdreDatoKey, SalgKey);   -- SalgKey gjør nøkkelen unik

PRINT '=== E4a Clustered på dato: én måned, ALLE kolonner tilgjengelig ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop), SUM(Kostnad), SUM(Antall) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;

PRINT '=== E4b Prisen: oppslag på SalgKey er nå et scan ===';
SET STATISTICS IO ON;
SELECT * FROM dw.FaktLab WHERE SalgKey = 123456;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E5  Komposittindeks: rekkefølgen
------------------------------------------------------------------------
CREATE INDEX IX_FaktLab_KundeDato ON dw.FaktLab (KundeKey, OrdreDatoKey) INCLUDE (NettoBelop);
GO
DECLARE @Kunde INT = (SELECT TOP 1 KundeKey FROM dw.FaktLab GROUP BY KundeKey ORDER BY COUNT(*) DESC);
DECLARE @Sql NVARCHAR(MAX);

PRINT '=== E5a (Kunde, Dato): WHERE Kunde = X AND Dato i måned → seek på begge ===';
SET @Sql = N'SET STATISTICS IO ON; SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE KundeKey = ' + CAST(@Kunde AS NVARCHAR(10))
         + N' AND OrdreDatoKey BETWEEN 20250101 AND 20251231; SET STATISTICS IO OFF;';
EXEC (@Sql);

PRINT '=== E5b (Kunde, Dato): WHERE Kunde = X alene → seek (ledende kolonne) ===';
SET @Sql = N'SET STATISTICS IO ON; SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE KundeKey = ' + CAST(@Kunde AS NVARCHAR(10))
         + N'; SET STATISTICS IO OFF;';
EXEC (@Sql);

PRINT '=== E5c (Kunde, Dato): WHERE Dato alene → kan IKKE seeke; blir scan av indeks eller tabell ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WITH (INDEX (IX_FaktLab_KundeDato)) WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;

DROP INDEX IX_FaktLab_KundeDato ON dw.FaktLab;
CREATE INDEX IX_FaktLab_DatoKunde ON dw.FaktLab (OrdreDatoKey, KundeKey) INCLUDE (NettoBelop);
GO
DECLARE @Kunde INT = (SELECT TOP 1 KundeKey FROM dw.FaktLab GROUP BY KundeKey ORDER BY COUNT(*) DESC);
DECLARE @Sql NVARCHAR(MAX);

PRINT '=== E5d (Dato, Kunde): WHERE Kunde = X AND Dato i år → seek på dato, filter på kunde (leser hele året) ===';
SET @Sql = N'SET STATISTICS IO ON; SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE KundeKey = ' + CAST(@Kunde AS NVARCHAR(10))
         + N' AND OrdreDatoKey BETWEEN 20250101 AND 20251231; SET STATISTICS IO OFF;';
EXEC (@Sql);

PRINT '=== E5e (Dato, Kunde): WHERE Dato alene → seek ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLab WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
DROP INDEX IX_FaktLab_DatoKunde ON dw.FaktLab;
GO

------------------------------------------------------------------------
-- E6  Columnstore
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktLabCS;
SELECT * INTO dw.FaktLabCS FROM dw.FaktLab;
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FaktLabCS ON dw.FaktLabCS;

PRINT '=== E6a Plass: rowstore vs columnstore ===';
EXEC sp_spaceused 'dw.FaktLab';
EXEC sp_spaceused 'dw.FaktLabCS';

PRINT '=== E6b Rapport 1-lignende aggregering: rowstore (clustered på dato) ===';
SET STATISTICS IO ON;
SELECT f.OrdreDatoKey / 100 AS AarMaaned, p.Hovedkategori, SUM(f.NettoBelop) AS Omsetning, SUM(f.NettoBelop - f.Kostnad) AS DB
FROM dw.FaktLab f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
GROUP BY f.OrdreDatoKey / 100, p.Hovedkategori;
SET STATISTICS IO OFF;

PRINT '=== E6c Samme på columnstore ===';
SET STATISTICS IO ON;
SELECT f.OrdreDatoKey / 100 AS AarMaaned, p.Hovedkategori, SUM(f.NettoBelop) AS Omsetning, SUM(f.NettoBelop - f.Kostnad) AS DB
FROM dw.FaktLabCS f JOIN dw.DimProdukt p ON p.ProduktKey = f.ProduktKey
GROUP BY f.OrdreDatoKey / 100, p.Hovedkategori;
SET STATISTICS IO OFF;

PRINT '=== E6d Punktoppslag: columnstore er dårlig til dette ===';
SET STATISTICS IO ON;
SELECT * FROM dw.FaktLabCS WHERE OrdrelinjeId = 250000;
SET STATISTICS IO OFF;

PRINT '=== E6e Columnstore + dato-filter: leser bare to kolonner. (Segment elimination krever >1 rowgroup = >1 048 576 rader – vi har ett) ===';
SET STATISTICS IO ON;
SELECT SUM(NettoBelop) FROM dw.FaktLabCS WHERE OrdreDatoKey BETWEEN 20250301 AND 20250331;
SET STATISTICS IO OFF;
GO

------------------------------------------------------------------------
-- E7  Kostnaden ved indekser: lasting av 100 000 rader
------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.FaktLabLast;
SELECT TOP (0) * INTO dw.FaktLabLast FROM dw.FaktLab;      -- tom heap med samme struktur
CREATE UNIQUE CLUSTERED INDEX CX ON dw.FaktLabLast (SalgKey);

DROP TABLE IF EXISTS #Kilde;
SELECT TOP (100000) * INTO #Kilde FROM dw.FaktLab ORDER BY NEWID();   -- tilfeldig rekkefølge, som i en ekte lasting

DECLARE @T0 DATETIME2, @Ms0 INT, @Ms3 INT, @Ms6 INT;

-- 0 nonclustered
SET @T0 = SYSDATETIME();
INSERT INTO dw.FaktLabLast SELECT * FROM #Kilde;
SET @Ms0 = DATEDIFF(millisecond, @T0, SYSDATETIME());
TRUNCATE TABLE dw.FaktLabLast;

-- 3 nonclustered (FK-indeksene)
CREATE INDEX IX1 ON dw.FaktLabLast (OrdreDatoKey);
CREATE INDEX IX2 ON dw.FaktLabLast (KundeKey);
CREATE INDEX IX3 ON dw.FaktLabLast (ProduktKey);
SET @T0 = SYSDATETIME();
INSERT INTO dw.FaktLabLast SELECT * FROM #Kilde;
SET @Ms3 = DATEDIFF(millisecond, @T0, SYSDATETIME());
TRUNCATE TABLE dw.FaktLabLast;

-- 6 nonclustered (+ tre covering)
CREATE INDEX IX4 ON dw.FaktLabLast (OrdreinfoKey) INCLUDE (NettoBelop, Kostnad);
CREATE INDEX IX5 ON dw.FaktLabLast (OrdreId) INCLUDE (NettoBelop, FraktAllokert);
CREATE INDEX IX6 ON dw.FaktLabLast (KundeKey, OrdreDatoKey) INCLUDE (NettoBelop, Antall);
SET @T0 = SYSDATETIME();
INSERT INTO dw.FaktLabLast SELECT * FROM #Kilde;
SET @Ms6 = DATEDIFF(millisecond, @T0, SYSDATETIME());

PRINT '=== E7 Lastetid 100 000 rader ===';
SELECT Indekser = 0, Ms = @Ms0 UNION ALL SELECT 3, @Ms3 UNION ALL SELECT 6, @Ms6;
EXEC sp_spaceused 'dw.FaktLabLast';

-- Plass per indeks
SELECT i.name, i.type_desc, Sider = SUM(ps.used_page_count), MB = CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(8,1))
FROM sys.indexes i
JOIN sys.dm_db_partition_stats ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.object_id = OBJECT_ID('dw.FaktLabLast')
GROUP BY i.name, i.type_desc ORDER BY i.type_desc DESC, i.name;
GO

------------------------------------------------------------------------
-- Bonus: hva mener optimalisereren mangler? (DMV-ene nullstilles ved restart)
------------------------------------------------------------------------
PRINT '=== Missing index-forslag for FaktLab-tabellene ===';
SELECT TOP (10)
       OBJECT_NAME(d.object_id) AS Tabell, d.equality_columns, d.inequality_columns, d.included_columns,
       s.user_seeks, s.avg_user_impact
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g ON g.index_handle = d.index_handle
JOIN sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
WHERE d.database_id = DB_ID() AND OBJECT_NAME(d.object_id) LIKE 'FaktLab%'
ORDER BY s.avg_user_impact * s.user_seeks DESC;
GO

-- Rydd (behold FaktLab og FaktLabCS til samling 6)
DROP TABLE IF EXISTS dw.FaktLabLast;
PRINT 'Ferdig. dw.FaktLab (clustered på dato) og dw.FaktLabCS (columnstore) beholdes til samling 6.';


