---
title: "Pipelines og Dataflow Gen2"
description: "Automatiser dataflyten og transformer data uten kode med Power Query."
order: 5
---

# Pipelines og Dataflow Gen2

## 9. Eksempel 5: Datapipeline (Data Factory)

En **pipeline** automatiserer arbeidet: den henter data, kjører notebooken og gir beskjed når noe feiler.

### Mål: daglig automatisk last

```text
┌──────────────┐    ┌──────────────────┐    ┌───────────────┐
│ Copy data    │───▶│ Notebook         │───▶│ Teams/Outlook │
│ (hent CSV    │ OK │ nb_nordlys_      │ OK │ "Last fullført"│
│  fra kilde)  │    │ transform        │    └───────────────┘
└──────────────┘    └──────────────────┘
        │ feil              │ feil
        └────────┬──────────┘
                 ▼
        ┌──────────────────┐
        │ Varsel om feil   │
        └──────────────────┘
```

### Steg for steg

1. Velg **+ New item → Data pipeline** og kall den `pl_daglig_last`.
2. Legg til aktiviteten **Copy data**:
   - **Source:** for eksempel en HTTP-kilde, Azure Blob Storage eller SharePoint-mappen der CSV-filene ligger.
   - **Destination:** `lh_nordlys` → **Files** → `bronse/`.
3. Legg til aktiviteten **Notebook**:
   - Velg `nb_nordlys_transform`.
   - Dra en **On success**-pil (grønn) fra *Copy data* til *Notebook*.
4. Legg til en varslingsaktivitet (**Office 365 Outlook** eller **Teams**) på **On failure**-pilen (rød).
5. Klikk **Run** for å teste.
6. Klikk **Schedule** og velg for eksempel **Daily** kl. 06:00.

### Parametere gjør pipelinen gjenbrukbar

I pipeline-innstillingene legger du til parameteren `filnavn` (string). I Copy-aktiviteten bruker du dette uttrykket i filstien:

```text
@concat('bronse/', pipeline().parameters.filnavn)
```

Notebooken kan også ta imot parametere. Merk en celle som **parameter cell**:

```python
# Parameter-celle: verdien overskrives av pipelinen
kjoredato = "2024-11-01"
```

---

## 10. Eksempel 6: Dataflow Gen2 (Power Query uten kode)

**Dataflow Gen2** passer for deg som kan Excel eller Power BI. Du bruker det samme Power Query-grensesnittet.

### Steg for steg

1. Velg **+ New item → Dataflow Gen2**.
2. Velg **Get data → Text/CSV** og pek på `kunder.csv`.
3. Gjør transformasjonene i grensesnittet:
   - Høyreklikk `kunde_id` og velg **Remove duplicates**.
   - Velg kolonnen `epost` og velg **Transform → Format → lowercase**.
   - Velg kolonnen `by` og velg **Transform → Format → Capitalize Each Word**.
   - Endre datatypen til `registrert` til **Date**.
4. Klikk **+** ved **Data destination** nede til høyre, velg **Lakehouse** → `lh_nordlys` og gi tabellen navnet `df_kunder`.
5. Klikk **Publish**.

### Bak kulissene: M-koden

Gå til **View → Advanced editor**. Der ser du at grensesnittet har generert M-kode:

```m
let
    Kilde       = Csv.Document(File.Contents("kunder.csv"), [Delimiter = ",", Encoding = 65001]),
    Overskrift  = Table.PromoteHeaders(Kilde, [PromoteAllScalars = true]),
    Typer       = Table.TransformColumnTypes(Overskrift, {
                    {"kunde_id", Int64.Type}, {"registrert", type date}}),
    UtenDupl    = Table.Distinct(Typer, {"kunde_id"}),
    SmaaBokst   = Table.TransformColumns(UtenDupl, {{"epost", Text.Lower, type text}}),
    StorForbok  = Table.TransformColumns(SmaaBokst, {{"by", Text.Proper, type text}})
in
    StorForbok
```

> 💬 **Diskusjon:** Vi gjorde det samme i eksempel 2 med PySpark. Hva er fordelene og ulempene med hver tilnærming?
