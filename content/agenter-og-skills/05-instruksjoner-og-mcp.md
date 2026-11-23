---
title: "Instruksjoner og MCP"
description: "Prosjektregler som alltid gjelder, regler for bestemte filtyper, og hvordan agenter får nye verktøy med MCP."
order: 5
---

# Instruksjoner og MCP

**Mål:** Du kan skrive prosjektinstruksjoner, lage regler som bare gjelder bestemte filer, og koble en MCP-server til Copilot.

---

## 1. Prosjektinstruksjoner: husreglene

Prosjektinstruksjoner sendes med i **hver** samtale i prosjektet, uansett hvilken agent du bruker. Her legger du regler alle skal følge.

| Fil | Brukes av |
|---|---|
| `.github/copilot-instructions.md` | GitHub Copilot |
| `AGENTS.md` (i roten av prosjektet) | Copilot og mange andre AI-verktøy (åpen standard) |

Velg én av dem. Det trengs ikke frontmatter.

### Eksempel: kursportalens egne instruksjoner

Denne kursportalen har filen `.github/copilot-instructions.md`:

```markdown
# Kursportalen – instruksjoner for AI-agenter

Statisk nettside (Vite og vanlig JavaScript) som viser undervisningsopplegg skrevet i Markdown i `content/`.

- **Innhold:** Hvert emne er en mappe `content/<emne>/` med `emne.json` ... Alle regler står i `VEILEDNING-nye-emner.md`.
- **Ikke endre kode** i `src/`, `scripts/` eller `tests/` for å legge til innhold.
- **Navn:** Mappe- og filnavn har bare små bokstaver, tall og bindestrek ...
- **Språk:** Norsk bokmål, enkelt og tydelig ...
- **Fasit og lærerstoff:** Fasit starter med `**Fasit:**` ...
- **Kontroll:** Etter endringer kjøres `npm test` og `npm run build`.
```

**Gode instruksjoner er:**

| ✅ Gjør | ❌ Unngå |
|---|---|
| Korte, konkrete regler | Lange essays |
| Henvisninger til filer med mer detaljer («se VEILEDNING-nye-emner.md») | Å kopiere hele veiledningen inn |
| Regler agenten faktisk har gjort feil på | Selvfølgeligheter som «skriv god kode» |
| Kommandoer som virker i prosjektet (`npm test`) | Kommandoer som ikke finnes |

### Slik tester du instruksjonene

1. `Ctrl + Shift + P` → **Chat: Open Customizations** → fanen **Instructions**. Filen skal stå i listen.
2. Start en **ny chat**, og be om noe der regelen har betydning, **uten** å nevne regelen. Eksempel: *«Lag et nytt tema om indekser i content/datavarehus/.»*
3. Sjekk resultatet: Ble filnavnet riktig? Har oppgavene `**Fasit:**`? Ble `npm run build` kjørt?
4. Under svaret kan du ofte se **References**, altså hvilke filer som ble tatt med. Instruksjonsfilen skal stå der.

> Instruksjoner *styrer* agenten, men de er ingen garanti. Sjekk alltid resultatet.

---

## 2. Regler for bestemte filer (`*.instructions.md`)

Noen regler gjelder bare noen filer, for eksempel SQL. Da lager du en egen instruksjonsfil med feltet `applyTo`:

📁 `.github/instructions/sql.instructions.md`

```markdown
---
applyTo: "**/*.sql"
---

# SQL i kursportalen

- Skriv nøkkelord med STORE bokstaver: `SELECT`, `FROM`, `WHERE`.
- Start hver fil med en kommentarblokk der første linje er tittel og neste linje er beskrivelse
  (portalen viser dette på siden «Case-filer»).
- Bruk tabellnavnene fra caset Nordhandel AS (`dw.FaktSalg`, `dw.DimKunde` …).
```

| `applyTo` | Gjelder |
|---|---|
| `"**/*.sql"` | Alle SQL-filer i prosjektet |
| `"content/**/*.md"` | Alle temafiler |
| `"content/datavarehus/**"` | Alt i emnet Datavarehus |

Reglene tas bare med når agenten jobber med filer som passer med mønsteret. Det sparer plass og gir mer presise svar.

---

## 3. MCP: gi agentene nye verktøy

**MCP** (*Model Context Protocol*) er en standard for å koble AI-agenter til verktøy og data utenfor prosjektet, for eksempel dokumentasjon, GitHub, databaser eller nettlesere. En **MCP-server** er et lite program eller en nettjeneste som tilbyr slike verktøy.

```text
  Copilot-agent  ──spør──▶  MCP-server  ──▶  Microsoft Learn / GitHub / database …
                 ◀─svar───
```

### Eksempel: koble til Microsoft Learn (gratis, uten innlogging)

1. Velg **Copilot** under **Session Target** i chatten.
2. `Ctrl + Shift + P` → **Chat: Open Customizations** → fanen **MCP Servers**.
3. Klikk **+** (Add Server) ved **User**.
4. Velg **HTTP**, og lim inn adressen `https://learn.microsoft.com/api/mcp`.
5. Gi serveren navnet `microsoftLearn`.
6. Velg den globale plasseringen for Copilot når du blir spurt. Da virker serveren i alle prosjektene dine.
7. Godkjenn eventuelle spørsmål om tillit til serveren.

**Test:** Skriv i chatten: *«Søk i Microsoft-dokumentasjonen: hva er Direct Lake i Power BI?»* I chatten ser du at det brukes et verktøy fra `microsoftLearn`, og svaret har lenker til learn.microsoft.com.

Nå kan agenter bruke serveren med `tools: [..., 'microsoftLearn/*']` (se eksempel 6.5 i tema 4).

### Dele en MCP-server med prosjektet

Skal alle i prosjektet bruke samme server, kan den ligge i filen `.vscode/mcp.json` i prosjektet:

```json
{
  "servers": {
    "microsoftLearn": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    }
  }
}
```

> 🔒 **Sikkerhet med MCP:**
> - Bruk bare servere fra utgivere du stoler på. En lokal MCP-server kan kjøre programmer på maskinen din.
> - **Legg aldri passord, API-nøkler eller tokens i `mcp.json`** eller andre filer som havner i Git. Følg utgiverens veiledning for innlogging.
> - Les hva et verktøy vil gjøre før du godkjenner det.
