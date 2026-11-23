---
title: "Power BI med Direct Lake"
description: "Semantisk modell, stjerneskjema, DAX-mål og en ferdig rapport."
order: 6
---

# Power BI med Direct Lake

## 11. Eksempel 7: Power BI med Direct Lake og DAX

### 11.1 Hva er Direct Lake?

| Modus | Hvordan | Fordel | Ulempe |
|---|---|---|---|
| **Import** | Data kopieres inn i Power BI | Rask | Må oppdateres, og dataene dupliseres |
| **DirectQuery** | Spør kilden ved hver visning | Alltid ferske data | Tregere |
| **Direct Lake** ⭐ | Leser Delta-filene i OneLake direkte | Rask *og* fersk, uten kopiering | Krever Fabric |

### 11.2 Lag en semantisk modell

1. I `lh_nordlys` klikker du **New semantic model**.
2. Navn: `sm_nordlys`. Velg tabellene `gull_fakta_salg`, `gull_dim_kunde` og `gull_dim_produkt`.
3. Åpne modellen og dra relasjoner i modellvisningen:
   - `gull_fakta_salg[kunde_id]` → `gull_dim_kunde[kunde_id]` (mange til én)
   - `gull_fakta_salg[produkt_id]` → `gull_dim_produkt[produkt_id]` (mange til én)

```text
                ┌────────────────┐
                │ gull_dim_kunde │
                └───────┬────────┘
                        │ 1
                        │
                        │ *
┌──────────────────┐  * ┌─────────────────┐
│ gull_dim_produkt │────│ gull_fakta_salg │
└──────────────────┘ 1  └─────────────────┘
          Stjerneskjema
```

### 11.3 DAX-mål

Lag disse målene i faktatabellen med **New measure**:

```dax
Total omsetning = SUM ( gull_fakta_salg[belop] )

Antall ordre = DISTINCTCOUNT ( gull_fakta_salg[ordre_id] )

Snitt per ordre = DIVIDE ( [Total omsetning], [Antall ordre] )

Andel av total =
DIVIDE (
    [Total omsetning],
    CALCULATE ( [Total omsetning], ALL ( gull_dim_produkt ) )
)

Omsetning Ski =
CALCULATE ( [Total omsetning], gull_dim_produkt[kategori] = "Ski" )
```

### 11.4 Bygg rapporten

1. Klikk **New report** fra den semantiske modellen.
2. Legg til:
   - **Kort (Card):** `Total omsetning`, `Antall ordre` og `Snitt per ordre`
   - **Søylediagram:** `kategori` på aksen og `Total omsetning` som verdi
   - **Linjediagram:** `ordredato` og `Total omsetning`
   - **Tabell:** `navn`, `by`, `Total omsetning`
   - **Slicer:** `by`
3. Lagre rapporten som `Salgsoversikt Nordlys`.
