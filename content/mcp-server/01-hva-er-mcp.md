---
title: "Hva er MCP, og hvordan fungerer det?"
description: "Problemet MCP løser, arkitekturen med host, klient og server, og byggeklossene tools, resources og prompts."
order: 1
---

# Hva er MCP, og hvordan fungerer det?

**Mål:** Etter dette temaet kan du forklare hva Model Context Protocol (MCP) er, hvilke roller som finnes, og hvordan en KI-assistent bruker en MCP-server til å hente data og utføre handlinger.

**Forkunnskaper:** Du har brukt en KI-assistent som ChatGPT eller GitHub Copilot. Litt kjennskap til API-er er en fordel.

---

## 1. Problemet MCP løser

En språkmodell (LLM) vet bare det den ble trent på. Skal den svare på spørsmål om *dine* data, som en database, et saksystem eller en dokumentasjon, eller gjøre noe for deg, trenger den **verktøy**.

Før MCP måtte hver KI-app lage sin egen integrasjon mot hvert system. Med tre apper og tre systemer blir det ni integrasjoner:

```text
Uten MCP: 3 apper × 3 systemer = 9 egne integrasjoner

  Copilot  ──┬──▶ GitHub         Claude ──┬──▶ GitHub        Egen app ──┬──▶ GitHub
             ├──▶ Database                ├──▶ Database                 ├──▶ Database
             └──▶ Dokumenter              └──▶ Dokumenter               └──▶ Dokumenter

Med MCP: hver app snakker MCP, og hvert system får én MCP-server (3 + 3)

  Copilot  ──┐                  ┌──▶ MCP-server for GitHub
  Claude   ──┼──── MCP ─────────┼──▶ MCP-server for databasen
  Egen app ──┘                  └──▶ MCP-server for dokumentene
```

**MCP er en åpen standard.** Den kommer opprinnelig fra Anthropic og brukes nå av blant andre Microsoft, Google og OpenAI. Den beskriver *én felles måte* for KI-apper å oppdage og bruke verktøy og data på, og sammenlignes ofte med **USB-C for KI**: én kontakt som passer overalt.

---

## 2. Arkitekturen: host, klient og server

| Rolle | Hva den er | Eksempel |
|---|---|---|
| **Host** | Programmet brukeren jobber i, og som bruker språkmodellen | VS Code med GitHub Copilot, Claude Desktop, din egen chatbot |
| **MCP-klient** | En del av hosten som holder forbindelsen til **én** MCP-server | Lages automatisk av VS Code for hver server du legger til |
| **MCP-server** | Et lite program eller en nettjeneste som tilbyr verktøy og data | Microsoft Learn-serveren, GitHub-serveren, en server du lager selv |

```text
┌───────────────── Host (f.eks. VS Code + Copilot) ─────────────────┐
│                                                                    │
│   Språkmodell ◀──▶ MCP-klient A ◀──JSON-RPC──▶ MCP-server: GitHub  │
│                    MCP-klient B ◀──JSON-RPC──▶ MCP-server: Learn   │
└────────────────────────────────────────────────────────────────────┘
```

**Viktig:** Språkmodellen snakker aldri direkte med serveren. Modellen *foreslår* et verktøykall, og hosten utfører det via klienten. Hosten kan be brukeren om godkjenning før noe skjer.

---

## 3. Hva en MCP-server kan tilby

| Byggekloss | Hva det er | Hvem bestemmer bruken? | Eksempel |
|---|---|---|---|
| **Tools** (verktøy) | Funksjoner modellen kan kalle, med navn, beskrivelse og parametere | Modellen | `sok_i_dokumentasjon(sporsmal)`, `opprett_issue(tittel, tekst)` |
| **Resources** (ressurser) | Data som kan leses, identifisert med en URI | Appen eller brukeren | `file:///rapport.md`, `db://kunder/42` |
| **Prompts** (maler) | Ferdige meldingsmaler brukeren kan velge | Brukeren | «Lag en kodegjennomgang av …» |

Tools er det klart mest brukte. Det er det du lager når du vil gi en agent en ny evne.

---

## 4. Slik foregår en samtale, steg for steg

```text
 Bruker            Host + LLM                  MCP-server
   │                   │                           │
   │                   │── initialize ────────────▶│ ① Hilser og avtaler versjon og evner
   │                   │◀─ capabilities ───────────│
   │                   │── tools/list ────────────▶│ ② Henter liste over verktøy
   │                   │◀─ [sok_i_dok, …] ─────────│    (navn, beskrivelse, JSON-skjema)
   │── «Hva er Direct  │                           │
   │    Lake?» ───────▶│ ③ LLM velger verktøy      │
   │                   │── tools/call ────────────▶│ ④ Kaller verktøyet med argumenter
   │                   │   sok_i_dok("Direct Lake")│
   │                   │◀─ resultat (tekst) ───────│
   │◀── svar med kilde ─│ ⑤ LLM bruker resultatet   │
```

- Meldingene er **JSON-RPC 2.0**: små JSON-objekter med `method`, `params` og `id`.
- **Transport** er hvordan meldingene fraktes:

| Transport | Når | Eksempel |
|---|---|---|
| **stdio** | Serveren kjører som et lokalt program på din maskin. Meldingene går via standard inn/ut. | `python server.py`, `npx …` |
| **Streamable HTTP** | Serveren kjører på nett, og meldingene går over HTTP | `https://learn.microsoft.com/api/mcp` |

Et verktøykall ser omtrent slik ut:

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "tools/call",
  "params": {
    "name": "sok_i_dokumentasjon",
    "arguments": { "sporsmal": "Hva er Direct Lake?" }
  }
}
```

---

## 5. Sikkerhet

| Risiko | Hva det betyr | Slik beskytter du deg |
|---|---|---|
| Lokale servere kjører kode på maskinen din | En ondsinnet server kan lese filer eller kjøre kommandoer | Bruk bare servere fra utgivere du stoler på. Les koden eller dokumentasjonen. |
| Verktøy handler med *dine* rettigheter | En agent kan for eksempel slette noe i GitHub på dine vegne | Gi serveren minst mulig tilgang. Les hva verktøyet vil gjøre før du godkjenner. |
| **Prompt injection** | Tekst serveren henter, for eksempel en nettside, kan inneholde skjulte instruksjoner til modellen | Behandle alt serveren returnerer som data, ikke som ordre. Krev godkjenning for handlinger som endrer noe. |
| Hemmeligheter i konfigurasjon | API-nøkler i `mcp.json` kan havne i Git | Bruk innlogging (OAuth) eller hemmelighetslager, aldri nøkler i klartekst i delte filer |

---

## Oppgaver

**Oppgave 1:** Hva er forskjellen på en MCP-*klient* og en MCP-*server*?

**Fasit:** Serveren *tilbyr* verktøy og data. Klienten er en del av hosten (for eksempel VS Code) og holder forbindelsen til én server. Hosten har én klient per server den er koblet til.

**Oppgave 2:** Hvorfor er det tryggere at hosten, og ikke språkmodellen, utfører verktøykallet?

**Fasit:** Hosten kan vise kallet til brukeren og be om godkjenning, logge det og stoppe farlige handlinger. Modellen kan bare foreslå kall, og den kan la seg lure av prompt injection.

**Oppgave 3:** En MCP-server for et saksystem skal kunne (a) søke etter saker, (b) vise innholdet i sak nr. 42 og (c) tilby en fast mal for «oppsummer sak». Hvilken MCP-byggekloss passer for hver?

**Fasit:** (a) Tool, fordi modellen kaller den med et søkeord. (b) Resource, fordi det er data som leses via en URI som `sak://42`. Et tool `hent_sak(nr)` er også et vanlig og godt svar. (c) Prompt, fordi brukeren velger malen.

> **Lærernotat:** Bruk sekvensdiagrammet i avsnitt 4 på tavla, og la studentene «spille» host, LLM og server. Det gjør det tydelig at modellen bare foreslår, og at hosten utfører.
