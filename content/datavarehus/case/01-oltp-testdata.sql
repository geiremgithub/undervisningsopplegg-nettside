/* =====================================================================
   Nordhandel AS – testdata for kildesystemet
   Fil: case/01-oltp-testdata.sql
   Forutsetter at 00-oltp-skjema.sql er kjørt.
   Kjøretid: 30–90 sekunder på en laptop.

   Genererer ca.
     5 050 kunder         (5 000 + 50 nesten-dubletter)
        20 kategorier     (3 nivåer + én «slettet» kategori)
       800 produkter
   195 000 ordrer         (2023-01-01 – 2025-12-31, færre i Q1)
   585 000 ordrelinjer

   INNEBYGDE KVALITETSFEIL (brukes i samling 1 og 3):
     K1  ~3 %  kunder uten postnummer
     K2  ~1 %  postnummer med bokstaven O i stedet for 0 («O566»)
     K3  ~1 %  postnummer som har mistet ledende null («566»)
     K4  ~1 %  postnummer med etterfølgende mellomrom
     K5  ~10 % kunder uten Kundesegment
     K6   50   nesten-dubletter (samme navn + postnummer, annen e-post)
     K7   40   kunder «opprettet» etter sin første ordre
     P1  ~2 %  produkter uten kategori
     P2  ~1 %  produkter som peker på kategori 20 «SLETTET»
     P3  ~5 %  produkter uten merke
     P4   25   produkter med merke i STORE BOKSTAVER eller med mellomrom
     P5  ~3 %  produkter med salgspris lavere enn innkjøpspris
     O1  150   ordrer med ordredato i fremtiden
     O2  ~2 %  ordrer uten betalingsmåte
     L1  ~0,2% ordrelinjer med Antall = 0
   ===================================================================== */

USE NordhandelShop;
GO
SET NOCOUNT ON;

------------------------------------------------------------------------
-- 0. Tøm tabeller og nullstill identity
------------------------------------------------------------------------
DELETE FROM dbo.Ordrelinje;
DELETE FROM dbo.Ordre;
DELETE FROM dbo.Produkt;
DELETE FROM dbo.Kategori;
DELETE FROM dbo.Kunde;
DELETE FROM dbo.Postnummer;
DBCC CHECKIDENT ('dbo.Ordrelinje', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Ordre',      RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Produkt',    RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Kategori',   RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Kunde',      RESEED, 0) WITH NO_INFOMSGS;

------------------------------------------------------------------------
-- 1. Talltabell 1..1 000 000 (gjenbrukes i samling 2 for DimDato)
------------------------------------------------------------------------
IF OBJECT_ID('dbo.Tall') IS NULL
BEGIN
    CREATE TABLE dbo.Tall (N INT NOT NULL PRIMARY KEY);

    ;WITH L0 AS (SELECT 1 AS c FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(c)), -- 10
          L1 AS (SELECT 1 AS c FROM L0 a CROSS JOIN L0 b),                                   -- 100
          L2 AS (SELECT 1 AS c FROM L1 a CROSS JOIN L1 b),                                   -- 10 000
          L3 AS (SELECT 1 AS c FROM L2 a CROSS JOIN L1 b)                                    -- 1 000 000
    INSERT INTO dbo.Tall (N)
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM L3;
END;

------------------------------------------------------------------------
-- 2. Postnummerregister (utdrag)
------------------------------------------------------------------------
INSERT INTO dbo.Postnummer (Postnummer, Poststed, Kommune, Fylke) VALUES
('0150','Oslo','Oslo','Oslo'),
('0566','Oslo','Oslo','Oslo'),
('1337','Sandvika','Bærum','Akershus'),
('1400','Ski','Nordre Follo','Akershus'),
('2000','Lillestrøm','Lillestrøm','Akershus'),
('1607','Fredrikstad','Fredrikstad','Østfold'),
('1776','Halden','Halden','Østfold'),
('2300','Hamar','Hamar','Innlandet'),
('2600','Lillehammer','Lillehammer','Innlandet'),
('3015','Drammen','Drammen','Buskerud'),
('3200','Sandefjord','Sandefjord','Vestfold'),
('3700','Skien','Skien','Telemark'),
('4006','Stavanger','Stavanger','Rogaland'),
('4306','Sandnes','Sandnes','Rogaland'),
('4610','Kristiansand S','Kristiansand','Agder'),
('5003','Bergen','Bergen','Vestland'),
('5200','Os','Bjørnafjorden','Vestland'),
('6002','Ålesund','Ålesund','Møre og Romsdal'),
('6413','Molde','Molde','Møre og Romsdal'),
('7010','Trondheim','Trondheim','Trøndelag'),
('7650','Verdal','Verdal','Trøndelag'),
('8006','Bodø','Bodø','Nordland'),
('9008','Tromsø','Tromsø','Troms'),
('9510','Alta','Alta','Finnmark'),
('9600','Hammerfest','Hammerfest','Finnmark');

------------------------------------------------------------------------
-- 3. Kunder (5 000)
--    Mønster: CROSS APPLY med NEWID() gir nye tilfeldige tall per rad.
------------------------------------------------------------------------
INSERT INTO dbo.Kunde (Epost, Fornavn, Etternavn, Postnummer, Poststed, Kundesegment, Opprettet, SistEndret)
SELECT
    LOWER(f.Fornavn + '.' + e.Etternavn + CAST(t.N AS VARCHAR(10)) + '@'
          + CHOOSE(1 + r.R3 % 4, 'gmail.com', 'hotmail.com', 'online.no', 'firma.no')),
    f.Fornavn,
    e.Etternavn,
    CASE
        WHEN r.R4 % 100 < 3                                   THEN NULL                               -- K1
        WHEN r.R4 % 100 = 3                                   THEN REPLACE(p.Postnummer, '0', 'O')    -- K2
        WHEN r.R4 % 100 = 4 AND LEFT(p.Postnummer, 1) = '0'   THEN SUBSTRING(p.Postnummer, 2, 3)      -- K3
        WHEN r.R4 % 100 = 5                                   THEN p.Postnummer + ' '                 -- K4
        ELSE p.Postnummer
    END,
    CASE WHEN r.R4 % 100 < 3 THEN NULL ELSE p.Poststed END,
    CASE WHEN r.R5 % 10 < 7 THEN 'Privat'
         WHEN r.R5 % 10 < 9 THEN 'Bedrift'
         ELSE NULL END,                                                                                -- K5
    d.Opprettet,
    d.Opprettet
FROM dbo.Tall t
CROSS APPLY (SELECT (CHECKSUM(NEWID()) & 2147483647) AS R1, (CHECKSUM(NEWID()) & 2147483647) AS R2,
                    (CHECKSUM(NEWID()) & 2147483647) AS R3, (CHECKSUM(NEWID()) & 2147483647) AS R4,
                    (CHECKSUM(NEWID()) & 2147483647) AS R5, (CHECKSUM(NEWID()) & 2147483647) AS R6,
                    (CHECKSUM(NEWID()) & 2147483647) AS R7) r
CROSS APPLY (SELECT CHOOSE(1 + r.R1 % 20, 'Ola','Kari','Per','Anne','Lars','Ingrid','Jon','Marit','Knut','Liv',
                           'Erik','Hanne','Bjørn','Silje','Tor','Astrid','Nils','Randi','Geir','Solveig') AS Fornavn) f
CROSS APPLY (SELECT CHOOSE(1 + r.R2 % 20, 'Hansen','Johansen','Olsen','Larsen','Andersen','Pedersen','Nilsen','Kristiansen',
                           'Jensen','Karlsen','Johnsen','Pettersen','Eriksen','Berg','Haugen','Hagen','Johannessen',
                           'Andreassen','Jacobsen','Dahl') AS Etternavn) e
CROSS APPLY (SELECT Postnummer, Poststed FROM dbo.Postnummer
             ORDER BY Postnummer OFFSET r.R6 % 25 ROWS FETCH NEXT 1 ROWS ONLY) p
CROSS APPLY (SELECT DATEADD(minute, r.R7 % 1051200, '2021-01-01') AS Opprettet) d   -- 2021–2022
WHERE t.N <= 5000;

-- K6: 50 nesten-dubletter
INSERT INTO dbo.Kunde (Epost, Fornavn, Etternavn, Postnummer, Poststed, Kundesegment, Opprettet, SistEndret)
SELECT TOP (50)
    LOWER(Fornavn + '_' + Etternavn + CAST(KundeId AS VARCHAR(10)) + '@gmail.com'),
    Fornavn, Etternavn, Postnummer, Poststed, Kundesegment,
    DATEADD(day, 30, Opprettet), DATEADD(day, 30, Opprettet)
FROM dbo.Kunde
ORDER BY NEWID();

-- K7: 40 kunder får Opprettet-dato etter at de har handlet
UPDATE TOP (40) dbo.Kunde SET Opprettet = '2025-06-01', SistEndret = '2025-06-01';

------------------------------------------------------------------------
-- 4. Kategorier (hierarki)
------------------------------------------------------------------------
SET IDENTITY_INSERT dbo.Kategori ON;
INSERT INTO dbo.Kategori (KategoriId, Navn, ForelderId) VALUES
( 1, 'Klær',          NULL),
( 2, 'Fottøy',        NULL),
( 3, 'Utstyr',        NULL),
( 4, 'Sekker',        NULL),
( 5, 'Jakker',        1),
( 6, 'Bukser',        1),
( 7, 'Undertøy',      1),
( 8, 'Fjellsko',      2),
( 9, 'Joggesko',      2),
(10, 'Telt',          3),
(11, 'Soveposer',     3),
(12, 'Kokeutstyr',    3),
(13, 'Dagstursekker', 4),
(14, 'Fjellsekker',   4),
(15, 'Skalljakker',   5),
(16, 'Dunjakker',     5),
(17, 'Fleecejakker',  5),
(18, 'Tunneltelt',    10),
(19, 'Kuppeltelt',    10),
(20, 'SLETTET - gamle varer', NULL);     -- P2: skal ikke brukes, men brukes
SET IDENTITY_INSERT dbo.Kategori OFF;

------------------------------------------------------------------------
-- 5. Produkter (800)
------------------------------------------------------------------------
INSERT INTO dbo.Produkt (Varenummer, Navn, KategoriId, Merke, Innkjopspris, Salgspris, Aktiv, SistEndret)
SELECT
    'NH-' + RIGHT('00000' + CAST(t.N AS VARCHAR(5)), 5),
    ISNULL(m.Merke, 'Nordhandel') + ' '
        + CHOOSE(1 + r.R2 % 12, 'Lofoten','Falketind','Trollveggen','Rondane','Jotunheim','Senja',
                                'Svalbard','Finse','Hardanger','Dovre','Lyngen','Femund') + ' '
        + CHOOSE(1 + r.R3 % 8, 'Pro','Light','Classic','Expedition','Junior','W','M','Eco'),
    CASE WHEN r.R4 % 100 < 2 THEN NULL                       -- P1
         WHEN r.R4 % 100 < 3 THEN 20                         -- P2
         ELSE 6 + r.R4 % 14 END,                             -- 6..19 (mellom- og bladnivå)
    m.Merke,
    i.Innkjop,
    CASE WHEN r.R6 % 100 < 3
         THEN ROUND(i.Innkjop * 0.80, 0) - 0.10              -- P5: tapsprodukt
         ELSE ROUND(i.Innkjop * (1.4 + (r.R6 % 80) / 100.0), 0) - 0.10 END,
    CASE WHEN r.R7 % 10 = 0 THEN 0 ELSE 1 END,
    DATEADD(day, -(r.R7 % 400), '2025-12-31')
FROM dbo.Tall t
CROSS APPLY (SELECT (CHECKSUM(NEWID()) & 2147483647) AS R1, (CHECKSUM(NEWID()) & 2147483647) AS R2,
                    (CHECKSUM(NEWID()) & 2147483647) AS R3, (CHECKSUM(NEWID()) & 2147483647) AS R4,
                    (CHECKSUM(NEWID()) & 2147483647) AS R5, (CHECKSUM(NEWID()) & 2147483647) AS R6,
                    (CHECKSUM(NEWID()) & 2147483647) AS R7) r
CROSS APPLY (SELECT CASE WHEN r.R1 % 100 < 5 THEN NULL                                    -- P3
                         ELSE CHOOSE(1 + r.R1 % 9, 'Norrøna','Bergans','Fjällräven','Devold',
                                     'Helly Hansen','Hilleberg','Primus','Osprey','Scarpa') END AS Merke) m
CROSS APPLY (SELECT CAST(100 + (r.R5 % 2900) AS DECIMAL(10,2)) AS Innkjop) i
WHERE t.N <= 800;

-- P4: inkonsistent skrivemåte på merke
UPDATE TOP (15) dbo.Produkt SET Merke = UPPER(Merke)   WHERE Merke IS NOT NULL;
-- NB: uten COLLATE er «Merke <> UPPER(Merke)» alltid usant under CI-kollasjon
UPDATE TOP (10) dbo.Produkt SET Merke = Merke + ' '
WHERE Merke IS NOT NULL AND Merke COLLATE Latin1_General_BIN2 <> UPPER(Merke);

------------------------------------------------------------------------
-- 6. Ordrer (215 000, deretter sesongjustering)
--    KundeId er skjevfordelt: produktet av to uniforme tall gir
--    mange små verdier → noen kunder handler mye oftere enn andre.
------------------------------------------------------------------------
DECLARE @AntallKunder INT = (SELECT COUNT(*) FROM dbo.Kunde);

INSERT INTO dbo.Ordre (KundeId, Ordredato, Status, Betalingsmate, Kanal, Fraktkostnad, SistEndret)
SELECT
    k.KundeId,
    d.Ordredato,
    CASE WHEN r.R3 % 100 < 80 THEN 'Levert'
         WHEN r.R3 % 100 < 85 THEN 'Sendt'
         WHEN r.R3 % 100 < 88 THEN 'Betalt'
         WHEN r.R3 % 100 < 90 THEN 'Ny'
         WHEN r.R3 % 100 < 95 THEN 'Kansellert'
         ELSE 'Returnert' END,
    CASE WHEN r.R4 % 100 < 55 THEN 'Kort'
         WHEN r.R4 % 100 < 90 THEN 'Vipps'
         WHEN r.R4 % 100 < 98 THEN 'Faktura'
         ELSE NULL END,                                                  -- O2
    CASE WHEN r.R5 % 100 < 60 THEN 'Web'
         WHEN r.R5 % 100 < 90 THEN 'App'
         ELSE 'Butikk' END,
    CHOOSE(1 + r.R6 % 4, 0.00, 49.00, 99.00, 149.00),
    DATEADD(day, r.R7 % 10, d.Ordredato)
FROM dbo.Tall t
CROSS APPLY (SELECT (CHECKSUM(NEWID()) & 2147483647) AS R1, (CHECKSUM(NEWID()) & 2147483647) AS R2,
                    (CHECKSUM(NEWID()) & 2147483647) AS R3, (CHECKSUM(NEWID()) & 2147483647) AS R4,
                    (CHECKSUM(NEWID()) & 2147483647) AS R5, (CHECKSUM(NEWID()) & 2147483647) AS R6,
                    (CHECKSUM(NEWID()) & 2147483647) AS R7, (CHECKSUM(NEWID()) & 2147483647) AS R8) r
CROSS APPLY (SELECT 1 + ((r.R1 % @AntallKunder) * (r.R2 % @AntallKunder)) / @AntallKunder AS KundeId) k
CROSS APPLY (SELECT DATEADD(minute, r.R8 % 1578240, '2023-01-01') AS Ordredato) d   -- 1096 dager (2024 er skuddår!)
WHERE t.N <= 215000;

-- Sesong: færre ordrer i januar–mars
DELETE FROM dbo.Ordre
WHERE MONTH(Ordredato) IN (1, 2, 3)
  AND (CHECKSUM(NEWID(), OrdreId) & 2147483647) % 100 < 40;   -- OrdreId tvinger evaluering per rad

-- O1: ordredato i fremtiden
UPDATE TOP (150) dbo.Ordre
SET Ordredato = DATEADD(year, 5, Ordredato)
WHERE Status = 'Ny';

------------------------------------------------------------------------
-- 7. Ordrelinjer (1–5 per ordre, snitt 3)
--    Enhetspris = dagens salgspris skalert ned for eldre ordrer
--    (80 % i jan 2023 → 100 % i des 2025) ± 3 % støy.
--    Dette simulerer prisendringer som kilden IKKE har historikk for.
------------------------------------------------------------------------
INSERT INTO dbo.Ordrelinje (OrdreId, ProduktId, Antall, EnhetsprisEksMva, RabattProsent)
SELECT
    o.OrdreId,
    pr.ProduktId,
    CASE WHEN r.R2 % 1000 < 2 THEN 0                                     -- L1
         WHEN r.R2 % 100 < 60 THEN 1
         WHEN r.R2 % 100 < 85 THEN 2
         ELSE 3 + r.R2 % 3 END,
    ROUND(pr.Salgspris
          * (0.80 + 0.20 * DATEDIFF(day, '2023-01-01', o.Ordredato) / 1096.0)
          * (0.97 + (r.R3 % 7) / 100.0), 2),
    CASE WHEN r.R4 % 100 < 85 THEN 0
         WHEN r.R4 % 100 < 93 THEN 10
         WHEN r.R4 % 100 < 98 THEN 20
         ELSE 50 END
FROM dbo.Ordre o
CROSS APPLY (SELECT 1 + (CHECKSUM(NEWID()) & 2147483647) % 5 AS AntallLinjer) a
JOIN (VALUES (1), (2), (3), (4), (5)) AS t(N) ON t.N <= a.AntallLinjer   -- IKKE dbo.Tall: 1M rader × 195k ordrer blir for dyrt
CROSS APPLY (SELECT (CHECKSUM(NEWID()) & 2147483647) AS R1, (CHECKSUM(NEWID()) & 2147483647) AS R2,
                    (CHECKSUM(NEWID()) & 2147483647) AS R3, (CHECKSUM(NEWID()) & 2147483647) AS R4,
                    (CHECKSUM(NEWID()) & 2147483647) AS R5) r
CROSS APPLY (SELECT 1 + ((r.R1 % 800) * (r.R5 % 800)) / 800 AS ProduktId) p     -- skjevfordelt
JOIN dbo.Produkt pr ON pr.ProduktId = p.ProduktId;

------------------------------------------------------------------------
-- 8. Kontroll
------------------------------------------------------------------------
SELECT 'Postnummer' AS Tabell, COUNT(*) AS Rader FROM dbo.Postnummer UNION ALL
SELECT 'Kunde',       COUNT(*) FROM dbo.Kunde       UNION ALL
SELECT 'Kategori',    COUNT(*) FROM dbo.Kategori    UNION ALL
SELECT 'Produkt',     COUNT(*) FROM dbo.Produkt     UNION ALL
SELECT 'Ordre',       COUNT(*) FROM dbo.Ordre       UNION ALL
SELECT 'Ordrelinje',  COUNT(*) FROM dbo.Ordrelinje;

PRINT 'NordhandelShop: testdata lastet.';


