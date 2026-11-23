---
title: "Notebook med PySpark"
description: "Rens og bearbeid data fra bronse til gull med PySpark, MERGE og tidsreise."
order: 3
---

# Notebook med PySpark

## 6. Eksempel 2: Notebook med PySpark (bronse → sølv → gull)

Opprett en notebook: **+ New item → Notebook**. Gi den navnet `nb_nordlys_transform` og koble den til `lh_nordlys` via **Add data items** til venstre.

Hver kodeblokk under er én **celle**. Du kjører en celle med `Shift + Enter`.

### Celle 1: Les rådata fra bronse

```python
# Les CSV-filene fra Files/bronse
kunder_raw = spark.read.option("header", True).csv("Files/bronse/kunder.csv")
produkter_raw = spark.read.option("header", True).csv("Files/bronse/produkter.csv")
ordre_raw = spark.read.option("header", True).csv("Files/bronse/ordre.csv")

display(kunder_raw)
```

### Celle 2: Rens kundene (sølv)

```python
from pyspark.sql import functions as F

kunder_solv = (
    kunder_raw
    .dropDuplicates(["kunde_id"])                                  # fjern duplikater
    .withColumn("kunde_id", F.col("kunde_id").cast("int"))
    .withColumn("epost", F.lower(F.trim(F.col("epost"))))           # små bokstaver
    .withColumn("by", F.initcap(F.trim(F.col("by"))))               # "oslo" → "Oslo"
    .withColumn("registrert", F.to_date("registrert", "yyyy-MM-dd"))
    .withColumn("epost", F.when(F.col("epost") == "", None).otherwise(F.col("epost")))
)

kunder_solv.write.mode("overwrite").format("delta").saveAsTable("solv_kunder")
display(kunder_solv)
```

### Celle 3: Rens produkter og ordre (sølv)

```python
produkter_solv = (
    produkter_raw
    .withColumn("produkt_id", F.col("produkt_id").cast("int"))
    .withColumn("pris", F.col("pris").cast("decimal(10,2)"))
)

ordre_solv = (
    ordre_raw
    .withColumn("ordre_id", F.col("ordre_id").cast("int"))
    .withColumn("kunde_id", F.col("kunde_id").cast("int"))
    .withColumn("produkt_id", F.col("produkt_id").cast("int"))
    .withColumn("antall", F.col("antall").cast("int"))
    .withColumn("ordredato", F.to_date("ordredato", "yyyy-MM-dd"))
)

# Skill ut ugyldige rader i stedet for å kaste dem stille
ugyldige = ordre_solv.filter(F.col("ordredato").isNull())
print(f"Ugyldige ordrerader: {ugyldige.count()}")
display(ugyldige)

ordre_solv = ordre_solv.filter(F.col("ordredato").isNotNull())

produkter_solv.write.mode("overwrite").format("delta").saveAsTable("solv_produkter")
ordre_solv.write.mode("overwrite").format("delta").saveAsTable("solv_ordre")
```

### Celle 4: Bygg gulltabeller (stjerneskjema)

```python
# Faktatabell: én rad per ordrelinje, med beregnet beløp
fakta_salg = (
    spark.table("solv_ordre").alias("o")
    .join(spark.table("solv_produkter").alias("p"), "produkt_id")
    .select(
        "o.ordre_id", "o.kunde_id", "o.produkt_id", "o.ordredato", "o.antall",
        "p.pris",
        (F.col("o.antall") * F.col("p.pris")).alias("belop"),
    )
)
fakta_salg.write.mode("overwrite").format("delta").saveAsTable("gull_fakta_salg")

# Dimensjonstabeller
spark.table("solv_kunder").select("kunde_id", "navn", "by") \
    .write.mode("overwrite").format("delta").saveAsTable("gull_dim_kunde")

spark.table("solv_produkter") \
    .write.mode("overwrite").format("delta").saveAsTable("gull_dim_produkt")
```

### Celle 5: Kontroller resultatet med Spark SQL

```sql
%%sql
SELECT p.kategori,
       SUM(f.belop)  AS total_omsetning,
       SUM(f.antall) AS antall_solgt
FROM gull_fakta_salg f
JOIN gull_dim_produkt p ON f.produkt_id = p.produkt_id
GROUP BY p.kategori
ORDER BY total_omsetning DESC
```

**Forventet resultat:**

| kategori | total_omsetning | antall_solgt |
|---|---|---|
| Ski | 13 895 | 5 |
| Løping | 8 295 | 5 |
| Sykkel | 999 | 1 |

### Celle 6 (bonus): Inkrementell last med MERGE

I praksis laster man sjelden alt på nytt hver gang. Med `MERGE` oppdaterer du eksisterende rader og legger til nye:

```python
from delta.tables import DeltaTable

nye_ordre = spark.createDataFrame(
    [(1009, 1, 105, 2, "2024-11-06")],
    ["ordre_id", "kunde_id", "produkt_id", "antall", "ordredato"],
).withColumn("ordredato", F.to_date("ordredato"))

maal = DeltaTable.forName(spark, "solv_ordre")
(
    maal.alias("t")
    .merge(nye_ordre.alias("s"), "t.ordre_id = s.ordre_id")
    .whenMatchedUpdateAll()
    .whenNotMatchedInsertAll()
    .execute()
)
```

### Celle 7 (bonus): Tidsreise i Delta

```sql
%%sql
DESCRIBE HISTORY solv_ordre;

-- Se tabellen slik den var i versjon 0
SELECT * FROM solv_ordre VERSION AS OF 0;
```
