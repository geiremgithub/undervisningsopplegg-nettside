---
title: "Vanlige feil, øvingsoppgaver og ordliste"
description: "Typiske feil, sju øvingsoppgaver med økende vanskelighet og en ordliste."
order: 10
---

# Vanlige feil, øvingsoppgaver og ordliste

## 21. Vanlige feil og gode råd

### ❌ Vanlige feil

| Feil | Symptom | Løsning |
|---|---|---|
| Tall importert som dimensjon i SAC | Kan ikke summere | Endre kolonnetypen til **Measure** i modelleren |
| Feil datoformat ved import | Datoene blir tomme | Angi riktig format, for eksempel `yyyy-MM-dd` |
| Glemt **Publish Data** i planlegging | Andre ser ikke endringene dine | Publiser den private kopien |
| Data action skriver til feil versjon | Budsjettet blir overskrevet | Avgrens alltid med `MEMBERSET` |
| Glemt **Deploy** i Datasphere | Objektet finnes ikke for SAC eller andre views | Deploy etter hver lagring |
| Feil *Semantic Usage* | Analytic model finner ingen mål | Sett view-et til **Fact** og marker måltallene |
| Nye kolonner i Python-script ikke lagt til output | Dataflyten feiler | Legg til kolonnene i Script-operatorens output |
| HANA-instans stoppet | Tilkoblingen feiler | Start instansen i HANA Cloud Central (prøveinstanser stopper hver natt) |
| Manglende entitlement i BTP | Tjenesten vises ikke i Marketplace | Tildel entitlement til subaccounten |
| Feil region i BTP | Tjenesten er ikke tilgjengelig | Ikke alle tjenester finnes i alle regioner. Sjekk *SAP Discovery Center*. |

### ✅ Gode råd

1. **Navnekonvensjon:** for eksempel `MDL_`, `STR_`, `DA_` (SAC), `T_`, `V_`, `AM_`, `DF_` (Datasphere).
2. **Modeller i Datasphere og visualiser i SAC.** Ha forretningslogikken ett sted.
3. **Bruk live-tilkobling for rapportering og import for planlegging.**
4. **Én space per domene** i Datasphere, for eksempel Salg, Finans og HR.
5. **Test data actions på private versjoner** før du kjører dem på publiserte versjoner.
6. **Dokumenter beregnede mål** med beskrivelsesfeltet. Neste person takker deg.
7. **Separate miljøer:** Dev, Test og Prod, både i BTP (subaccounts) og SAC/Datasphere. Bruk **Content Network** eller **Transport** i SAC for å flytte innhold.

---

## 22. Øvingsoppgaver

### Oppgave 1: Første modell og story (30 min) 🟢
1. Importer `salg.csv` i SAC og lag modellen `MDL_<navn>_SALG`.
2. Lag en story med 2 KPI-er, 1 søylediagram og 1 tabell.
3. Legg til et input control (filter) på `Region`.

**Kontroll:** Total omsetning skal være 419 760.

### Oppgave 2: Beregninger (30 min) 🟢
Lag disse beregningene i storyen:
- `Dekningsbidrag` og `DB-grad %`
- Restricted measure: `Omsetning Løping`
- Et diagram som viser DB-grad per kategori

**Spørsmål:** Hvilken kategori har høyest DB-grad? Hvorfor kan det være slik?

### Oppgave 3: Budsjett (60 min) 🟡
1. Lag planleggingsmodellen `MDL_<navn>_PLAN`.
2. Importer `budsjett.csv` som *Budget*.
3. Lag en tabell der du kan skrive inn budsjett for august–desember.
4. Øk budsjettet for Øst med 10 % ved å skrive inn på regionnivå (spread).
5. Lag en variansanalyse mellom *Actual* og *Budget*.
6. Publiser.

### Oppgave 4: Data action (45 min) 🟡
Lag en data action som:
1. Kopierer *Actual* januar–juni 2024 til *Forecast*.
2. Bruker advanced formulas til å sette Forecast for juli–desember lik gjennomsnittet av januar–juni × 1,03.
3. Kjøres med en knapp i storyen.

### Oppgave 5: HANA Cloud SQL (45 min) 🟡
1. Opprett skjemaet `NORDLYS_<navn>` og tabellene `PRODUKT` og `SALG`.
2. Importer dataene.
3. Skriv spørringer som viser:
   - omsetning per region og måned
   - topp 3 produkter etter dekningsbidrag
   - andelen hver kategori utgjør av total omsetning (hint: `SUM(...) OVER ()`)

### Oppgave 6: Datasphere til SAC (60 min) 🔴
1. Lag en space og importer `salg.csv` som lokal tabell.
2. Lag et graphical view (Fact) med `Dekningsbidrag` og `Aar`.
3. Lag dimensjonen `V_PRODUKT_DIM` og en assosiasjon.
4. Lag en analytic model med minst ett calculated measure og ett restricted measure.
5. Koble SAC live og lag en story.

### Oppgave 7: Sluttprosjekt i gruppe (4–6 timer) 🔴
Velg et åpent datasett, for eksempel fra **SSB** (statistikkbanken), **data.norge.no** eller **Kaggle**, og bygg en løsning:

| Krav | ✔ |
|---|---|
| Data lastet inn i Datasphere eller HANA Cloud | ☐ |
| Minst ett view med transformasjon (SQL, grafisk eller Python) | ☐ |
| Analytic model eller SAC-modell med minst 3 beregnede mål | ☐ |
| SAC-story med minst 2 sider, filter og linked analysis | ☐ |
| Planleggingsdel: budsjett/prognose + én data action | ☐ |
| Bonus: Smart Predict-prognose eller skripting | ☐ |
| Bonus: radnivåsikkerhet (DAC) | ☐ |

**Presentasjon på 10 min:** arkitekturskisse, demo, og hva dere ville gjort annerledes i en ekte bedrift.

---

## 23. Ordliste og videre lesning

### Ordliste

| Begrep | Forklaring |
|---|---|
| **Account-dimensjon** | Dimensjon for kontoer i planleggingsmodeller, med egne regler for summering |
| **Analytic Model** | Forretningsklar modell i Datasphere med mål og dimensjoner for SAC |
| **BTP** | SAP Business Technology Platform, SAPs skyplattform |
| **CAP** | Cloud Application Programming Model, rammeverk for apper på BTP |
| **CDS** | Core Data Services, SAPs språk for datamodeller |
| **Cloud Foundry** | Kjøremiljø for apper på BTP |
| **Data Action** | Automatisert beregning i SAC Planning |
| **DAC** | Data Access Control, radnivåsikkerhet i Datasphere |
| **Entitlement** | Retten og kvoten til å bruke en BTP-tjeneste |
| **Federation** | Data leses direkte fra kilden uten kopiering |
| **HANA** | SAPs in-memory, kolonnebaserte database |
| **Joule** | SAPs AI-assistent |
| **Live connection** | SAC spør kilden direkte |
| **MAPE** | Mean Absolute Percentage Error, prosentvis feilmål for prognoser |
| **OData** | Standard for REST-API-er som SAP bruker mye |
| **Replication** | Data kopieres fra kilde til mål |
| **S/4HANA** | SAPs ERP-system |
| **Space** | Avgrenset arbeidsområde i Datasphere |
| **Story** | Rapport eller dashbord i SAC |
| **Subaccount** | Miljø i BTP knyttet til en region |
| **Version** | Utgave av data i planlegging: Actual, Budget, Forecast |

### Videre lesning

- SAP Learning (gratis kurs og læringsstier): <https://learning.sap.com>
- SAP Help Portal, SAP Analytics Cloud: <https://help.sap.com/docs/SAP_ANALYTICS_CLOUD>
- SAP Help Portal, SAP Datasphere: <https://help.sap.com/docs/SAP_DATASPHERE>
- SAP Help Portal, SAP HANA Cloud: <https://help.sap.com/docs/HANA_CLOUD>
- SAP Discovery Center (BTP-tjenester, regioner og oppdrag): <https://discovery-center.cloud.sap>
- CAP-dokumentasjon: <https://cap.cloud.sap>
- SAP Community (spørsmål og svar, blogger): <https://community.sap.com>
- SAP Developer Tutorials: <https://developers.sap.com/tutorial-navigator.html>
- Sertifiseringer: *SAP Certified Associate – Data Analyst – SAP Analytics Cloud*, *SAP Certified Associate – Planning – SAP Analytics Cloud* og *SAP Certified Associate – Data Engineer – SAP Datasphere*

---

> **Lærernotat:** Del A (SAC, eksempel 1–4 og oppgave 1–2) passer for første undervisningsdag og krever bare en SAC-tilgang. Planlegging (eksempel 5–6, oppgave 3–4) er en naturlig dag to for økonomistudenter. Del B (BTP, HANA og Datasphere) passer for IT- og datastudenter. SAP endrer grensesnitt og produktnavn ofte, for eksempel Just Ask → Joule og Analytics Designer → Optimized Story Experience. Sjekk derfor menynavn og hvilke funksjoner prøvekontoene har før timen.
