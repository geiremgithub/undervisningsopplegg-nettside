---
title: "Videoer: MCP-server"
description: "Utvalgte videoer om hva MCP er, hvordan protokollen fungerer, og hvordan du bygger en MCP-server i Python, C# og TypeScript."
order: 3
---

# Videoer: MCP-server

Alle videoene er på engelsk og gratis på YouTube. Lenkene er kontrollert og var offentlig tilgjengelige i november 2026. Beskrivelsene bygger på videoenes egen beskrivelse, kapitler og lengde. Jeg har ikke sett hele videoene.

**Anbefalt rekkefølge:** Start med IBM (4 min) og Google Cloud (8 min) for å forstå begrepene. Se deretter codebasics for protokollen i detalj. Velg så én byggevideo i det språket du kan best.

---

## Hva er MCP? (begreper og arkitektur)

Hører til [Hva er MCP, og hvordan fungerer det?](01-hva-er-mcp.md).

### What is MCP? Integrate AI Agents with Databases & APIs

- **Kanal / kilde:** YouTube – IBM Technology · 3:46 · 2025
- **Lenke:** https://www.youtube.com/watch?v=eur8dUO9mvE
- **Nivå:** Nybegynner
- **Innhold:** Roy Derks forklarer på tavla hvordan MCP kobler KI-agenter til databaser og API-er, og går gjennom komponentene fra **host** og **klient** til **server**, med eksempler på bruk. Kortest og best som første møte med begrepene.

### How Model Context Protocol (MCP) actually works

- **Kanal / kilde:** YouTube – Google Cloud Tech · 7:58 · 2026
- **Lenke:** https://www.youtube.com/watch?v=cGuyrANVi4A
- **Nivå:** Nybegynner
- **Innhold:** Smitha Kolan forklarer *hvorfor* MCP trengs: API-er er laget for deterministiske programmer, mens språkmodeller resonnerer probabilistisk. Videoen viser hvordan MCP standardiserer måten modeller **oppdager** og bruker eksterne ressurser på, i stedet for egen integrasjonskode for hvert verktøy. Ny og oppdatert video.

### Why Everyone's Talking About MCP?

- **Kanal / kilde:** YouTube – ByteByteGo · 5:03 · 2025
- **Lenke:** https://www.youtube.com/watch?v=_d0duu3dED4
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Animert arkitekturforklaring av MCP i ByteByteGos systemdesign-stil, med diagrammer av komponentene og hvordan de snakker sammen. Merk: Kanalen opplyser at en feil i 2:44–3:10 er rettet i versjonen på X, men ikke på YouTube.

### Introduction to Model Context Protocol (MCP)

- **Kanal / kilde:** YouTube – Microsoft Developer · 5:08 · 2025
- **Lenke:** https://www.youtube.com/watch?v=agBbdiOPLQA
- **Nivå:** Nybegynner
- **Innhold:** Første kapittel i Microsofts kurs *MCP for Beginners*. Forklarer hvorfor KI-apper blir komplekse når de får flere modeller og verktøy, og hvordan MCP gir en konsistent arkitektur for å legge til nye funksjoner.

---

## Protokollen i detalj

### Model Context Protocol Clearly Explained | MCP Beyond the Hype

- **Kanal / kilde:** YouTube – codebasics · 15:04 · 2025
- **Lenke:** https://www.youtube.com/watch?v=tzrwxLNHtRY
- **Nivå:** Viderekommen
- **Innhold:** Starter med en enkel forklaring av hva MCP er og hvordan det forenkler utviklingen av KI-apper. Går deretter inn i **hvordan selve protokollen ser ut**, og viser koden til både en MCP-**klient** (Python-SDK-ens eksempelchatbot) og en MCP-**server** (Google Maps-serveren). God bro mellom teori og kode.

---

## Bygg din egen MCP-server

Hører til [Bygg og koble til en MCP-server](02-bygg-mcp-server.md).

### Build Anything With a CUSTOM MCP Server – Python Tutorial

- **Kanal / kilde:** YouTube – Tech With Tim · 26:00 · 2025
- **Lenke:** https://www.youtube.com/watch?v=-8k9lGpGQ6g
- **Nivå:** Nybegynner (med litt Python)
- **Innhold:** Steg-for-steg-bygging av en egen MCP-server i **Python**, og hvordan den kobles til en KI-agent. Laget for nybegynnere og viser hva en MCP-server faktisk er, og hvordan den kan utvides. Samme språk og SDK som i tema 2.

### Beginner's Guide to Building a MCP Server with C# and .NET

- **Kanal / kilde:** YouTube – James Montemagno · 25:19 · 2025
- **Lenke:** https://www.youtube.com/watch?v=MKD-sCZWpZQ
- **Nivå:** Nybegynner (med litt C#)
- **Innhold:** Bygger og tester en MCP-server med den **offisielle C#-SDK-en** for MCP, som Microsoft har laget sammen med Anthropic. Alt gjøres i VS Code: bygging, testing og kobling til Copilot. Passer for .NET-utviklere.

### The Ultimate MCP Crash Course – Build From Scratch

- **Kanal / kilde:** YouTube – Web Dev Simplified · 1:15:25 · 2025
- **Lenke:** https://www.youtube.com/watch?v=ZoZxQwp1PiM
- **Nivå:** Viderekommen (JavaScript/TypeScript)
- **Innhold:** Grundig forklaring av hva MCP er og hvordan det fungerer, og deretter bygging av både en egen MCP-**server** og en egen MCP-**klient** fra bunnen av i TypeScript. Den lengste og mest komplette byggevideoen.

### Full Course (Lessons 1–11) MCP for Beginners

- **Kanal / kilde:** YouTube – Microsoft Developer · 50:46 · 2025
- **Lenke:** https://www.youtube.com/watch?v=VfZlglOWWZw
- **Nivå:** Nybegynner → viderekommen
- **Innhold:** Hele Microsoft-kurset *MCP for Beginners* med April Gittens, i én video: kjernebegreper, praktisk utvikling, avansert implementasjon og eksempler fra virkeligheten, blant annet hvordan du bygger og deployer agenter med MCP i VS Code. Kode og øvelser ligger på https://aka.ms/MCP-for-Beginners.

### MCP Servers in VS Code and GitHub Copilot

- **Kanal / kilde:** YouTube – Visual Studio Code · 9:07 · 2025
- **Lenke:** https://www.youtube.com/watch?v=vUQfqW5GKAQ
- **Nivå:** Nybegynner
- **Innhold:** Den offisielle VS Code-kanalen viser hvordan du legger til og bruker MCP-servere i GitHub Copilot, det samme som avsnitt 1 i tema 2.

---

> **Lærernotat:** IBM-videoen (4 min) passer som innledning i timen. Microsoft-kurset passer som hjemmearbeid for studenter som vil fordype seg.
