/* =====================================================================
   Nordhandel AS – ETL/ELT for datavarehuset
   Fil: case/03-etl.sql
   Fasit for mappeinnlevering 2 (ETL-delen). Forutsetter 02-dw-skjema.sql.

   Lastesekvens (etl.KjorAlt):
     1. Start logg                 etl.Kjoring
     2. Extract → staging          etl.Extract      (dims: full kopi; ordre: inkrementelt på SistEndret)
     ┌─ BEGIN TRANSACTION
     3. Last DimKunde (SCD 0/1/2)  etl.LastDimKunde
     4. Last DimProdukt (SCD 1/2)  etl.LastDimProdukt
     5. Last FaktSalg (upsert)     etl.LastFaktSalg
     6. Oppdater vannmerke
     └─ COMMIT  (ROLLBACK + logg + THROW ved feil)
     7. Avslutt logg

   Kjør første gang:  EXEC etl.KjorAlt @FullLast = 1;
   Deretter:          EXEC etl.KjorAlt;
   ===================================================================== */

USE NordhandelDW;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

------------------------------------------------------------------------
-- 0. Rydd ved rekjøring
------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS etl.KjorAlt, etl.Extract, etl.LastDimKunde, etl.LastDimProdukt,
                         etl.LastFaktSalg, etl.LoggSteg, etl.AvstemSlettinger;
DROP TABLE IF EXISTS stg.Kunde, stg.Kategori, stg.Produkt, stg.Ordre, stg.Ordrelinje, stg.Postnummer;
DROP TABLE IF EXISTS etl.KjoringSteg, etl.Karantene, etl.Kjoring, etl.Vannmerke;
GO

------------------------------------------------------------------------
-- 1. Staging: rå kopi av kilden, 1:1, ingen indekser, tømmes hver gang
------------------------------------------------------------------------
CREATE TABLE stg.Postnummer (Postnummer CHAR(4), Poststed NVARCHAR(100), Kommune NVARCHAR(100), Fylke NVARCHAR(100));

CREATE TABLE stg.Kunde (
    KundeId INT, Epost NVARCHAR(200), Fornavn NVARCHAR(100), Etternavn NVARCHAR(100),
    Postnummer NVARCHAR(10), Poststed NVARCHAR(100), Kundesegment NVARCHAR(20),
    Opprettet DATETIME2, SistEndret DATETIME2
);
CREATE TABLE stg.Kategori (KategoriId INT, Navn NVARCHAR(100), ForelderId INT);
CREATE TABLE stg.Produkt (
    ProduktId INT, Varenummer NVARCHAR(20), Navn NVARCHAR(200), KategoriId INT, Merke NVARCHAR(100),
    Innkjopspris DECIMAL(10,2), Salgspris DECIMAL(10,2), Aktiv BIT, SistEndret DATETIME2
);
CREATE TABLE stg.Ordre (
    OrdreId INT, KundeId INT, Ordredato DATETIME2, Status NVARCHAR(20), Betalingsmate NVARCHAR(20),
    Kanal NVARCHAR(20), Fraktkostnad DECIMAL(10,2), SistEndret DATETIME2
);
CREATE TABLE stg.Ordrelinje (
    OrdrelinjeId INT, OrdreId INT, ProduktId INT, Antall INT, EnhetsprisEksMva DECIMAL(10,2), RabattProsent DECIMAL(5,2)
);
GO

------------------------------------------------------------------------
-- 2. ETL-metadata: logg, karantene, vannmerke
------------------------------------------------------------------------
CREATE TABLE etl.Kjoring (
    KjoringId    INT IDENTITY PRIMARY KEY,
    Jobb         NVARCHAR(100) NOT NULL,
    StartTid     DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    SluttTid     DATETIME2     NULL,
    Status       NVARCHAR(20)  NOT NULL DEFAULT N'Kjører',      -- Kjører / OK / Feil
    Feilmelding  NVARCHAR(MAX) NULL
);

CREATE TABLE etl.KjoringSteg (
    StegId          INT IDENTITY PRIMARY KEY,
    KjoringId       INT NOT NULL REFERENCES etl.Kjoring(KjoringId),
    Steg            NVARCHAR(100) NOT NULL,
    StartTid        DATETIME2 NOT NULL,
    SluttTid        DATETIME2 NOT NULL,
    VarighetMs      AS DATEDIFF(millisecond, StartTid, SluttTid),
    RaderLest       INT NOT NULL DEFAULT 0,
    RaderInnsatt    INT NOT NULL DEFAULT 0,
    RaderOppdatert  INT NOT NULL DEFAULT 0,
    RaderSlettet    INT NOT NULL DEFAULT 0,
    RaderKarantene  INT NOT NULL DEFAULT 0
);

CREATE TABLE etl.Karantene (
    KaranteneId  INT IDENTITY PRIMARY KEY,
    KjoringId    INT NOT NULL,
    Kilde        NVARCHAR(50)  NOT NULL,       -- 'Kunde', 'Produkt', 'Ordre', 'Ordrelinje'
    KildeId      INT           NOT NULL,       -- nøkkelen i kilden
    Regel        NVARCHAR(100) NOT NULL,       -- hva som slo til
    Alvor        NVARCHAR(10)  NOT NULL,       -- 'Info' (korrigert automatisk) / 'Advarsel' (lastet med Ukjent) / 'Feil' (ikke lastet)
    Verdi        NVARCHAR(400) NULL,           -- den problematiske verdien
    Tidspunkt    DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    Behandlet    BIT           NOT NULL DEFAULT 0
);
CREATE INDEX IX_Karantene_Oppslag ON etl.Karantene (Kilde, KildeId, Regel);

CREATE TABLE etl.Vannmerke (
    Tabell  NVARCHAR(50) PRIMARY KEY,
    Verdi   DATETIME2 NOT NULL
);
INSERT INTO etl.Vannmerke (Tabell, Verdi) VALUES (N'Ordre', '19000101');
GO

------------------------------------------------------------------------
-- 3. Hjelpeprosedyre: logg ett steg
------------------------------------------------------------------------
CREATE PROCEDURE etl.LoggSteg
    @KjoringId INT, @Steg NVARCHAR(100), @StartTid DATETIME2,
    @Lest INT = 0, @Innsatt INT = 0, @Oppdatert INT = 0, @Slettet INT = 0, @Karantene INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO etl.KjoringSteg (KjoringId, Steg, StartTid, SluttTid, RaderLest, RaderInnsatt, RaderOppdatert, RaderSlettet, RaderKarantene)
    VALUES (@KjoringId, @Steg, @StartTid, SYSDATETIME(), @Lest, @Innsatt, @Oppdatert, @Slettet, @Karantene);
END;
GO

------------------------------------------------------------------------
-- 4. Extract: kilde → staging
--    Dimensjonskilder er små → alltid full kopi.
--    Ordre er stor → inkrementelt: SistEndret > vannmerke AND <= starttid.
--    Vannmerket settes til STARTTIDEN for uttrekket, ikke MAX(SistEndret):
--    rader som endres mens vi leser, blir med neste gang i stedet for å mistes.
------------------------------------------------------------------------
CREATE PROCEDURE etl.Extract
    @KjoringId INT, @FullLast BIT = 0, @NyttVannmerke DATETIME2 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Start DATETIME2 = SYSDATETIME(), @Lest INT = 0;
    DECLARE @Vannmerke DATETIME2 = CASE WHEN @FullLast = 1 THEN '19000101'
                                        ELSE (SELECT Verdi FROM etl.Vannmerke WHERE Tabell = N'Ordre') END;
    SET @NyttVannmerke = @Start;

    TRUNCATE TABLE stg.Postnummer;
    INSERT INTO stg.Postnummer SELECT Postnummer, Poststed, Kommune, Fylke FROM NordhandelShop.dbo.Postnummer;

    TRUNCATE TABLE stg.Kunde;
    INSERT INTO stg.Kunde
    SELECT KundeId, Epost, Fornavn, Etternavn, Postnummer, Poststed, Kundesegment, Opprettet, SistEndret
    FROM NordhandelShop.dbo.Kunde;
    SET @Lest += @@ROWCOUNT;

    TRUNCATE TABLE stg.Kategori;
    INSERT INTO stg.Kategori SELECT KategoriId, Navn, ForelderId FROM NordhandelShop.dbo.Kategori;

    TRUNCATE TABLE stg.Produkt;
    INSERT INTO stg.Produkt
    SELECT ProduktId, Varenummer, Navn, KategoriId, Merke, Innkjopspris, Salgspris, Aktiv, SistEndret
    FROM NordhandelShop.dbo.Produkt;
    SET @Lest += @@ROWCOUNT;

    TRUNCATE TABLE stg.Ordre;
    INSERT INTO stg.Ordre
    SELECT OrdreId, KundeId, Ordredato, Status, Betalingsmate, Kanal, Fraktkostnad, SistEndret
    FROM NordhandelShop.dbo.Ordre
    WHERE SistEndret > @Vannmerke AND SistEndret <= @Start;
    SET @Lest += @@ROWCOUNT;

    -- Ordrelinje har ingen SistEndret: hent alle linjer for ordrene vi hentet
    TRUNCATE TABLE stg.Ordrelinje;
    INSERT INTO stg.Ordrelinje
    SELECT ol.OrdrelinjeId, ol.OrdreId, ol.ProduktId, ol.Antall, ol.EnhetsprisEksMva, ol.RabattProsent
    FROM NordhandelShop.dbo.Ordrelinje ol
    WHERE EXISTS (SELECT 1 FROM stg.Ordre o WHERE o.OrdreId = ol.OrdreId);
    SET @Lest += @@ROWCOUNT;

    EXEC etl.LoggSteg @KjoringId, N'Extract', @Start, @Lest = @Lest;
END;
GO

------------------------------------------------------------------------
-- 5. DimKunde: SCD type 0 / 1 / 2
--    Type 1: Navn                           → overskriv ALLE versjoner
--    Type 2: Postnummer, Poststed, Kommune, Fylke, Kundesegment → ny versjon
--    Type 0: OpprinneligKundesegment, KundeSiden → arves fra første versjon
------------------------------------------------------------------------
CREATE PROCEDURE etl.LastDimKunde @KjoringId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Start DATETIME2 = SYSDATETIME(), @LastDato DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Lest INT, @Innsatt INT = 0, @Oppdatert INT = 0, @Karantene INT = 0;

    ------------------------------------------------------------------
    -- 5.1 Forbered: rens, normaliser, berik. Alt NOT NULL etter dette,
    --     så sammenligningene i 5.3 kan bruke vanlig <> uten NULL-logikk.
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Kunde;
    SELECT  k.KundeId,
            k.Navn,
            k.PostnummerRaa,
            k.PostnummerRenset,
            Postnummer   = ISNULL(p.Postnummer, '0000'),
            Poststed     = ISNULL(p.Poststed,   N'Ukjent'),
            Kommune      = ISNULL(p.Kommune,    N'Ukjent'),
            Fylke        = ISNULL(p.Fylke,      N'Ukjent'),
            k.Kundesegment,
            k.KundeSiden,
            FunnetIRegister = CASE WHEN p.Postnummer IS NULL THEN 0 ELSE 1 END
    INTO    #Kunde
    FROM (
        SELECT  KundeId,
                Navn         = TRIM(Fornavn) + N' ' + TRIM(Etternavn),
                PostnummerRaa = Postnummer,
                -- Regelbasert korreksjon: O→0, trim, ledende null
                PostnummerRenset = CASE
                    WHEN Postnummer IS NULL THEN NULL
                    WHEN LEN(TRIM(REPLACE(Postnummer, 'O', '0'))) = 3 THEN '0' + TRIM(REPLACE(Postnummer, 'O', '0'))
                    ELSE TRIM(REPLACE(Postnummer, 'O', '0')) END,
                Kundesegment = ISNULL(NULLIF(TRIM(Kundesegment), N''), N'Ukjent'),
                KundeSiden   = CAST(Opprettet AS DATE)
        FROM stg.Kunde
    ) k
    LEFT JOIN stg.Postnummer p ON p.Postnummer = k.PostnummerRenset;
    SET @Lest = @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 5.2 Karantene. Samme avvik logges bare én gang (NOT EXISTS).
    ------------------------------------------------------------------
    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Kunde', k.KundeId, r.Regel, r.Alvor, r.Verdi
    FROM #Kunde k
    CROSS APPLY (
        SELECT N'Postnummer korrigert automatisk' AS Regel, N'Info' AS Alvor,
               CONCAT(N'[', k.PostnummerRaa, N'] → ', k.Postnummer) AS Verdi
        WHERE k.FunnetIRegister = 1 AND k.PostnummerRaa IS NOT NULL
          -- binær sammenligning: ser også forskjell på '0566' og '0566 ' (vanlig = ignorerer mellomrom bak)
          AND CAST(k.PostnummerRaa AS VARBINARY(20)) <> CAST(CAST(k.Postnummer AS NVARCHAR(10)) AS VARBINARY(20))
        UNION ALL
        SELECT N'Postnummer finnes ikke i register', N'Advarsel', CONCAT(N'[', k.PostnummerRaa, N']')
        WHERE k.FunnetIRegister = 0 AND k.PostnummerRaa IS NOT NULL
        UNION ALL
        SELECT N'Postnummer mangler', N'Info', NULL
        WHERE k.PostnummerRaa IS NULL
        UNION ALL
        SELECT N'Mulig dublett (samme navn, postnummer og registrert innen 31 dager)', N'Info',
               (SELECT STRING_AGG(k2.KundeId, ',') FROM #Kunde k2
                WHERE k2.Navn = k.Navn AND k2.Postnummer = k.Postnummer AND k2.KundeId <> k.KundeId
                  AND ABS(DATEDIFF(day, k2.KundeSiden, k.KundeSiden)) <= 31)
        -- Første versjon av regelen (bare navn + postnummer) ga 1 990 treff på 5 050 kunder.
        -- Med 31-dagers-kravet: ~300 treff, hvorav ~100 er de 50 plantede parene. Resten er falske positive.
        -- Lærdom: dublettdeteksjon gir KANDIDATER som et menneske må vurdere (kolonnen Behandlet) – aldri automatisk sammenslåing.
        WHERE k.Postnummer <> '0000'
          AND EXISTS (SELECT 1 FROM #Kunde k2
                      WHERE k2.Navn = k.Navn AND k2.Postnummer = k.Postnummer AND k2.KundeId <> k.KundeId
                        AND ABS(DATEDIFF(day, k2.KundeSiden, k.KundeSiden)) <= 31)
    ) r
    WHERE NOT EXISTS (SELECT 1 FROM etl.Karantene q
                      WHERE q.Kilde = N'Kunde' AND q.KildeId = k.KundeId AND q.Regel = r.Regel);
    SET @Karantene = @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 5.3 Type 1: overskriv Navn på alle versjoner
    ------------------------------------------------------------------
    UPDATE d
    SET    Navn = k.Navn, OppdatertKjoringId = @KjoringId
    FROM   dw.DimKunde d
    JOIN   #Kunde k ON k.KundeId = d.KundeId
    WHERE  d.Navn <> k.Navn;
    SET @Oppdatert += @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 5.4 Type 2: finn gjeldende rader der type 2-attributter er endret
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Endret;
    SELECT  d.KundeKey, d.KundeId,
            SammeDag = CASE WHEN d.GyldigFra = @LastDato THEN 1 ELSE 0 END
    INTO    #Endret
    FROM    dw.DimKunde d
    JOIN    #Kunde k ON k.KundeId = d.KundeId
    WHERE   d.ErGjeldende = 1
      AND  (d.Postnummer <> k.Postnummer OR d.Poststed <> k.Poststed OR d.Kommune <> k.Kommune
            OR d.Fylke <> k.Fylke OR d.Kundesegment <> k.Kundesegment);

    -- 5.4a Versjonen ble opprettet i dag → kan ikke lage enda en versjon for samme dag. Overskriv.
    UPDATE d
    SET    Postnummer = k.Postnummer, Poststed = k.Poststed, Kommune = k.Kommune, Fylke = k.Fylke,
           Kundesegment = k.Kundesegment, OppdatertKjoringId = @KjoringId
    FROM   dw.DimKunde d
    JOIN   #Endret e ON e.KundeKey = d.KundeKey AND e.SammeDag = 1
    JOIN   #Kunde  k ON k.KundeId  = e.KundeId;
    SET @Oppdatert += @@ROWCOUNT;

    -- 5.4b Utløp gammel versjon: gyldig til og med i går
    UPDATE d
    SET    GyldigTil = DATEADD(day, -1, @LastDato), ErGjeldende = 0, OppdatertKjoringId = @KjoringId
    FROM   dw.DimKunde d
    JOIN   #Endret e ON e.KundeKey = d.KundeKey AND e.SammeDag = 0;
    SET @Oppdatert += @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 5.5 Sett inn: nye versjoner (fra 5.4b) og helt nye kunder.
    --     Begge mangler nå en gjeldende rad → ett INSERT dekker begge.
    ------------------------------------------------------------------
    INSERT INTO dw.DimKunde (KundeId, Navn, Postnummer, Poststed, Kommune, Fylke, Kundesegment,
                             OpprinneligKundesegment, KundeSiden, GyldigFra, GyldigTil, ErGjeldende, InnsattKjoringId)
    SELECT  k.KundeId, k.Navn, k.Postnummer, k.Poststed, k.Kommune, k.Fylke, k.Kundesegment,
            OpprinneligKundesegment = ISNULL(f.OpprinneligKundesegment, k.Kundesegment),  -- type 0: arv
            KundeSiden              = ISNULL(f.KundeSiden, k.KundeSiden),                 -- type 0: arv
            GyldigFra               = CASE WHEN f.KundeId IS NULL THEN '19000101'          -- ny kunde: «fra tidenes morgen»
                                           ELSE @LastDato END,                             -- ny versjon: fra i dag
            GyldigTil               = '99991231',
            ErGjeldende             = 1,
            InnsattKjoringId        = @KjoringId
    FROM    #Kunde k
    LEFT JOIN (SELECT KundeId, MAX(OpprinneligKundesegment) AS OpprinneligKundesegment, MIN(KundeSiden) AS KundeSiden
               FROM dw.DimKunde GROUP BY KundeId) f ON f.KundeId = k.KundeId
    WHERE NOT EXISTS (SELECT 1 FROM dw.DimKunde d WHERE d.KundeId = k.KundeId AND d.ErGjeldende = 1);
    SET @Innsatt = @@ROWCOUNT;

    EXEC etl.LoggSteg @KjoringId, N'LastDimKunde', @Start, @Lest, @Innsatt, @Oppdatert, 0, @Karantene;
END;
GO

------------------------------------------------------------------------
-- 6. DimProdukt: SCD type 1 / 2
--    Type 1: Varenummer, Navn, Merke, Aktiv
--    Type 2: Hovedkategori, Kategori, Underkategori, Innkjopspris, Salgspris
------------------------------------------------------------------------
CREATE PROCEDURE etl.LastDimProdukt @KjoringId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Start DATETIME2 = SYSDATETIME(), @LastDato DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Lest INT, @Innsatt INT = 0, @Oppdatert INT = 0, @Karantene INT = 0;

    ------------------------------------------------------------------
    -- 6.1 Flat ut kategorihierarkiet (rekursiv CTE – én gang, her, ikke i hver rapport)
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Hierarki;
    ;WITH H AS (
        SELECT KategoriId, Navn, 1 AS Nivaa,
               N1 = Navn, N2 = CAST(NULL AS NVARCHAR(100)), N3 = CAST(NULL AS NVARCHAR(100))
        FROM stg.Kategori WHERE ForelderId IS NULL
        UNION ALL
        SELECT k.KategoriId, k.Navn, h.Nivaa + 1,
               h.N1,
               CASE WHEN h.Nivaa + 1 = 2 THEN k.Navn ELSE h.N2 END,
               CASE WHEN h.Nivaa + 1 = 3 THEN k.Navn ELSE h.N3 END
        FROM stg.Kategori k JOIN H h ON h.KategoriId = k.ForelderId
    )
    SELECT KategoriId,
           Hovedkategori = N1,
           Kategori      = ISNULL(N2, N1),          -- produkt på nivå 1: Kategori = Hovedkategori
           Underkategori = ISNULL(N3, ISNULL(N2, N1)),
           ErSlettet     = CASE WHEN N1 LIKE N'SLETTET%' THEN 1 ELSE 0 END
    INTO #Hierarki FROM H;

    ------------------------------------------------------------------
    -- 6.2 Kanonisk merkenavn: for hver UPPER(TRIM(merke)), velg skrivemåten flest produkter bruker.
    --     COLLATE BIN2 er nødvendig: under CI-kollasjon ser GROUP BY 'Osprey' og 'OSPREY' som samme verdi
    --     og returnerer en vilkårlig av dem som etikett (fellen fra samling 1, demo 1.3d).
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Merke;
    SELECT Nokkel, Kanonisk = Kanonisk COLLATE DATABASE_DEFAULT      -- tilbake til standard, ellers kollasjonskonflikt i sammenligninger senere
    INTO #Merke
    FROM (
        SELECT UPPER(TRIM(Merke)) AS Nokkel,
               TRIM(Merke) COLLATE Latin1_General_BIN2 AS Kanonisk,
               ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(Merke)) ORDER BY COUNT(*) DESC, TRIM(Merke) COLLATE Latin1_General_BIN2) AS Rn
        FROM stg.Produkt WHERE Merke IS NOT NULL
        GROUP BY UPPER(TRIM(Merke)), TRIM(Merke) COLLATE Latin1_General_BIN2
    ) x WHERE Rn = 1;

    ------------------------------------------------------------------
    -- 6.3 Forbered
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Produkt;
    SELECT  p.ProduktId, p.Varenummer,
            Navn          = TRIM(p.Navn),
            Merke         = ISNULL(m.Kanonisk, N'Ukjent'),
            MerkeRaa      = p.Merke,
            p.Aktiv,
            Hovedkategori = CASE WHEN h.KategoriId IS NULL OR h.ErSlettet = 1 THEN N'Ukjent' ELSE h.Hovedkategori END,
            Kategori      = CASE WHEN h.KategoriId IS NULL OR h.ErSlettet = 1 THEN N'Ukjent' ELSE h.Kategori END,
            Underkategori = CASE WHEN h.KategoriId IS NULL OR h.ErSlettet = 1 THEN N'Ukjent' ELSE h.Underkategori END,
            p.Innkjopspris, p.Salgspris,
            KategoriProblem = CASE WHEN p.KategoriId IS NULL THEN N'Kategori mangler'
                                   WHEN h.ErSlettet = 1     THEN N'Peker på slettet kategori' END
    INTO    #Produkt
    FROM    stg.Produkt p
    LEFT JOIN #Hierarki h ON h.KategoriId = p.KategoriId
    LEFT JOIN #Merke m    ON m.Nokkel = UPPER(TRIM(p.Merke));
    SET @Lest = @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 6.4 Karantene
    ------------------------------------------------------------------
    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Produkt', p.ProduktId, r.Regel, r.Alvor, r.Verdi
    FROM #Produkt p
    CROSS APPLY (
        SELECT p.KategoriProblem AS Regel, N'Advarsel' AS Alvor, p.Varenummer AS Verdi WHERE p.KategoriProblem IS NOT NULL
        UNION ALL
        SELECT N'Merke normalisert', N'Info', CONCAT(N'[', p.MerkeRaa, N'] → ', p.Merke)
        WHERE p.MerkeRaa IS NOT NULL
          AND CAST(p.MerkeRaa AS VARBINARY(200)) <> CAST(p.Merke AS VARBINARY(200))   -- binært: ser også mellomrom bak
        UNION ALL
        SELECT N'Salgspris lavere enn innkjøpspris', N'Advarsel', CONCAT(p.Salgspris, N' < ', p.Innkjopspris)
        WHERE p.Salgspris < p.Innkjopspris
    ) r
    WHERE NOT EXISTS (SELECT 1 FROM etl.Karantene q
                      WHERE q.Kilde = N'Produkt' AND q.KildeId = p.ProduktId AND q.Regel = r.Regel);
    SET @Karantene = @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 6.5 Type 1
    ------------------------------------------------------------------
    UPDATE d
    SET    Varenummer = p.Varenummer, Navn = p.Navn, Merke = p.Merke, Aktiv = p.Aktiv, OppdatertKjoringId = @KjoringId
    FROM   dw.DimProdukt d
    JOIN   #Produkt p ON p.ProduktId = d.ProduktId
    WHERE  d.Varenummer <> p.Varenummer OR d.Navn <> p.Navn OR d.Merke <> p.Merke OR d.Aktiv <> p.Aktiv;
    SET @Oppdatert += @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 6.6 Type 2
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Endret;
    SELECT d.ProduktKey, d.ProduktId, SammeDag = CASE WHEN d.GyldigFra = @LastDato THEN 1 ELSE 0 END
    INTO   #Endret
    FROM   dw.DimProdukt d
    JOIN   #Produkt p ON p.ProduktId = d.ProduktId
    WHERE  d.ErGjeldende = 1
      AND (d.Hovedkategori <> p.Hovedkategori OR d.Kategori <> p.Kategori OR d.Underkategori <> p.Underkategori
           OR d.Innkjopspris <> p.Innkjopspris OR d.Salgspris <> p.Salgspris);

    UPDATE d
    SET    Hovedkategori = p.Hovedkategori, Kategori = p.Kategori, Underkategori = p.Underkategori,
           Innkjopspris = p.Innkjopspris, Salgspris = p.Salgspris, OppdatertKjoringId = @KjoringId
    FROM   dw.DimProdukt d
    JOIN   #Endret e ON e.ProduktKey = d.ProduktKey AND e.SammeDag = 1
    JOIN   #Produkt p ON p.ProduktId = e.ProduktId;
    SET @Oppdatert += @@ROWCOUNT;

    UPDATE d
    SET    GyldigTil = DATEADD(day, -1, @LastDato), ErGjeldende = 0, OppdatertKjoringId = @KjoringId
    FROM   dw.DimProdukt d
    JOIN   #Endret e ON e.ProduktKey = d.ProduktKey AND e.SammeDag = 0;
    SET @Oppdatert += @@ROWCOUNT;

    INSERT INTO dw.DimProdukt (ProduktId, Varenummer, Navn, Merke, Aktiv, Hovedkategori, Kategori, Underkategori,
                               Innkjopspris, Salgspris, GyldigFra, GyldigTil, ErGjeldende, InnsattKjoringId)
    SELECT  p.ProduktId, p.Varenummer, p.Navn, p.Merke, p.Aktiv, p.Hovedkategori, p.Kategori, p.Underkategori,
            p.Innkjopspris, p.Salgspris,
            CASE WHEN EXISTS (SELECT 1 FROM dw.DimProdukt d WHERE d.ProduktId = p.ProduktId) THEN @LastDato ELSE '19000101' END,
            '99991231', 1, @KjoringId
    FROM    #Produkt p
    WHERE NOT EXISTS (SELECT 1 FROM dw.DimProdukt d WHERE d.ProduktId = p.ProduktId AND d.ErGjeldende = 1);
    SET @Innsatt = @@ROWCOUNT;

    EXEC etl.LoggSteg @KjoringId, N'LastDimProdukt', @Start, @Lest, @Innsatt, @Oppdatert, 0, @Karantene;
END;
GO

------------------------------------------------------------------------
-- 7. FaktSalg: upsert på OrdrelinjeId (idempotent), surrogatnøkkeloppslag
--    med versjon på salgstidspunktet, -1 for ukjent, fraktallokering.
------------------------------------------------------------------------
CREATE PROCEDURE etl.LastFaktSalg @KjoringId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Start DATETIME2 = SYSDATETIME(), @Naa DATETIME2 = SYSDATETIME();
    DECLARE @Lest INT, @Innsatt INT = 0, @Oppdatert INT = 0, @Slettet INT = 0, @Karantene INT = 0;
    SELECT @Lest = COUNT(*) FROM stg.Ordrelinje;

    ------------------------------------------------------------------
    -- 7.1 Karantene FØR lasting: rader som ikke skal inn (Alvor = Feil)
    ------------------------------------------------------------------
    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Ordre', o.OrdreId, N'Ordredato i fremtiden', N'Feil', CONVERT(NVARCHAR(30), o.Ordredato, 120)
    FROM stg.Ordre o
    WHERE o.Ordredato > @Naa
      AND NOT EXISTS (SELECT 1 FROM etl.Karantene q WHERE q.Kilde = N'Ordre' AND q.KildeId = o.OrdreId AND q.Regel = N'Ordredato i fremtiden');
    SET @Karantene += @@ROWCOUNT;

    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Ordrelinje', ol.OrdrelinjeId, N'Antall <= 0', N'Feil', CAST(ol.Antall AS NVARCHAR(10))
    FROM stg.Ordrelinje ol
    WHERE ol.Antall <= 0
      AND NOT EXISTS (SELECT 1 FROM etl.Karantene q WHERE q.Kilde = N'Ordrelinje' AND q.KildeId = ol.OrdrelinjeId AND q.Regel = N'Antall <= 0');
    SET @Karantene += @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 7.2 Forbered linjer: slå opp surrogatnøkler for RIKTIG VERSJON
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Linje;
    SELECT  ol.OrdrelinjeId, ol.OrdreId, o.KundeId, ol.ProduktId,
            OrdreDato    = CAST(o.Ordredato AS DATE),
            OrdreDatoKey = ISNULL(d.DatoKey, 19000101),
            KundeKey     = ISNULL(k.KundeKey, -1),
            ProduktKey   = ISNULL(p.ProduktKey, -1),
            OrdreinfoKey = ISNULL(oi.OrdreinfoKey, -1),
            ol.Antall,
            Enhetspris   = ol.EnhetsprisEksMva,
            ol.RabattProsent,
            BruttoBelop  = CAST(ol.Antall * ol.EnhetsprisEksMva AS DECIMAL(12,2)),
            RabattBelop  = CAST(ROUND(ol.Antall * ol.EnhetsprisEksMva * ol.RabattProsent / 100.0, 2) AS DECIMAL(12,2)),
            Kostnad      = CAST(ol.Antall * ISNULL(p.Innkjopspris, 0) AS DECIMAL(12,2)),
            o.Fraktkostnad
    INTO    #Linje
    FROM    stg.Ordrelinje ol
    JOIN    stg.Ordre o        ON o.OrdreId = ol.OrdreId
    LEFT JOIN dw.DimDato d     ON d.Dato = CAST(o.Ordredato AS DATE)
    LEFT JOIN dw.DimKunde k    ON k.KundeId = o.KundeId
                              AND CAST(o.Ordredato AS DATE) BETWEEN k.GyldigFra AND k.GyldigTil    -- versjonen som gjaldt da
    LEFT JOIN dw.DimProdukt p  ON p.ProduktId = ol.ProduktId
                              AND CAST(o.Ordredato AS DATE) BETWEEN p.GyldigFra AND p.GyldigTil
    LEFT JOIN dw.DimOrdreinfo oi ON oi.Status = o.Status
                              AND oi.Betalingsmate = ISNULL(o.Betalingsmate, N'Ukjent')
                              AND oi.Kanal = o.Kanal
    WHERE   o.Ordredato <= @Naa          -- ekskluder fremtidsdaterte (karantene 7.1)
      AND   ol.Antall > 0;               -- ekskluder antall <= 0   (karantene 7.1)

    -- Advarsler for ukjent-nøkler: lastet, men bør undersøkes
    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Ordrelinje', l.OrdrelinjeId, r.Regel, N'Advarsel', r.Verdi
    FROM #Linje l
    CROSS APPLY (
        SELECT N'Kunde ikke funnet i DimKunde' AS Regel, CAST(l.KundeId AS NVARCHAR(20)) AS Verdi WHERE l.KundeKey = -1
        UNION ALL SELECT N'Produkt ikke funnet i DimProdukt', CAST(l.ProduktId AS NVARCHAR(20)) WHERE l.ProduktKey = -1
        UNION ALL SELECT N'Ordreinfo-kombinasjon ukjent', NULL WHERE l.OrdreinfoKey = -1
        UNION ALL SELECT N'Dato utenfor DimDato', CONVERT(NVARCHAR(10), l.OrdreDato, 120) WHERE l.OrdreDatoKey = 19000101
    ) r
    WHERE NOT EXISTS (SELECT 1 FROM etl.Karantene q WHERE q.Kilde = N'Ordrelinje' AND q.KildeId = l.OrdrelinjeId AND q.Regel = r.Regel);
    SET @Karantene += @@ROWCOUNT;

    ------------------------------------------------------------------
    -- 7.3 Fraktallokering: proporsjonalt med netto, avrundingsrest på siste linje
    ------------------------------------------------------------------
    DROP TABLE IF EXISTS #Frakt;
    ;WITH Netto AS (
        SELECT OrdrelinjeId, OrdreId, Fraktkostnad,
               Netto      = BruttoBelop - RabattBelop,
               OrdreNetto = SUM(BruttoBelop - RabattBelop) OVER (PARTITION BY OrdreId),
               Linjer     = COUNT(*) OVER (PARTITION BY OrdreId),
               Rn         = ROW_NUMBER() OVER (PARTITION BY OrdreId ORDER BY OrdrelinjeId DESC)
        FROM #Linje
    ), Naiv AS (
        SELECT *, FraktNaiv = CASE WHEN OrdreNetto = 0 THEN ROUND(Fraktkostnad / Linjer, 2)
                                   ELSE ROUND(Fraktkostnad * Netto / OrdreNetto, 2) END
        FROM Netto
    )
    SELECT OrdrelinjeId,
           FraktAllokert = CAST(CASE WHEN Rn = 1 THEN FraktNaiv + (Fraktkostnad - SUM(FraktNaiv) OVER (PARTITION BY OrdreId))
                                     ELSE FraktNaiv END AS DECIMAL(12,2))
    INTO #Frakt FROM Naiv;

    ------------------------------------------------------------------
    -- 7.4 Upsert: MERGE på forretningsnøkkelen OrdrelinjeId.
    --     Rekjøring gir 0 innsatt; statusendring på en ordre gir oppdatert.
    --     NB: Ingen WHEN NOT MATCHED BY SOURCE – kilden er inkrementell!
    ------------------------------------------------------------------
    DECLARE @Resultat TABLE (Handling NVARCHAR(10));

    MERGE dw.FaktSalg AS t
    USING (SELECT l.*, f.FraktAllokert FROM #Linje l JOIN #Frakt f ON f.OrdrelinjeId = l.OrdrelinjeId) AS s
       ON t.OrdrelinjeId = s.OrdrelinjeId
    WHEN MATCHED AND (   t.OrdreinfoKey <> s.OrdreinfoKey OR t.KundeKey <> s.KundeKey OR t.ProduktKey <> s.ProduktKey
                      OR t.OrdreDatoKey <> s.OrdreDatoKey OR t.Antall <> s.Antall OR t.Enhetspris <> s.Enhetspris
                      OR t.RabattProsent <> s.RabattProsent OR t.FraktAllokert <> s.FraktAllokert OR t.Kostnad <> s.Kostnad)
        THEN UPDATE SET
            OrdreDatoKey = s.OrdreDatoKey, KundeKey = s.KundeKey, ProduktKey = s.ProduktKey, OrdreinfoKey = s.OrdreinfoKey,
            OrdreId = s.OrdreId, Antall = s.Antall, BruttoBelop = s.BruttoBelop, RabattBelop = s.RabattBelop,
            NettoBelop = s.BruttoBelop - s.RabattBelop, Kostnad = s.Kostnad, FraktAllokert = s.FraktAllokert,
            Enhetspris = s.Enhetspris, RabattProsent = s.RabattProsent, LastetKjoringId = @KjoringId
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (OrdreDatoKey, KundeKey, ProduktKey, OrdreinfoKey, OrdreId, OrdrelinjeId, Antall,
                     BruttoBelop, RabattBelop, NettoBelop, Kostnad, FraktAllokert, Enhetspris, RabattProsent, LastetKjoringId)
             VALUES (s.OrdreDatoKey, s.KundeKey, s.ProduktKey, s.OrdreinfoKey, s.OrdreId, s.OrdrelinjeId, s.Antall,
                     s.BruttoBelop, s.RabattBelop, s.BruttoBelop - s.RabattBelop, s.Kostnad, s.FraktAllokert,
                     s.Enhetspris, s.RabattProsent, @KjoringId)
    OUTPUT $action INTO @Resultat;

    SELECT @Innsatt   = COUNT(*) FROM @Resultat WHERE Handling = 'INSERT';
    SELECT @Oppdatert = COUNT(*) FROM @Resultat WHERE Handling = 'UPDATE';

    ------------------------------------------------------------------
    -- 7.5 Linjer som er borte fra ordrer vi HAR hentet (slettet, eller nå ugyldige)
    --     Harde slettinger av hele ordrer fanges ikke her – se etl.AvstemSlettinger.
    ------------------------------------------------------------------
    DELETE f
    FROM   dw.FaktSalg f
    WHERE  EXISTS (SELECT 1 FROM stg.Ordre o WHERE o.OrdreId = f.OrdreId)
      AND NOT EXISTS (SELECT 1 FROM #Linje l WHERE l.OrdrelinjeId = f.OrdrelinjeId);
    SET @Slettet = @@ROWCOUNT;

    EXEC etl.LoggSteg @KjoringId, N'LastFaktSalg', @Start, @Lest, @Innsatt, @Oppdatert, @Slettet, @Karantene;
END;
GO

------------------------------------------------------------------------
-- 8. Avstemming av harde slettinger (lab U). Kjøres sjeldnere (f.eks. ukentlig):
--    sammenligner HELE nøkkelmengden i kilden med fakta.
------------------------------------------------------------------------
CREATE PROCEDURE etl.AvstemSlettinger @KjoringId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Start DATETIME2 = SYSDATETIME(), @Slettet INT;

    DROP TABLE IF EXISTS #KildeNokler;
    SELECT OrdrelinjeId INTO #KildeNokler FROM NordhandelShop.dbo.Ordrelinje;   -- bare nøkler: billig selv for store tabeller

    INSERT INTO etl.Karantene (KjoringId, Kilde, KildeId, Regel, Alvor, Verdi)
    SELECT @KjoringId, N'Ordrelinje', f.OrdrelinjeId, N'Slettet i kilden', N'Info', CONCAT(N'OrdreId ', f.OrdreId, N', netto ', f.NettoBelop)
    FROM dw.FaktSalg f
    WHERE NOT EXISTS (SELECT 1 FROM #KildeNokler k WHERE k.OrdrelinjeId = f.OrdrelinjeId);

    DELETE f FROM dw.FaktSalg f
    WHERE NOT EXISTS (SELECT 1 FROM #KildeNokler k WHERE k.OrdrelinjeId = f.OrdrelinjeId);
    SET @Slettet = @@ROWCOUNT;

    EXEC etl.LoggSteg @KjoringId, N'AvstemSlettinger', @Start, @Slettet = @Slettet, @Karantene = @Slettet;
END;
GO

------------------------------------------------------------------------
-- 9. Orkestrering
------------------------------------------------------------------------
CREATE PROCEDURE etl.KjorAlt @FullLast BIT = 0, @MedAvstemming BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;                           -- enhver feil gjør transaksjonen udømmelig → garantert rollback

    DECLARE @KjoringId INT, @NyttVannmerke DATETIME2;

    INSERT INTO etl.Kjoring (Jobb) VALUES (CASE WHEN @FullLast = 1 THEN N'Full last' ELSE N'Inkrementell last' END);
    SET @KjoringId = SCOPE_IDENTITY();

    BEGIN TRY
        -- Extract utenfor transaksjonen: staging er engangs, og vi vil ikke holde låser mens vi leser kilden
        EXEC etl.Extract @KjoringId, @FullLast, @NyttVannmerke OUTPUT;

        BEGIN TRANSACTION;
            EXEC etl.LastDimKunde   @KjoringId;      -- dimensjoner FØR fakta
            EXEC etl.LastDimProdukt @KjoringId;
            EXEC etl.LastFaktSalg   @KjoringId;
            IF @MedAvstemming = 1 EXEC etl.AvstemSlettinger @KjoringId;
            UPDATE etl.Vannmerke SET Verdi = @NyttVannmerke WHERE Tabell = N'Ordre';   -- sist, inne i transaksjonen
        COMMIT;

        UPDATE etl.Kjoring SET SluttTid = SYSDATETIME(), Status = N'OK' WHERE KjoringId = @KjoringId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE etl.Kjoring
        SET    SluttTid = SYSDATETIME(), Status = N'Feil',
               Feilmelding = CONCAT(ERROR_PROCEDURE(), N' (linje ', ERROR_LINE(), N'): ', ERROR_MESSAGE())
        WHERE  KjoringId = @KjoringId;
        THROW;                                   -- la jobbplanleggeren se feilen
    END CATCH;
END;
GO

------------------------------------------------------------------------
-- 10. Overvåkningsview: siste kjøringer med radantall per steg
------------------------------------------------------------------------
CREATE OR ALTER VIEW etl.vKjoringer AS
SELECT  k.KjoringId, k.Jobb, k.StartTid, k.Status,
        VarighetSek = DATEDIFF(second, k.StartTid, k.SluttTid),
        s.Steg, s.RaderLest, s.RaderInnsatt, s.RaderOppdatert, s.RaderSlettet, s.RaderKarantene, s.VarighetMs,
        k.Feilmelding
FROM    etl.Kjoring k
LEFT JOIN etl.KjoringSteg s ON s.KjoringId = k.KjoringId;
GO

PRINT 'ETL opprettet. Kjør: EXEC etl.KjorAlt @FullLast = 1;';
