---
title: "Medaljongarkitektur og lakehouse"
description: "Bronse, sølv og gull, og ditt første lakehouse med opplastede data."
order: 2
---

# Medaljongarkitektur og lakehouse

## 4. Medaljongarkitektur: bronse, sølv og gull

Medaljongarkitektur er det vanligste mønsteret for å organisere data i Fabric:

```text
  KILDER                BRONSE               SØLV                  GULL                 BRUK
┌─────────┐        ┌──────────────┐    ┌───────────────┐    ┌─────────────────┐    ┌──────────┐
│ CSV     │───────▶│ Rådata       │───▶│ Renset og     │───▶│ Forretnings-    │───▶│ Power BI │
│ API     │        │ som de kom   │    │ standardisert │    │ klare tabeller  │    │ ML       │
│ Database│        │ (uendret)    │    │ (typer, dubl.)│    │ (aggregert,     │    │ Rapporter│
└─────────┘        └──────────────┘    └───────────────┘    │ stjerneskjema)  │    └──────────┘
                                                            └─────────────────┘
```

| Lag | Innhold | Hvem bruker det? |
|---|---|---|
| 🥉 **Bronse** | Rådata nøyaktig som de ble mottatt, for sporbarhet | Dataingeniører |
| 🥈 **Sølv** | Rensede data: riktige datatyper, uten duplikater og med standardiserte verdier | Dataingeniører og analytikere |
| 🥇 **Gull** | Aggregerte, forretningsklare tabeller (fakta og dimensjoner) | Analytikere og Power BI |

---

## 5. Eksempel 1: Lakehouse og opplasting av data

### 5.1 Lag testdata

Lagre disse tre filene lokalt på maskinen din.

📄 `kunder.csv`

```csv
kunde_id,navn,epost,by,registrert
1,Kari Nordmann,kari@example.no,Oslo,2024-01-15
2,Ola Hansen,ola@example.no,Bergen,2024-02-03
3,Ingrid Berg,INGRID@EXAMPLE.NO,Trondheim,2024-02-20
4,Lars Olsen,lars@example.no,oslo,2024-03-11
5,Sofie Lie,,Stavanger,2024-04-01
3,Ingrid Berg,INGRID@EXAMPLE.NO,Trondheim,2024-02-20
```

📄 `produkter.csv`

```csv
produkt_id,produktnavn,kategori,pris
101,Langrennski Pro,Ski,4999
102,Skistaver Karbon,Ski,1299
103,Løpesko Fjell,Løping,1899
104,Løpejakke Vind,Løping,1499
105,Sykkelhjelm Aero,Sykkel,999
```

📄 `ordre.csv`

```csv
ordre_id,kunde_id,produkt_id,antall,ordredato
1001,1,101,1,2024-11-01
1002,2,103,2,2024-11-01
1003,1,102,1,2024-11-02
1004,3,105,1,2024-11-03
1005,4,104,3,2024-11-03
1006,5,101,1,2024-11-04
1007,2,102,2,2024-11-05
1008,4,103,1,abc
```

> Legg merke til «feilene» i dataene: en duplisert kunde, blandet store og små bokstaver, en manglende e-post og en ugyldig dato. Det er med vilje. Vi rydder opp i dem i sølvlaget.

### 5.2 Opprett lakehouse og last opp filene

1. Klikk **+ New item** i workspacet og velg **Lakehouse**.
2. Navn: `lh_nordlys`. Ingen mellomrom er tillatt.
3. Høyreklikk **Files** i Lakehouse Explorer, velg **New subfolder** og kall mappen `bronse`.
4. Høyreklikk mappen `bronse`, velg **Upload → Upload files** og velg de tre CSV-filene.

### 5.3 Rask vei: fra fil til tabell uten kode

1. Høyreklikk `produkter.csv`.
2. Velg **Load to Tables → New table**.
3. Fabric lager en Delta-tabell som heter `produkter` under **Tables**.

> 📝 **Files** er for løse filer i alle formater. **Tables** er for Delta-tabeller som kan spørres med SQL og brukes i Power BI.
