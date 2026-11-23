---
name: sjekk-innhold
description: Kjører en automatisk kontroll av innholdet i kursportalen (emne.json, frontmatter, rekkefølge, filnavn, alt-tekst på bilder og forsiden). Bruk før publisering, etter at innhold er lagt til, eller når noen spør om innholdet er riktig satt opp.
---

# Sjekk innhold

1. Kjør skriptet fra roten av prosjektet. Ikke gjør kontrollene for hånd:

   ```bash
   node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs
   ```

   Vil du bare sjekke ett emne, legger du til mappenavnet:

   ```bash
   node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs power-bi
   ```

2. Les resultatet:
   - `FEIL` må rettes før publisering. Skriptet avslutter da med kode 1.
   - `ADVARSEL` bør rettes, men stopper ikke publiseringen.
3. Vis resultatet som en tabell med kolonnene fil, type og melding, og foreslå en konkret retting for hver linje.
4. Kjør til slutt `npm run build` for å bekrefte at portalen kan bygges.

Krever at `npm install` er kjørt.
