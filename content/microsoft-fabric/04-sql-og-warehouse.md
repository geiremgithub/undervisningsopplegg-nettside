---
title: "SQL endpoint og warehouse"
description: "Spør lakehouse-tabeller med SQL og bygg et datavarehus med T-SQL."
order: 4
---

# SQL endpoint og warehouse

## 7. Eksempel 3: SQL Analytics Endpoint

Hvert lakehouse får automatisk et **SQL analytics endpoint**. Det lar deg spørre Delta-tabellene med vanlig T-SQL, men **bare lese**.

1. Åpne `lh_nordlys` og bytt fra **Lakehouse** til **SQL analytics endpoint** øverst til høyre.
2. Klikk **New SQL query**.

```sql
-- Topp 3 kunder etter omsetning
SELECT TOP 3
       k.navn,
       k.by,
       SUM(f.belop) AS omsetning
FROM gull_fakta_salg AS f
JOIN gull_dim_kunde  AS k ON f.kunde_id = k.kunde_id
GROUP BY k.navn, k.by
ORDER BY omsetning DESC;
```

```sql
-- Lag et view som Power BI eller andre kan bruke
CREATE VIEW v_salg_per_dag AS
SELECT ordredato,
       COUNT(DISTINCT ordre_id) AS antall_ordre,
       SUM(belop)               AS omsetning
FROM gull_fakta_salg
GROUP BY ordredato;
```

> 💡 Du kan også koble til endpointet fra **SSMS**, **Azure Data Studio** eller **VS Code**. Kopier tilkoblingsstrengen fra innstillingene.

---

## 8. Eksempel 4: Data Warehouse med T-SQL

Et **warehouse** passer når du vil jobbe *bare* med SQL og trenger full T-SQL med `INSERT`, `UPDATE`, `DELETE` og transaksjoner.

1. Velg **+ New item → Warehouse** og kall det `wh_nordlys`.
2. Åpne en ny SQL-spørring.

### Opprett tabeller

```sql
CREATE TABLE dbo.dim_dato
(
    dato        DATE        NOT NULL,
    aar         INT         NOT NULL,
    maaned      INT         NOT NULL,
    maanedsnavn VARCHAR(20) NOT NULL,
    ukedag      VARCHAR(20) NOT NULL
);
```

### Fyll datodimensjonen

```sql
DECLARE @dato DATE = '2024-01-01';
WHILE @dato <= '2024-12-31'
BEGIN
    INSERT INTO dbo.dim_dato (dato, aar, maaned, maanedsnavn, ukedag)
    VALUES (@dato, YEAR(@dato), MONTH(@dato), DATENAME(month, @dato), DATENAME(weekday, @dato));
    SET @dato = DATEADD(day, 1, @dato);
END;
```

### Hent data fra lakehouse på tvers av elementer

Et warehouse kan lese direkte fra lakehouse-tabeller i samme workspace med **tredelte navn**:

```sql
CREATE TABLE dbo.fakta_salg AS
SELECT ordre_id, kunde_id, produkt_id, ordredato, antall, belop
FROM lh_nordlys.dbo.gull_fakta_salg;
```

### Lagret prosedyre

```sql
CREATE PROCEDURE dbo.sp_omsetning_per_maaned @aar INT
AS
BEGIN
    SELECT d.maaned, d.maanedsnavn, SUM(f.belop) AS omsetning
    FROM dbo.fakta_salg f
    JOIN dbo.dim_dato  d ON f.ordredato = d.dato
    WHERE d.aar = @aar
    GROUP BY d.maaned, d.maanedsnavn
    ORDER BY d.maaned;
END;
GO

EXEC dbo.sp_omsetning_per_maaned @aar = 2024;
```

### Lakehouse eller warehouse?

| | Lakehouse | Warehouse |
|---|---|---|
| Primærspråk | PySpark, Spark SQL | T-SQL |
| Skrive med SQL | ❌ (SQL endpoint er skrivebeskyttet) | ✅ |
| Ustrukturerte filer (bilder, JSON …) | ✅ | ❌ |
| Transaksjoner over flere tabeller | Begrenset | ✅ |
| Typisk bruker | Dataingeniør, data scientist | SQL-utvikler, BI-utvikler |
