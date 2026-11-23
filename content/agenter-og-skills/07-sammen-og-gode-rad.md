---
title: "Agenter og skills sammen"
description: "Når du lager agent, skill eller instruksjon, gode råd, vanlige feil, feilsøking og sikkerhet."
order: 7
---

# Agenter og skills sammen

**Mål:** Du kan velge riktig byggekloss for en oppgave, unngå de vanligste feilene og feilsøke når noe ikke virker.

## 7. Agenter og skills sammen

Agenter og skills utfyller hverandre. Slik henger det sammen i kursportalen:

```text
┌──────────────────────────────────────────────────────────────┐
│  Instruksjoner: .github/copilot-instructions.md  (alltid med) │
│                                                              │
│  Agent: "Kursforfatter"                                      │
│  Rolle + verktøy (read, search, edit, execute)               │
│                                                              │
│   Brukeren: "Lag et nytt emne om Power BI"                   │
│        │                                                     │
│        ▼  agenten har skillen i skills: [...]                │
│   Skill: nytt-tema        → leser SKILL.md                   │
│        │                                                     │
│        ▼  trenger malen                                      │
│   nytt-tema/mal.md        → leses ved behov                  │
│        │                                                     │
│        ▼  ferdig, skal kontrollere                           │
│   Skill: sjekk-innhold    → kjører skriptet                  │
└──────────────────────────────────────────────────────────────┘
```

**Hvorfor ikke legge alt i agenten?**

- Agentinstruksjonene lastes **hver gang**. Lange instruksjoner koster mer og gir dårligere fokus.
- Skills kan **gjenbrukes** av alle agenter.
- Skills lastes **bare ved behov**.

| Spørsmål | Svar: lag … |
|---|---|
| Skal assistenten *oppføre seg* annerledes (rolle, tone, begrensninger)? | Agent |
| Trenger den *andre verktøy* eller en annen modell? | Agent |
| Er det en *oppskrift* eller *fagkunnskap* som trengs av og til? | Skill |
| Er det en bestilling du gjentar ofte, som `/lag-quiz`? | Skill (som du kjører med `/navn`) |
| Må noe være *nøyaktig* (beregning, kontroll)? | Skill med skript |
| Er det en regel som *alltid* gjelder i prosjektet? | `copilot-instructions.md` eller `AGENTS.md` |
| Er det en regel for *bestemte filtyper*? | `*.instructions.md` med `applyTo` |
| Trenger agenten data eller verktøy *utenfor* prosjektet? | MCP-server |

---

## 8. Gode råd og vanlige feil

### ✅ Gode råd

1. **Start smått.** En skill på 15 linjer som brukes, er bedre enn en på 500 linjer som ingen leser.
2. **Skriv beskrivelsen først.** Hvis du ikke klarer å si *når* skillen skal brukes, er den for vag.
3. **Bruk konkrete eksempler.** AI-en lærer mer av ett godt eksempel enn av tre avsnitt med teori.
4. **Bruk nummererte steg** for prosedyrer.
5. **Si hva som er forbudt.** Begrensninger som «Aldri …» er svært effektive.
6. **Bruk skript for det som må være eksakt** (beregninger, validering, formatering).
7. **Test med realistiske forespørsler** og juster beskrivelsen hvis skillen ikke blir valgt.
8. **Versjoner i Git** og gjennomgå endringer i agenter og skills som vanlig kode.

### ❌ Vanlige feil

| Feil | Symptom | Løsning |
|---|---|---|
| `name` ≠ mappenavn | Skillen dukker ikke opp | Gi dem samme navn, for eksempel `commit-melding/` og `name: commit-melding` |
| Vag `description` | Skillen blir aldri brukt | Legg til «Bruk når …» og nøkkelord |
| Feil filnavn (`skill.md`, `Skill.md`) | Skillen blir ikke funnet | Filen **må** hete `SKILL.md` |
| Glemt `---` rundt frontmatter | Feltene blir ikke lest | Frontmatter må stå øverst, mellom to `---`-linjer |
| Agent uten `tools`-felt | Agenten kan gjøre *alt*, også endre filer | Begrens verktøyene eksplisitt |
| Stoler på «Endre aldri filer» i teksten | Agenten endrer likevel noe | Ta bort `edit` fra `tools`. Instrukser er ikke sperrer. |
| Bruker `handoffs` eller `agents:` i Copilot-modus | Feltene har en strek under seg og virker ikke | Bytt agent selv, eller deleger med instruksjoner (tema 4, eksempel 6.3 og 6.4) |
| Tester i en gammel chat | Endringen ser ikke ut til å virke | Start alltid en **ny** chat etter at du har endret en agent eller skill |
| Alt i én gigantisk agent | Treg agent som glemmer instruksjoner | Flytt detaljer til skills |
| Hemmeligheter i skill, agent eller `mcp.json` | Sikkerhetshull når filen deles i Git | Aldri passord eller nøkler i disse filene |
| Motstridende instruksjoner | Uforutsigbar oppførsel | Ha én kilde til sannhet. Henvis i stedet for å kopiere. |

### 🔍 Feilsøking

| Problem | Sjekk dette |
|---|---|
| Agenten eller skillen finnes ikke | `Ctrl + Shift + P` → **Chat: Open Customizations**. Står den i listen? Har den et feilmerke? Ligger filen i `.github/agents/` eller `.github/skills/<navn>/SKILL.md`? |
| Agenten står ikke i nedtrekksmenyen | Har du valgt **Copilot** under **Session Target**? Har agenten `user-invocable: false`? |
| Skillen brukes ikke automatisk | Test med `/skill-navn` først. Virker den da, er beskrivelsen for vag. |
| Agenten bruker verktøy den ikke skulle | Se verktøylinjene i chatten. Fjern verktøyet fra `tools`. |
| Subagenten startet ikke | Sjekk at lederen har `agent` i `tools`, og at instruksjonen nevner agentnavnet nøyaktig |
| MCP-verktøyene mangler | **Chat: Open Customizations → MCP Servers**. Kjører serveren? Stemmer navnet i `tools` (`'microsoftLearn/*'`)? |

Du kan også spørre assistenten direkte: *«Hvilke agenter og skills har du tilgjengelig?»*

### 🛡️ Ansvarlig bruk

- **Du har ansvaret** for det agenten lager. Les, test og kvalitetssikre før du publiserer.
- **Godkjenn kommandoer bevisst.** Les hva agenten vil kjøre før du klikker *Allow*.
- **Del ikke personopplysninger** eller hemmeligheter i chatten.
- **I læring:** Bruk veilederagenter til å forstå, ikke til å slippe å tenke. Følg skolens regler for bruk av AI på innleveringer og eksamen.
