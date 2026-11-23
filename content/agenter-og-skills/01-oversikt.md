---
title: "Byggeklossene og hvor filene ligger"
description: "Instruksjoner, skills, agenter og MCP: hva de er, når du bruker hva, og hvor filene skal ligge."
order: 1
---

# Byggeklossene og hvor filene ligger

> **Mål:** Etter dette emnet kan du lage egne **agenter** og **skills** for GitHub Copilot i VS Code, teste at de virker, og bruke dem til å jobbe med ekte prosjekter, blant annet denne kursportalen.

**Slik er emnet bygd opp:**

| Tema | Innhold |
|---|---|
| 1. Byggeklossene (dette temaet) | Begrepene, og hvor filene ligger |
| 2. Oppsett og din første agent | Installasjon og en agent du lager steg for steg på 15 minutter |
| 3. Skills | Teori og fem eksempler |
| 4. Agenter | Teori og fem eksempler |
| 5. Instruksjoner og MCP | Prosjektregler som alltid gjelder, og hvordan agenter får nye verktøy |
| 6. Agenter for kursportalen | Ferdige, fungerende agenter og skills du kan prøve i dette prosjektet |
| 7. Sammen, gode råd og feilsøking | Når du bruker hva, og hva du gjør når noe ikke virker |
| 8. Øvingsoppgaver | Oppgaver med fasit og sjekklister |

---

## 1. Byggeklossene: oversikt

En AI-assistent som Copilot kan tilpasses på flere nivåer. Tenk på det som en ny kollega:

| Byggekloss | Analogi | Når brukes den? | Fil |
|---|---|---|---|
| **Prosjektinstruksjoner** (`copilot-instructions.md`, `AGENTS.md`) | «Velkommen til teamet, slik jobber vi her» | Alltid, i hver samtale | Markdown |
| **Filspesifikke instruksjoner** (`*.instructions.md`) | «Når du skriver C#, gjør det slik» | Når agenten jobber med filer som matcher et mønster | Markdown + `applyTo` |
| **Skills** (`SKILL.md`) | En oppskriftsbok kollegaen slår opp i ved behov | Når oppgaven matcher beskrivelsen, eller når du skriver `/skill-navn` | Mappe med `SKILL.md` |
| **Agenter** (`*.agent.md`) | En spesialist med egen rolle og egne verktøy | Når du velger agenten, eller når en annen agent delegerer til den | Markdown + frontmatter |
| **MCP-servere** | Verktøykassen: tilgang til dokumentasjon, GitHub, databaser … | Når agenten trenger et verktøy serveren har | Oppsett i VS Code (`mcp.json`) |

**Hovedforskjellen:**

- En **agent** er en *person*. Den har en rolle, et sett med verktøy og eventuelt en egen modell.
- En **skill** er *kunnskap eller en prosedyre*. Den lastes inn bare når den trengs, og kan brukes av alle agenter.
- **Instruksjoner** er *husregler* som alltid gjelder i prosjektet.

> 💡 **Tommelfingerregel:** Lag en **skill** når du har en *oppskrift* («slik lager vi et nytt tema»). Lag en **agent** når du vil ha en *rolle* med andre verktøy eller annen oppførsel («en gjennomgåer som aldri endrer filer»). Skriv **instruksjoner** for regler som *alltid* gjelder.

### Hva med prompt-filer (`*.prompt.md`)?

Tidligere brukte man ofte prompt-filer til ferdige bestillinger som `/lag-test`. I nyere VS Code virker de bare i den gamle **Local**-modusen, som fjernes i februar 2027. **Lag skills i stedet.** De dukker også opp som `/kommandoer` og virker med Copilot overalt.

### Copilot-modus eller Local-modus (harness)

I chatten i VS Code velger du hvilken *motor* (på engelsk *harness*) agenten kjører i, med valget **Session Target**. Velg **Copilot**. Det er den som gjelder fremover, og den samme motoren brukes av Copilot CLI. **Local** er den gamle motoren og er under utfasing. Noen felt i agentfiler virker bare i én av dem. Det sier vi fra om underveis.

---

## 2. Hvor filene ligger

### I et prosjekt (deles med teamet via Git)

```text
mitt-prosjekt/
├── AGENTS.md                           # Prosjektinstruksjoner (åpen standard, alternativ til filen under)
└── .github/
    ├── copilot-instructions.md         # Prosjektinstruksjoner for Copilot
    ├── instructions/
    │   └── sql.instructions.md         # Gjelder bare filer som matcher applyTo, f.eks. **/*.sql
    ├── agents/
    │   └── innholdsgjennomgaer.agent.md  # Agent
    └── skills/
        └── nytt-tema/
            ├── SKILL.md                # Skill
            └── mal.md                  # Ekstra fil skillen bruker
```

> Denne kursportalen har akkurat denne strukturen. Se i mappen `.github/` i prosjektet. Agentene og skillene der gjennomgås i tema 6.

### For deg personlig (gjelder i alle prosjekter)

| Type | Windows | macOS/Linux |
|---|---|---|
| Agenter | `%USERPROFILE%\.copilot\agents\` | `~/.copilot/agents/` |
| Skills | `%USERPROFILE%\.copilot\skills\` | `~/.copilot/skills/` |

Prosjektfiler bør du legge i Git, slik at alle som jobber i prosjektet får de samme agentene og skillene. Personlige filer er for dine egne vaner og verktøy.

> Du kan også støte på mappene `.agents/skills/` og `.claude/skills/`. De brukes av andre AI-verktøy (Codex og Claude). For Copilot er `.github/skills/` riktig sted.

### Den enkleste veien: la VS Code lage filene

Du trenger ikke huske mappene. Kjør **Chat: Open Customizations** fra kommandopaletten (`Ctrl + Shift + P`). Da åpnes en egen side med fanene **Agents**, **Skills**, **Instructions** og **MCP Servers**. Klikk **+** ved **Workspace** (prosjektet) eller **User** (personlig), så legges filen på riktig sted. Hvordan det gjøres, ser du steg for steg i neste tema.
