---
title: "Egen app med CAP (bonus)"
description: "Lag en egen tjeneste med datamodell og OData-API på SAP BTP."
order: 8
---

# Egen app med CAP (bonus)

## 18. Eksempel 13: Egen app med CAP (bonus for utviklere)

**SAP Cloud Application Programming Model (CAP)** er SAPs rammeverk for å lage egne tjenester og apper på BTP med Node.js eller Java.

### 18.1 Utviklingsmiljø

Bruk **SAP Business Application Studio**, som er nettleserbasert og abonneres på i BTP. Alternativt kan du bruke **VS Code** lokalt med Node.js:

```bash
npm install -g @sap/cds-dk
cds init nordlys-app
cd nordlys-app
npm install
```

### 18.2 Datamodell i CDS

📄 `db/schema.cds`

```cds
namespace nordlys;

entity Produkter {
  key ID          : Integer;
      produktnavn : String(100);
      kategori    : String(50);
      pris        : Decimal(10, 2);
}

entity Salg {
  key ID        : UUID;
      dato      : Date;
      region    : String(20);
      byNavn    : String(50);
      produkt   : Association to Produkter;
      antall    : Integer;
      omsetning : Decimal(15, 2);
      kostnad   : Decimal(15, 2);
}
```

### 18.3 Tjeneste

📄 `srv/salg-service.cds`

```cds
using nordlys from '../db/schema';

service SalgService {
  @readonly entity Produkter as projection on nordlys.Produkter;
  entity Salg as projection on nordlys.Salg;
}
```

### 18.4 Testdata

📄 `db/data/nordlys-Produkter.csv`

```csv
ID;produktnavn;kategori;pris
101;Langrennski Pro;Ski;4999
102;Skistaver Karbon;Ski;1299
103;Løpesko Fjell;Løping;1899
```

### 18.5 Kjør lokalt

```bash
cds watch
```

Åpne <http://localhost:4004>. Du har nå et **OData V4-API**:

```text
GET http://localhost:4004/odata/v4/salg/Produkter
GET http://localhost:4004/odata/v4/salg/Produkter?$filter=kategori eq 'Ski'
GET http://localhost:4004/odata/v4/salg/Produkter?$orderby=pris desc&$top=2
```

### 18.6 Egen logikk

📄 `srv/salg-service.js`

```javascript
const cds = require('@sap/cds');

module.exports = class SalgService extends cds.ApplicationService {
  init() {
    // Valider før lagring: antall må være positivt
    this.before('CREATE', 'Salg', (req) => {
      if (req.data.antall <= 0) req.error(400, 'Antall må være større enn 0');
    });
    return super.init();
  }
};
```

> 💡 Neste steg er å legge til HANA Cloud (`cds add hana`) og deployere til Cloud Foundry (`cds add mta` og deretter `mbt build` og `cf deploy`). Det er et eget kurs i seg selv.
