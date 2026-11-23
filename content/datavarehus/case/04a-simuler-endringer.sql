/* =====================================================================
   Nordhandel AS – simuler endringer i kilden (for samling 4)
   Fil: case/04a-simuler-endringer.sql
   Forutsetter full last (EXEC etl.KjorAlt @FullLast = 1).

   Uten endringer i kilden har ingen dimensjoner mer enn én versjon,
   og rapport 4 («kunder som har flyttet») blir tom. Dette skriptet:
     1. flytter de 25 mest aktive kundene til nytt fylke og kjører ETL
        → ny SCD2-versjon med GyldigFra = i dag
     2. legger inn 2 nye ordrer i dag for hver av dem og kjører ETL
        → fakta som peker på den nye versjonen
     3. setter ny pris på de 10 mest solgte produktene og kjører ETL
   Kjøretid: ~5 sekunder.
   ===================================================================== */
USE NordhandelDW;
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

-- 1. Flytt 25 aktive kunder
DROP TABLE IF EXISTS #Flytt;
SELECT TOP (25) o.KundeId,
       NyttPostnummer = CHOOSE(1 + ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) % 6, '9008', '5003', '7010', '0150', '4006', '8006')
INTO #Flytt
FROM NordhandelShop.dbo.Ordre o
JOIN NordhandelShop.dbo.Kunde k ON k.KundeId = o.KundeId
WHERE k.Postnummer NOT IN ('9008', '5003', '7010', '0150', '4006', '8006') AND o.Ordredato < '2026-01-01'
GROUP BY o.KundeId
ORDER BY COUNT(*) DESC;

UPDATE k
SET    Postnummer = f.NyttPostnummer,
       Poststed   = p.Poststed,
       SistEndret = SYSDATETIME()
FROM   NordhandelShop.dbo.Kunde k
JOIN   #Flytt f ON f.KundeId = k.KundeId
JOIN   NordhandelShop.dbo.Postnummer p ON p.Postnummer = f.NyttPostnummer;

EXEC etl.KjorAlt;

-- 2. To nye ordrer i dag per flyttet kunde
INSERT INTO NordhandelShop.dbo.Ordre (KundeId, Ordredato, Status, Betalingsmate, Kanal, Fraktkostnad, SistEndret)
SELECT f.KundeId, SYSDATETIME(), 'Levert', 'Vipps', 'App', 99, SYSDATETIME()
FROM #Flytt f CROSS JOIN (VALUES (1), (2)) n(x);

INSERT INTO NordhandelShop.dbo.Ordrelinje (OrdreId, ProduktId, Antall, EnhetsprisEksMva, RabattProsent)
SELECT o.OrdreId, p.ProduktId, 1, p.Salgspris, 0
FROM   NordhandelShop.dbo.Ordre o
CROSS APPLY (SELECT TOP (2) ProduktId, Salgspris FROM NordhandelShop.dbo.Produkt
             WHERE Aktiv = 1 ORDER BY CHECKSUM(NEWID(), o.OrdreId)) p
WHERE  o.Ordredato >= CAST(SYSDATETIME() AS DATE)
  AND  o.KundeId IN (SELECT KundeId FROM #Flytt);

-- 3. Ny pris på de 10 mest solgte produktene
UPDATE p
SET    Salgspris = ROUND(Salgspris * 1.08, 0) - 0.10, SistEndret = SYSDATETIME()
FROM   NordhandelShop.dbo.Produkt p
WHERE  p.ProduktId IN (SELECT TOP (10) ProduktId FROM NordhandelShop.dbo.Ordrelinje GROUP BY ProduktId ORDER BY COUNT(*) DESC);

EXEC etl.KjorAlt;

SELECT 'Kunder med >1 versjon' AS Hva, COUNT(*) AS Antall FROM (SELECT KundeId FROM dw.DimKunde GROUP BY KundeId HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'Produkter med >1 versjon', COUNT(*) FROM (SELECT ProduktId FROM dw.DimProdukt GROUP BY ProduktId HAVING COUNT(*) > 1) y
UNION ALL
SELECT 'Faktarader i dag', COUNT(*) FROM dw.FaktSalg WHERE OrdreDatoKey = CONVERT(INT, CONVERT(CHAR(8), SYSDATETIME(), 112));
