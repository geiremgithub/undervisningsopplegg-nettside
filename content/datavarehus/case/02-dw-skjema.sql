/* =====================================================================
   Nordhandel AS – datavarehus (stjerneskjema)
   Fil: case/02-dw-skjema.sql
   Fasit for mappeinnlevering 1. Kjøres etter samling 2.

   Innhold
     1. Database og schemaer (dw, stg, etl)
     2. dw.DimDato        – generert 2022–2032 med norske helligdager
     3. dw.DimKunde       – SCD type 2 på adresse, type 1 på navn,
                            type 0 på opprinnelig segment
     4. dw.DimProdukt     – SCD type 2 på pris og kategori, type 1 på navn/merke
     5. dw.DimOrdreinfo   – junk dimension (status × betalingsmåte × kanal)
     6. dw.FaktSalg       – korn: én rad per ordrelinje
     7. Ukjent-rader (nøkkel -1) i alle dimensjoner
   ===================================================================== */

IF DB_ID('NordhandelDW') IS NULL
    CREATE DATABASE NordhandelDW;
GO
USE NordhandelDW;
GO
SET QUOTED_IDENTIFIER ON;   -- kreves for filtrerte indekser og beregnede kolonner (SSMS setter dette; sqlcmd gjør det ikke)
SET ANSI_NULLS ON;
GO

------------------------------------------------------------------------
-- 1. Schemaer: ett per lag, så rettigheter og opprydding blir enkelt
------------------------------------------------------------------------
IF SCHEMA_ID('dw')  IS NULL EXEC('CREATE SCHEMA dw');    -- stjerneskjemaet
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');   -- staging (samling 3)
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');   -- logg, karantene, prosedyrer (samling 3)
GO

-- Rydd ved rekjøring: fakta før dimensjoner pga. fremmednøkler
DROP TABLE IF EXISTS dw.FaktSalg;
DROP TABLE IF EXISTS dw.DimKunde;
DROP TABLE IF EXISTS dw.DimProdukt;
DROP TABLE IF EXISTS dw.DimOrdreinfo;
DROP TABLE IF EXISTS dw.DimDato;
DROP FUNCTION IF EXISTS dw.fnPaaskedag;
GO

------------------------------------------------------------------------
-- 2. DimDato
------------------------------------------------------------------------
CREATE TABLE dw.DimDato (
    DatoKey        INT          NOT NULL PRIMARY KEY,   -- yyyymmdd, lesbar og sorterbar
    Dato           DATE         NOT NULL UNIQUE,
    Aar            SMALLINT     NOT NULL,
    Kvartal        TINYINT      NOT NULL,
    KvartalNavn    CHAR(7)      NOT NULL,               -- '2025-Q1'
    Maaned         TINYINT      NOT NULL,
    MaanedNavn     NVARCHAR(10) NOT NULL,
    AarMaaned      CHAR(7)      NOT NULL,               -- '2025-03' – praktisk å sortere/gruppere på
    DagIMaaned     TINYINT      NOT NULL,
    IsoUke         TINYINT      NOT NULL,
    IsoAar         SMALLINT     NOT NULL,               -- uke 1 kan tilhøre forrige/neste år!
    IsoAarUke      CHAR(8)      NOT NULL,               -- '2025-W09'
    Ukedag         TINYINT      NOT NULL,               -- 1 = mandag … 7 = søndag (uavhengig av DATEFIRST)
    UkedagNavn     NVARCHAR(10) NOT NULL,
    ErHelg         BIT          NOT NULL,
    ErHelligdag    BIT          NOT NULL,
    HelligdagNavn  NVARCHAR(60) NULL,
    ErArbeidsdag   AS CAST(CASE WHEN ErHelg = 0 AND ErHelligdag = 0 THEN 1 ELSE 0 END AS BIT)
);
GO

-- Påskedag etter Meeus/Jones/Butcher (gregoriansk kalender)
CREATE FUNCTION dw.fnPaaskedag (@Aar INT)
RETURNS TABLE
AS RETURN
(
    WITH v AS (
        SELECT a = @Aar % 19, b = @Aar / 100, c = @Aar % 100
    ), w AS (
        SELECT a, b, c, d = b / 4, e = b % 4, f = (b + 8) / 25 FROM v
    ), x AS (
        SELECT a, b, c, d, e, g = (b - f + 1) / 3 FROM w
    ), y AS (
        SELECT a, c, h = (19 * a + b - d - g + 15) % 30, i = c / 4, k = c % 4, e FROM x
    ), z AS (
        SELECT h, l = (32 + 2 * e + 2 * i - h - k) % 7, a FROM y
    ), m AS (
        SELECT h, l, m = (a + 11 * h + 22 * l) / 451 FROM z
    )
    SELECT Paaskedag = DATEFROMPARTS(@Aar, (h + l - 7 * m + 114) / 31, (h + l - 7 * m + 114) % 31 + 1)
    FROM m
);
GO

SET LANGUAGE Norwegian;   -- gir norske måneds- og dagnavn fra DATENAME
SET DATEFORMAT ymd;       -- NB! SET LANGUAGE endrer også datoformat til dmy, så 'yyyy-mm-dd' tolkes som år-DAG-måned for datetime

;WITH L0 AS (SELECT 1 AS c FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(c)),
      L1 AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),          -- 100
      L2 AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),          -- 10 000
      Dager AS (
          SELECT DATEADD(day, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, '2022-01-01') AS Dato
          FROM L2
      ),
      Grunnlag AS (
          SELECT Dato
          FROM Dager
          WHERE Dato <= '2032-12-31'
      ),
      HelligdagerRaa AS (
          -- Faste
          SELECT d.Dato, N'1. nyttårsdag' AS Navn FROM Grunnlag d WHERE MONTH(d.Dato) = 1  AND DAY(d.Dato) = 1
          UNION ALL SELECT d.Dato, N'1. mai'      FROM Grunnlag d WHERE MONTH(d.Dato) = 5  AND DAY(d.Dato) = 1
          UNION ALL SELECT d.Dato, N'17. mai'     FROM Grunnlag d WHERE MONTH(d.Dato) = 5  AND DAY(d.Dato) = 17
          UNION ALL SELECT d.Dato, N'1. juledag'  FROM Grunnlag d WHERE MONTH(d.Dato) = 12 AND DAY(d.Dato) = 25
          UNION ALL SELECT d.Dato, N'2. juledag'  FROM Grunnlag d WHERE MONTH(d.Dato) = 12 AND DAY(d.Dato) = 26
          -- Bevegelige (relativt til påskedag)
          UNION ALL
          SELECT DATEADD(day, o.Offset, p.Paaskedag), o.Navn
          FROM (SELECT DISTINCT YEAR(Dato) AS Aar FROM Grunnlag) aar
          CROSS APPLY dw.fnPaaskedag(aar.Aar) p
          CROSS JOIN (VALUES (-3, N'Skjærtorsdag'), (-2, N'Langfredag'), (0, N'1. påskedag'), (1, N'2. påskedag'),
                             (39, N'Kristi himmelfartsdag'), (49, N'1. pinsedag'), (50, N'2. pinsedag')) o(Offset, Navn)
      ),
      Helligdager AS (
          -- Samme dato kan være to helligdager (17. mai 2027 er også 2. pinsedag) → én rad per dato
          SELECT Dato, STRING_AGG(Navn, N' / ') WITHIN GROUP (ORDER BY Navn) AS Navn
          FROM HelligdagerRaa
          GROUP BY Dato
      )
INSERT INTO dw.DimDato (DatoKey, Dato, Aar, Kvartal, KvartalNavn, Maaned, MaanedNavn, AarMaaned, DagIMaaned,
                        IsoUke, IsoAar, IsoAarUke, Ukedag, UkedagNavn, ErHelg, ErHelligdag, HelligdagNavn)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), g.Dato, 112)),
    g.Dato,
    YEAR(g.Dato),
    DATEPART(quarter, g.Dato),
    CONCAT(YEAR(g.Dato), '-Q', DATEPART(quarter, g.Dato)),
    MONTH(g.Dato),
    DATENAME(month, g.Dato),
    CONVERT(CHAR(7), g.Dato, 126),                                      -- 'yyyy-MM'
    DAY(g.Dato),
    DATEPART(iso_week, g.Dato),
    YEAR(DATEADD(day, 26 - DATEPART(iso_week, g.Dato), g.Dato)),        -- ISO-år: året torsdagen i uka tilhører
    CONCAT(YEAR(DATEADD(day, 26 - DATEPART(iso_week, g.Dato), g.Dato)), '-W',
           RIGHT('0' + CAST(DATEPART(iso_week, g.Dato) AS VARCHAR(2)), 2)),
    (DATEPART(weekday, g.Dato) + @@DATEFIRST - 2) % 7 + 1,              -- 1 = mandag uansett serverinnstilling
    DATENAME(weekday, g.Dato),
    CASE WHEN (DATEPART(weekday, g.Dato) + @@DATEFIRST - 2) % 7 + 1 >= 6 THEN 1 ELSE 0 END,
    CASE WHEN h.Dato IS NOT NULL THEN 1 ELSE 0 END,
    h.Navn
FROM Grunnlag g
LEFT JOIN Helligdager h ON h.Dato = g.Dato;

-- Ukjent dato (for fakta uten gyldig dato – skal normalt ikke forekomme, men finnes alltid)
INSERT INTO dw.DimDato (DatoKey, Dato, Aar, Kvartal, KvartalNavn, Maaned, MaanedNavn, AarMaaned, DagIMaaned,
                        IsoUke, IsoAar, IsoAarUke, Ukedag, UkedagNavn, ErHelg, ErHelligdag, HelligdagNavn)
VALUES (19000101, '1900-01-01', 1900, 1, '1900-Q1', 1, N'Ukjent', '1900-01', 1, 1, 1900, '1900-W01', 1, N'Ukjent', 0, 0, NULL);
GO

------------------------------------------------------------------------
-- 3. DimKunde (SCD type 2)
------------------------------------------------------------------------
CREATE TABLE dw.DimKunde (
    KundeKey               INT IDENTITY(1,1) NOT NULL PRIMARY KEY,     -- surrogatnøkkel
    KundeId                INT           NOT NULL,                     -- forretningsnøkkel fra NordhandelShop
    -- Type 1: overskrives
    Navn                   NVARCHAR(200) NOT NULL,                     -- Fornavn + Etternavn (vurder GDPR før Power BI!)
    -- Type 2: ny rad ved endring
    Postnummer             CHAR(4)       NOT NULL,                     -- '0000' = ukjent
    Poststed               NVARCHAR(100) NOT NULL,
    Kommune                NVARCHAR(100) NOT NULL,
    Fylke                  NVARCHAR(100) NOT NULL,
    Kundesegment           NVARCHAR(20)  NOT NULL,                     -- 'Privat','Bedrift','Ukjent'
    -- Type 0: settes ved første lasting, aldri endret
    OpprinneligKundesegment NVARCHAR(20) NOT NULL,
    KundeSiden             DATE          NOT NULL,
    -- SCD2-styring
    GyldigFra              DATE          NOT NULL,
    GyldigTil              DATE          NOT NULL,                     -- '9999-12-31' for gjeldende rad (ikke NULL: enklere BETWEEN)
    ErGjeldende            BIT           NOT NULL,
    -- Revisjon
    InnsattKjoringId       INT           NULL,
    OppdatertKjoringId     INT           NULL
);

-- Én gjeldende rad per kunde (filtrert unik indeks)
CREATE UNIQUE INDEX UX_DimKunde_Gjeldende ON dw.DimKunde (KundeId) WHERE ErGjeldende = 1;
-- Oppslag av riktig versjon for en gitt dato (brukes av faktalastingen)
CREATE UNIQUE INDEX UX_DimKunde_Versjon   ON dw.DimKunde (KundeId, GyldigFra) INCLUDE (GyldigTil);
GO

------------------------------------------------------------------------
-- 4. DimProdukt (SCD type 2 på pris og kategori)
------------------------------------------------------------------------
CREATE TABLE dw.DimProdukt (
    ProduktKey         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProduktId          INT           NOT NULL,                         -- forretningsnøkkel
    Varenummer         NVARCHAR(20)  NOT NULL,                         -- den brukerne kjenner igjen
    -- Type 1
    Navn               NVARCHAR(200) NOT NULL,
    Merke              NVARCHAR(100) NOT NULL,                         -- normalisert; 'Ukjent' for NULL
    Aktiv              BIT           NOT NULL,
    -- Type 2: hierarkiet flatet ut (stjerne, ikke snøfnugg)
    Hovedkategori      NVARCHAR(100) NOT NULL,                         -- 'Klær'
    Kategori           NVARCHAR(100) NOT NULL,                         -- 'Jakker'   (= Hovedkategori hvis produktet ligger på nivå 1)
    Underkategori      NVARCHAR(100) NOT NULL,                         -- 'Skalljakker' (= Kategori hvis produktet ligger på nivå 2)
    Innkjopspris       DECIMAL(10,2) NOT NULL,
    Salgspris          DECIMAL(10,2) NOT NULL,
    -- SCD2-styring
    GyldigFra          DATE          NOT NULL,
    GyldigTil          DATE          NOT NULL,
    ErGjeldende        BIT           NOT NULL,
    InnsattKjoringId   INT           NULL,
    OppdatertKjoringId INT           NULL
);
CREATE UNIQUE INDEX UX_DimProdukt_Gjeldende ON dw.DimProdukt (ProduktId) WHERE ErGjeldende = 1;
CREATE UNIQUE INDEX UX_DimProdukt_Versjon   ON dw.DimProdukt (ProduktId, GyldigFra) INCLUDE (GyldigTil);
GO

------------------------------------------------------------------------
-- 5. DimOrdreinfo – junk dimension
--    Tre små attributter med få verdier. Alle kombinasjoner fylles på
--    forhånd (6 × 4 × 3 = 72 rader); ETL slår bare opp.
------------------------------------------------------------------------
CREATE TABLE dw.DimOrdreinfo (
    OrdreinfoKey   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Status         NVARCHAR(20) NOT NULL,
    Betalingsmate  NVARCHAR(20) NOT NULL,      -- 'Ukjent' for NULL
    Kanal          NVARCHAR(20) NOT NULL,
    -- Avledede flagg: forretningsregler definert ÉN gang, her
    ErGyldigSalg   BIT NOT NULL,               -- teller i omsetning?
    ErReturnert    BIT NOT NULL,
    ErKansellert   BIT NOT NULL,
    CONSTRAINT UX_DimOrdreinfo UNIQUE (Status, Betalingsmate, Kanal)
);

INSERT INTO dw.DimOrdreinfo (Status, Betalingsmate, Kanal, ErGyldigSalg, ErReturnert, ErKansellert)
SELECT s.Status, b.Betalingsmate, k.Kanal,
       CASE WHEN s.Status IN ('Kansellert') THEN 0 ELSE 1 END,   -- Returnert teller som salg (og som retur) – se lab U
       CASE WHEN s.Status = 'Returnert'  THEN 1 ELSE 0 END,
       CASE WHEN s.Status = 'Kansellert' THEN 1 ELSE 0 END
FROM (VALUES ('Ny'), ('Betalt'), ('Sendt'), ('Levert'), ('Kansellert'), ('Returnert')) s(Status)
CROSS JOIN (VALUES ('Kort'), ('Vipps'), ('Faktura'), ('Ukjent')) b(Betalingsmate)
CROSS JOIN (VALUES ('Web'), ('App'), ('Butikk')) k(Kanal);
GO

------------------------------------------------------------------------
-- 6. FaktSalg – korn: én rad per ordrelinje
------------------------------------------------------------------------
CREATE TABLE dw.FaktSalg (
    SalgKey            BIGINT IDENTITY(1,1) NOT NULL,
    -- Dimensjonsnøkler (surrogat)
    OrdreDatoKey       INT NOT NULL REFERENCES dw.DimDato(DatoKey),
    KundeKey           INT NOT NULL REFERENCES dw.DimKunde(KundeKey),
    ProduktKey         INT NOT NULL REFERENCES dw.DimProdukt(ProduktKey),
    OrdreinfoKey       INT NOT NULL REFERENCES dw.DimOrdreinfo(OrdreinfoKey),
    -- Degenererte dimensjoner (nøkler fra kilden uten egen dimensjonstabell)
    OrdreId            INT NOT NULL,
    OrdrelinjeId       INT NOT NULL,                     -- forretningsnøkkel for faktaraden → idempotent lasting
    -- Fakta (målbare, additive)
    Antall             INT           NOT NULL,
    BruttoBelop        DECIMAL(12,2) NOT NULL,           -- Antall × Enhetspris
    RabattBelop        DECIMAL(12,2) NOT NULL,           -- Brutto × Rabatt%
    NettoBelop         DECIMAL(12,2) NOT NULL,           -- Brutto − Rabatt  ← «omsetning», definert én gang
    Kostnad            DECIMAL(12,2) NOT NULL,           -- Antall × Innkjopspris (på salgstidspunktet, via DimProdukt-versjon)
    Dekningsbidrag     AS (NettoBelop - Kostnad) PERSISTED,
    FraktAllokert      DECIMAL(12,2) NOT NULL,           -- ordrens frakt fordelt på linjene etter NettoBelop (lab V)
    -- Ikke-additive fakta (bevares for sporbarhet, summeres aldri)
    Enhetspris         DECIMAL(10,2) NOT NULL,
    RabattProsent      DECIMAL(5,2)  NOT NULL,
    -- Revisjon
    LastetKjoringId    INT NULL,
    CONSTRAINT PK_FaktSalg PRIMARY KEY CLUSTERED (SalgKey),            -- vi bytter dette i samling 5!
    CONSTRAINT UX_FaktSalg_Ordrelinje UNIQUE (OrdrelinjeId)
);
-- Indekser på fremmednøklene – uten dem blir alle dimensjonsjoins scans (samling 5)
CREATE INDEX IX_FaktSalg_OrdreDatoKey ON dw.FaktSalg (OrdreDatoKey);
CREATE INDEX IX_FaktSalg_KundeKey     ON dw.FaktSalg (KundeKey);
CREATE INDEX IX_FaktSalg_ProduktKey   ON dw.FaktSalg (ProduktKey);
CREATE INDEX IX_FaktSalg_OrdreId      ON dw.FaktSalg (OrdreId);
GO

------------------------------------------------------------------------
-- 7. Ukjent-rader: nøkkel -1 i hver dimensjon, så fakta aldri får NULL
------------------------------------------------------------------------
SET IDENTITY_INSERT dw.DimKunde ON;
INSERT INTO dw.DimKunde (KundeKey, KundeId, Navn, Postnummer, Poststed, Kommune, Fylke, Kundesegment,
                         OpprinneligKundesegment, KundeSiden, GyldigFra, GyldigTil, ErGjeldende)
VALUES (-1, -1, N'Ukjent kunde', '0000', N'Ukjent', N'Ukjent', N'Ukjent', N'Ukjent', N'Ukjent',
        '1900-01-01', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT dw.DimKunde OFF;

SET IDENTITY_INSERT dw.DimProdukt ON;
INSERT INTO dw.DimProdukt (ProduktKey, ProduktId, Varenummer, Navn, Merke, Aktiv, Hovedkategori, Kategori, Underkategori,
                           Innkjopspris, Salgspris, GyldigFra, GyldigTil, ErGjeldende)
VALUES (-1, -1, N'UKJENT', N'Ukjent produkt', N'Ukjent', 0, N'Ukjent', N'Ukjent', N'Ukjent',
        0, 0, '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT dw.DimProdukt OFF;

SET IDENTITY_INSERT dw.DimOrdreinfo ON;
INSERT INTO dw.DimOrdreinfo (OrdreinfoKey, Status, Betalingsmate, Kanal, ErGyldigSalg, ErReturnert, ErKansellert)
VALUES (-1, N'Ukjent', N'Ukjent', N'Ukjent', 0, 0, 0);
SET IDENTITY_INSERT dw.DimOrdreinfo OFF;
GO

------------------------------------------------------------------------
-- Kontroll
------------------------------------------------------------------------
SELECT 'DimDato' AS Tabell, COUNT(*) AS Rader FROM dw.DimDato      UNION ALL
SELECT 'DimKunde',          COUNT(*) FROM dw.DimKunde              UNION ALL
SELECT 'DimProdukt',        COUNT(*) FROM dw.DimProdukt            UNION ALL
SELECT 'DimOrdreinfo',      COUNT(*) FROM dw.DimOrdreinfo          UNION ALL
SELECT 'FaktSalg',          COUNT(*) FROM dw.FaktSalg;

SELECT Dato, UkedagNavn, HelligdagNavn FROM dw.DimDato WHERE Aar = 2025 AND ErHelligdag = 1 ORDER BY Dato;

PRINT 'NordhandelDW: skjema opprettet. ETL kommer i 03-etl.sql.';
