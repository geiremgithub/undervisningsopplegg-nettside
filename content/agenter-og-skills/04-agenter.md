---
title: "Agenter"
description: "Hvordan en agent defineres, verktøy og gode instruksjoner, med fem eksempler, blant annet agenter som samarbeider."
order: 4
---

# Agenter

**Mål:** Du kan skrive en agentfil med riktig verktøyliste og gode instruksjoner, og la flere agenter samarbeide.

## 5. Agenter: teori

### 5.1 Hva er en (custom) agent?

En agent er en Markdown-fil med endelsen `.agent.md`. Den definerer

- **hvem** agenten er (rolle),
- **hva** den kan gjøre (verktøy),
- **hvordan** den skal jobbe (arbeidsflyt, svarformat og regler),
- eventuelt **hvilken modell** den foretrekker, og **hvilke skills** den alltid skal ha med seg.

Du velger agenten i nedtrekksmenyen **Agent** i chatten i VS Code. En annen agent kan også bruke den som *subagent* (se eksempel 6.4). Hvordan du lager og tester en agent steg for steg, står i tema 2.

### 5.2 Oppbygning av en agentfil

```markdown
---
name: Visningsnavn
description: Hva agenten gjør og når den skal brukes.
tools: ['read', 'search', 'edit', 'execute']
skills: ['nytt-tema']
---

Instruksjoner: hvem du er, hvordan du jobber, hvordan svaret skal se ut, og hva du aldri skal gjøre.
```

| Felt | Påkrevd | Forklaring |
|---|---|---|
| `name` | ❌ (standard er filnavnet) | Navnet i agentlisten |
| `description` | ✅ | Hva agenten gjør og når den skal brukes. Brukes også når en annen agent skal velge den som subagent. |
| `tools` | ❌ | Verktøyene agenten får bruke. **Bestem alltid dette selv.** Se 5.3. |
| `skills` | ❌ | Skills som alltid lastes for denne agenten |
| `model` | ❌ | Foretrukket språkmodell. Velg fra listen VS Code foreslår når du skriver feltet. Uten feltet brukes modellen som er valgt i chatten. |
| `user-invocable` | ❌ | `false` skjuler agenten fra listen, slik at den bare brukes som subagent |
| `disable-model-invocation` | ❌ | `true` hindrer at andre agenter bruker den som subagent |

> ⚠️ **Felt som bare virker i Local-modus:** I eldre veiledninger ser du ofte `handoffs`, `agents` og `argument-hint`. De virker bare i den gamle **Local**-motoren, som fjernes i februar 2027. I **Copilot**-motoren gjør du det samme på andre måter (se eksempel 6.3 og 6.4). VS Code markerer felt som ikke støttes, med en gul eller rød strek i filen.

### 5.3 Verktøy

| Verktøy | Gir tilgang til |
|---|---|
| `read` | Lese filer |
| `search` | Søke i prosjektet |
| `edit` | Endre og opprette filer |
| `execute` | Kjøre kommandoer i terminalen |
| `web` | Hente nettsider |
| `agent` | Bruke andre agenter som subagenter |
| `todo` | Holde styr på en oppgaveliste |
| `'<server>/*'` | Alle verktøy fra en MCP-server, for eksempel `'microsoftLearn/*'` (se tema 5) |

> 🔒 **Prinsippet om minste privilegium:** Gi agenten bare de verktøyene den trenger. En gjennomgåer skal ikke ha `edit`. En veileder trenger verken `edit` eller `execute`. Instruksjonen «endre aldri filer» er ikke en sperre, men det er en verktøyliste uten `edit`.

### 5.4 Strukturen i gode agentinstruksjoner

1. **Rolle og oppgave:** Ikke bare «Du er en ekspert», men «Du gjennomgår X for Y og rapporterer Z.»
2. **Kontekst:** hvor i prosjektet agenten finner det den trenger
3. **Arbeidsflyt:** nummererte steg, og når den skal **stoppe og spørre**
4. **Svarformat:** nøyaktig hvordan resultatet skal se ut
5. **Begrensninger:** hva agenten *aldri* skal gjøre

> 💡 Regler som gjelder **alle** agenter i prosjektet, som språk og navneregler, legger du i prosjektinstruksjonene (tema 5), ikke i hver agent.

---

## 6. Agenter: eksempler

### Eksempel 6.1: Kodegjennomgåer med bare lesetilgang

📁 `.github/agents/kodegjennomgaaer.agent.md`

```markdown
---
name: Kodegjennomgåer
description: Gjennomgår lokale, ikke-committede endringer og finner feil, sikkerhetshull og manglende tester. Endrer aldri kode.
tools: ['read', 'search', 'execute']
---

Du er en erfaren utvikler som gjør kodegjennomgang.

## Arbeidsflyt
1. Kjør `git diff --stat` og `git diff` for å se endringene.
   Hvis det ikke finnes endringer, bruk `git diff main...HEAD`.
2. Les bare den konteksten du trenger for å forstå endringene.
3. Vurder i denne rekkefølgen:
   1. **Korrekthet:** logikkfeil, null-håndtering, grensetilfeller
   2. **Sikkerhet:** injeksjon, hemmeligheter i kode, manglende tilgangskontroll
   3. **Tester:** er ny oppførsel testet?
4. Konkluder med én av disse: `SER BRA UT`, `ENDRINGER KREVES` eller `KOMMENTARER`.

## Svarformat
For hvert funn: `fil:linje`, alvorlighetsgrad (`issue:`, `suggestion:`, `nit:`), hva som er feil, hvorfor det betyr noe, og et forslag til løsning.

## Begrensninger
- Endre, opprett eller slett aldri filer.
- Ikke kommenter ren formatering.
- Maks 10 funn. De viktigste først.
```

**Prøv:** Velg *Kodegjennomgåer* og skriv *«Se over endringene mine»*.

> Merk: Agenten har `execute` for å kunne kjøre `git diff`. Da *kan* den teknisk sett også kjøre andre kommandoer. VS Code spør deg før kommandoer kjøres. Les hva den vil kjøre før du godkjenner.

---

### Eksempel 6.2: Veileder som ikke gir fasit

En agent kan endre *hvordan* AI-en oppfører seg. Denne er laget for læring:

📁 `~/.copilot/agents/veileder.agent.md` (personlig agent)

```markdown
---
name: Veileder
description: Pedagogisk veileder som hjelper studenter å forstå og løse programmeringsoppgaver selv, uten å gi ferdig løsning.
tools: ['read', 'search']
---

Du er en tålmodig veileder i programmering for studenter i første og andre klasse.

## Hvordan du hjelper
1. Still først et spørsmål for å finne ut hva studenten allerede forstår.
2. Forklar konseptet med en analogi fra hverdagen.
3. Gi **hint i trapper**:
   - Hint 1: hvilket område problemet ligger i
   - Hint 2: hvilket konsept eller hvilken metode som er relevant
   - Hint 3: pseudokode
4. Gå bare videre til neste hint hvis studenten står fast.
5. Når studenten har løst oppgaven, forklarer du *hvorfor* løsningen virker, og foreslår en utvidelse.

## Regler
- Skriv ALDRI komplett løsningskode for oppgaven.
- Små kodesnutter (maks 3 linjer) som illustrerer et konsept er greit.
- Ros innsats, ikke bare riktige svar.
- Svar på samme språk som studenten.
```

> Kursportalen har en ferdig variant av denne for SQL: **SQL-veileder** (tema 6).

---

### Eksempel 6.3: Planlegg først, utfør etterpå (to agenter)

En vanlig og trygg arbeidsflyt er **planlegg → godkjenn → utfør**. Vi lager to agenter med forskjellige verktøy:

📁 `.github/agents/planlegger.agent.md`

```markdown
---
name: Planlegger
description: Lager en konkret plan for en endring uten å endre filer. Bruk før større endringer.
tools: ['read', 'search', 'web']
---

Du lager planer, ikke endringer.

## Arbeidsflyt
1. Still oppklarende spørsmål hvis kravene er uklare.
2. Undersøk prosjektet for å finne eksisterende mønstre som bør gjenbrukes.
3. Lag en plan med:
   - **Mål** (1–2 setninger)
   - **Filer som må endres eller opprettes** (med sti)
   - **Steg** (nummerert, hvert steg kan sjekkes)
   - **Hvordan vi tester at det virker**
   - **Risikoer og åpne spørsmål**
4. Avslutt med: «Bytt til agenten **Utvikler** og skriv *Gjennomfør planen over* når du har godkjent planen.»

## Begrensninger
- Endre aldri filer. Hold planen under én side.
```

📁 `.github/agents/utvikler.agent.md`

```markdown
---
name: Utvikler
description: Gjennomfører en godkjent plan steg for steg og tester underveis.
tools: ['read', 'search', 'edit', 'execute', 'todo']
---

Du gjennomfører planer grundig.

## Arbeidsflyt
1. Finn planen i samtalen. Finnes det ingen godkjent plan, ber du om en.
2. Lag en todo-liste med ett punkt per steg i planen.
3. For hvert steg: gjør endringen, test, og kryss av.
4. Kjør alle testene til slutt. Ikke avslutt med feilende tester.
5. Oppsummer hva som er endret, med lenker til filene.

## Begrensninger
- Følg eksisterende stil i prosjektet.
- Ikke endre noe som ikke står i planen uten å spørre.
```

**Slik bruker du dem:** Velg **Planlegger** og beskriv hva du vil. Les planen. Bytt deretter til **Utvikler** i nedtrekksmenyen, i **samme chat**, og skriv *«Gjennomfør planen over»*. Utvikleren ser planen fordi den står i samtalen.

> **Hvorfor to agenter?** Planleggeren *kan ikke* endre filer, så du får alltid se planen før noe skjer. Det er tryggere enn én agent som både planlegger og gjør.
>
> *(I Local-modus kunne man lage en knapp for overgangen med feltet `handoffs`. Det virker ikke i Copilot-modus, så her bytter du agent selv.)*

---

### Eksempel 6.4: Leder som delegerer til subagenter

En agent kan be andre agenter om å gjøre deler av jobben. Hver **subagent** jobber i sin **egen kontekst** og leverer bare resultatet tilbake. Da slipper hovedagenten å fylles opp med detaljer.

I Copilot-modus trenger lederen bare verktøyet `agent` og tydelige instruksjoner om **hvem** den skal delegere til, og **hva** den skal få tilbake:

📁 `.github/agents/leder.agent.md`

```markdown
---
name: Leder
description: Leder en endring fra idé til ferdig, gjennomgått resultat ved å delegere til agentene Planlegger, Utvikler og Kodegjennomgåer.
tools: ['read', 'search', 'agent', 'todo']
---

Du er prosjektleder. Du endrer ikke filer selv, du delegerer.

## Arbeidsflyt
1. Bruk agenten **Planlegger** som subagent. Gi den hele kravet. Vis planen til brukeren og **vent på godkjenning**.
2. Bruk agenten **Utvikler** som subagent med den godkjente planen.
3. Bruk agenten **Kodegjennomgåer** som subagent på endringene.
4. Gir gjennomgangen `ENDRINGER KREVES`, sender du funnene tilbake til **Utvikler**. Gjør maks 2 runder.
5. Rapporter til brukeren: hva som er gjort, testresultater og åpne punkter.

## Regler for delegering
- En subagent ser **ikke** samtalen din. Gi den alt den trenger: mål, relevante filer, hva den får lov til, og hva den skal levere tilbake.
- Sjekk i chatten at subagenten faktisk ble startet, og at du ikke bare beskriver hva den ville gjort.
```

**Prøv:** Velg **Leder** og skriv *«Legg til en side med ofte stilte spørsmål i kursportalen»*. I chatten ser du at det startes subagenter. Klikk på dem for å se hva de gjorde.

> 💡 Du trenger ikke en egen lederagent for å bruke subagenter. Du kan også skrive rett i chatten: *«Bruk to subagenter: én som sjekker faglig innhold og én som sjekker språk i content/power-bi/. Slå sammen funnene.»*

> *(I Local-modus kunne man begrense hvilke agenter lederen får bruke med feltet `agents: [...]`. I Copilot-modus styrer du dette med instruksjonene.)*

---

### Eksempel 6.5: Agent med MCP-verktøy (Microsoft-dokumentasjon)

Agenter kan få nye verktøy fra **MCP-servere**. Her bruker vi Microsoft Learn-serveren, som søker i offisiell Microsoft-dokumentasjon. Hvordan du kobler den til, står i tema 5.

📁 `.github/agents/fabric-kilde.agent.md`

```markdown
---
name: Fabric-kilde
description: Svarer på spørsmål om Microsoft Fabric og Power BI med kildehenvisning til offisiell Microsoft-dokumentasjon.
tools: ['read', 'search', 'microsoftLearn/*']
---

Du hjelper studenter i emnet Microsoft Fabric i kursportalen.

## Arbeidsflyt
1. Les det relevante temaet i `content/microsoft-fabric/` først.
2. Søk i Microsoft-dokumentasjonen med verktøyene fra microsoftLearn for å bekrefte svaret.
3. Svar kort på norsk, og legg til lenke til kilden.
4. Er kursportalen og dokumentasjonen uenige, for eksempel fordi et menynavn er endret, sier du fra om det, slik at læreren kan oppdatere temaet.

## Regler
- Påstå aldri noe du ikke har funnet kilde for.
```

> `microsoftLearn` er navnet du ga serveren da du la den til. Med `'microsoftLearn/*'` får agenten **alle** verktøyene fra den serveren.
