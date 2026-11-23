---
title: "Sanntidsdata med KQL"
description: "Eventstream, Eventhouse og spørringer i Kusto Query Language."
order: 7
---

# Sanntidsdata med KQL

## 12. Eksempel 8: Sanntidsdata med Eventstream og KQL

**Real-Time Intelligence** brukes til data som strømmer inn kontinuerlig, for eksempel IoT-sensorer, klikk på nettsiden eller logger.

**Case:** Nordlys Sport vil se hvilke produkter kundene klikker på *akkurat nå*.

### 12.1 Opprett Eventhouse og Eventstream

1. Velg **+ New item → Eventhouse** og kall det `eh_nordlys`. En KQL-database opprettes automatisk.
2. Velg **+ New item → Eventstream** og kall den `es_klikk`.
3. Velg **Use sample data** som kilde for å teste (for eksempel *Bicycles* eller *Stock market*). Du kan også koble til **Azure Event Hubs** eller et **custom endpoint**.
4. Legg til destinasjonen **Eventhouse** → `eh_nordlys` og tabellen `klikk`.
5. Publiser.

### 12.2 Spør med KQL (Kusto Query Language)

KQL leses ovenfra og ned. Hver `|` sender resultatet videre til neste steg, omtrent som et samlebånd.

```kql
// De siste 10 hendelsene
klikk
| take 10
```

```kql
// Antall klikk per produkt siste time
klikk
| where Timestamp > ago(1h)
| summarize antall_klikk = count() by produkt
| order by antall_klikk desc
```

```kql
// Tidsserie per 5. minutt, vist som graf
klikk
| where Timestamp > ago(24h)
| summarize antall = count() by bin(Timestamp, 5m)
| render timechart
```

```kql
// Finn uvanlige topper (anomalideteksjon)
klikk
| make-series antall = count() on Timestamp from ago(7d) to now() step 1h
| extend anomalier = series_decompose_anomalies(antall)
| render anomalychart with (anomalycolumns = anomalier)
```

### 12.3 SQL og KQL side om side

| SQL | KQL |
|---|---|
| `SELECT TOP 10 * FROM t` | `t \| take 10` |
| `WHERE x > 5` | `\| where x > 5` |
| `GROUP BY a` + `COUNT(*)` | `\| summarize count() by a` |
| `ORDER BY a DESC` | `\| order by a desc` |

### 12.4 Varsling med Activator

Med **Activator** (tidligere *Data Activator*) kan du for eksempel sende en Teams-melding når antall klikk per minutt går under en grense, noe som kan tyde på at nettsiden er nede.
