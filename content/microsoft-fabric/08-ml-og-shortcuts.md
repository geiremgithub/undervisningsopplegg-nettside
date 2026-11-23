---
title: "Maskinlæring og shortcuts"
description: "Tren og bruk en modell med MLflow, og bruk data uten å kopiere dem."
order: 8
---

# Maskinlæring og shortcuts

## 13. Eksempel 9: Maskinlæring med MLflow

**Case:** Kan vi forutsi hvor mye en kunde kommer til å handle for?

Opprett en ny notebook, `nb_ml_prediksjon`, koblet til `lh_nordlys`.

### Celle 1: Klargjør data

```python
import pandas as pd

df = spark.sql("""
    SELECT f.antall, f.pris, p.kategori, k.by, f.belop
    FROM gull_fakta_salg f
    JOIN gull_dim_produkt p ON f.produkt_id = p.produkt_id
    JOIN gull_dim_kunde   k ON f.kunde_id   = k.kunde_id
""").toPandas()

df["pris"] = df["pris"].astype(float)
df["belop"] = df["belop"].astype(float)
X = pd.get_dummies(df[["antall", "pris", "kategori", "by"]])
y = df["belop"]
```

### Celle 2: Tren og logg med MLflow

```python
import mlflow
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import train_test_split

mlflow.set_experiment("nordlys-belop-prediksjon")

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

with mlflow.start_run(run_name="lineær-regresjon"):
    modell = LinearRegression()
    modell.fit(X_train, y_train)

    mae = mean_absolute_error(y_test, modell.predict(X_test))
    mlflow.log_metric("mae", mae)
    mlflow.sklearn.log_model(modell, "modell", registered_model_name="nordlys-belop")

    print(f"Gjennomsnittlig feil (MAE): {mae:.2f} kr")
```

> ⚠️ Datasettet vårt er altfor lite for ekte maskinlæring. Poenget er å lære **arbeidsflyten**: eksperiment → kjøring → metrikk → registrert modell.

### Celle 3: Bruk modellen (batch-scoring)

```python
from synapse.ml.predict import MLFlowTransformer

scorer = MLFlowTransformer(
    inputCols=list(X.columns),
    outputCol="predikert_belop",
    modelName="nordlys-belop",
    modelVersion=1,
)

prediksjoner = scorer.transform(spark.createDataFrame(X_test))
prediksjoner.write.mode("overwrite").format("delta").saveAsTable("gull_prediksjoner")
```

I workspacet ser du nå elementene **Experiment** og **ML model**, der du kan sammenligne kjøringer.

---

## 14. Eksempel 10: Shortcuts, eller data uten kopiering

En **shortcut** er en peker til data som ligger et annet sted. Dataene leses direkte fra kilden uten å kopieres.

```text
lh_nordlys
├── Tables
│   ├── gull_fakta_salg
│   └── 🔗 lager_beholdning   ──▶ Annet lakehouse i et annet workspace
└── Files
    └── 🔗 leverandorfiler    ──▶ Azure Data Lake Storage Gen2 / Amazon S3 / Google Cloud Storage
```

### Steg for steg

1. Høyreklikk **Tables** eller **Files** i lakehouset og velg **New shortcut**.
2. Velg kilde: **OneLake**, **Azure Data Lake Storage Gen2**, **Amazon S3**, **Google Cloud Storage**, **Dataverse** og flere.
3. Velg tilkobling og mappe, og gi shortcuten et navn.

```python
# Shortcuts brukes akkurat som vanlige tabeller
spark.table("lager_beholdning").show()
```

**Når passer shortcuts?**

- Data eies av et annet team, og du vil ikke ha en kopi som blir utdatert.
- Data ligger i en annen sky (S3, GCS).
- Du vil unngå å betale for lagring to ganger.

> Relatert: **Mirroring** speiler hele databaser (for eksempel Azure SQL, Snowflake eller Cosmos DB) inn i OneLake nesten i sanntid.
