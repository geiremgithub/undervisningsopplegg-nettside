/* =====================================================================
   Nordhandel AS – kildesystem (OLTP)
   Fil: case/00-oltp-skjema.sql
   Kjøres én gang før samling 1. Krever SQL Server 2019 eller nyere.
   ===================================================================== */

IF DB_ID('NordhandelShop') IS NULL
    CREATE DATABASE NordhandelShop;
GO
USE NordhandelShop;
GO

-- Rydd ved rekjøring (rekkefølge pga. fremmednøkler)
DROP TABLE IF EXISTS dbo.Ordrelinje;
DROP TABLE IF EXISTS dbo.Ordre;
DROP TABLE IF EXISTS dbo.Produkt;
DROP TABLE IF EXISTS dbo.Kategori;
DROP TABLE IF EXISTS dbo.Kunde;
DROP TABLE IF EXISTS dbo.Postnummer;
GO

/* Referansetabell fra Bring. Legg merke til at Kunde.Postnummer er
   NVARCHAR(10) mens denne er CHAR(4) – det er med vilje (samling 6). */
CREATE TABLE dbo.Postnummer (
    Postnummer  CHAR(4)       NOT NULL PRIMARY KEY,
    Poststed    NVARCHAR(100) NOT NULL,
    Kommune     NVARCHAR(100) NOT NULL,
    Fylke       NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Kunde (
    KundeId        INT IDENTITY PRIMARY KEY,
    Epost          NVARCHAR(200) NOT NULL UNIQUE,
    Fornavn        NVARCHAR(100) NOT NULL,
    Etternavn      NVARCHAR(100) NOT NULL,
    Postnummer     NVARCHAR(10)  NULL,          -- NULL og feil format forekommer
    Poststed       NVARCHAR(100) NULL,
    Kundesegment   NVARCHAR(20)  NULL,          -- 'Privat', 'Bedrift', NULL
    Opprettet      DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    SistEndret     DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Kategori (
    KategoriId     INT IDENTITY PRIMARY KEY,
    Navn           NVARCHAR(100) NOT NULL,
    ForelderId     INT NULL REFERENCES dbo.Kategori(KategoriId)   -- hierarki: Klær > Jakker > Skalljakker
);

CREATE TABLE dbo.Produkt (
    ProduktId      INT IDENTITY PRIMARY KEY,
    Varenummer     NVARCHAR(20)  NOT NULL UNIQUE,
    Navn           NVARCHAR(200) NOT NULL,
    KategoriId     INT NULL REFERENCES dbo.Kategori(KategoriId),  -- NULL forekommer
    Merke          NVARCHAR(100) NULL,
    Innkjopspris   DECIMAL(10,2) NOT NULL,
    Salgspris      DECIMAL(10,2) NOT NULL,       -- dagens pris; historikk finnes IKKE i kilden
    Aktiv          BIT NOT NULL DEFAULT 1,
    SistEndret     DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Ordre (
    OrdreId        INT IDENTITY PRIMARY KEY,
    KundeId        INT NOT NULL REFERENCES dbo.Kunde(KundeId),
    Ordredato      DATETIME2 NOT NULL,
    Status         NVARCHAR(20) NOT NULL,        -- 'Ny','Betalt','Sendt','Levert','Kansellert','Returnert'
    Betalingsmate  NVARCHAR(20) NULL,            -- 'Kort','Vipps','Faktura', NULL
    Kanal          NVARCHAR(20) NOT NULL,        -- 'Web','App','Butikk'
    Fraktkostnad   DECIMAL(10,2) NOT NULL DEFAULT 0,
    SistEndret     DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.Ordrelinje (
    OrdrelinjeId     INT IDENTITY PRIMARY KEY,
    OrdreId          INT NOT NULL REFERENCES dbo.Ordre(OrdreId),
    ProduktId        INT NOT NULL REFERENCES dbo.Produkt(ProduktId),
    Antall           INT NOT NULL,
    EnhetsprisEksMva DECIMAL(10,2) NOT NULL,     -- prisen på salgstidspunktet
    RabattProsent    DECIMAL(5,2) NOT NULL DEFAULT 0
);
GO

/* Typiske OLTP-indekser: fremmednøkler og oppslag kassesystemet trenger.
   Legg merke til at det IKKE finnes indekser tilpasset rapportering. */
CREATE INDEX IX_Ordre_KundeId      ON dbo.Ordre(KundeId);
CREATE INDEX IX_Ordre_Ordredato    ON dbo.Ordre(Ordredato);
CREATE INDEX IX_Ordrelinje_OrdreId ON dbo.Ordrelinje(OrdreId);
CREATE INDEX IX_Ordrelinje_Produkt ON dbo.Ordrelinje(ProduktId);
CREATE INDEX IX_Produkt_KategoriId ON dbo.Produkt(KategoriId);
GO

PRINT 'NordhandelShop: skjema opprettet. Kjør nå 01-oltp-testdata.sql.';
