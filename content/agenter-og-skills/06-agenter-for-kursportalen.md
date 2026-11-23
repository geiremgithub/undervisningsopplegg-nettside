---
title: "Agenter for kursportalen"
description: "Tre ferdige agenter og fire skills som hjelper deg å skrive, kontrollere, øve på og publisere innhold i denne portalen."
order: 6
---

# Agenter for kursportalen

**Mål:** Du kan bruke, lese og tilpasse ekte agenter og skills som jobber med denne kursportalen, og lage din egen.

Alt i dette temaet **finnes i prosjektet**. Åpne kursportalen i VS Code, så kan du prøve hvert eksempel med én gang.

---

## 1. Oversikt

```text
.github/
├── copilot-instructions.md            Husregler for alle agenter (tema 5)
├── agents/
│   ├── kursforfatter.agent.md         Lager nye emner og temaer
│   ├── innholdsgjennomgaer.agent.md   Korrekturleser før publisering (endrer ingenting)
│   └── sql-veileder.agent.md          Hjelper studenter med SQL uten å gi fasit
└── skills/
    ├── nytt-tema/                     Oppskrift og mal for et nytt tema
    │   ├── SKILL.md
    │   └── mal.md
    ├── sjekk-innhold/                 Automatisk kontroll av content/
    │   ├── SKILL.md
    │   └── scripts/sjekk-innhold.mjs
    ├── lag-quiz/                      Lager quiz med fasit fra et tema
    │   └── SKILL.md
    └── publiser-endringer/            Trygg publisering med Git, bare når du ber om det
        └── SKILL.md
```

| Hva | Type | Verktøy | Hvem er den for? |
|---|---|---|---|
| **Kursforfatter** | Agent | `read`, `search`, `edit`, `execute` | Lærere og studenter som skriver innhold |
| **Innholdsgjennomgåer** | Agent | `read`, `search`, `execute` | Alle, før publisering |
| **SQL-veileder** | Agent | `read`, `search` | Studenter i emnet Datavarehus |
| `nytt-tema` | Skill | (bruker agentens verktøy) | Brukes av Kursforfatter og av deg |
| `sjekk-innhold` | Skill med skript | (bruker agentens verktøy) | Brukes av begge innholdsagentene |
| `lag-quiz` | Skill | (bruker agentens verktøy) | Alle som vil øve eller lage quiz |
| `publiser-endringer` | Skill, bare manuelt | (bruker agentens verktøy) | Alle som publiserer |

Se hvordan **verktøylistene** passer til rollene: Den som bare skal lese og veilede, har ikke `edit`. Den som skal kontrollere, har `execute` for å kjøre skriptet, men ikke `edit`.

---

## 2. Agenten Kursforfatter

**Oppgave:** lage nye emner og temaer etter portalens regler.

```markdown
---
name: Kursforfatter
description: Lager nye emner og temaer i kursportalen etter portalens regler. Bruk når du vil legge til eller utvide undervisningsinnhold i content/.
tools: ['read', 'search', 'edit', 'execute']
skills: ['nytt-tema', 'sjekk-innhold']
---
```

**Det som gjør den god:**

| Grep | Hvorfor |
|---|---|
| Leser `VEILEDNING-nye-emner.md` først | Reglene står ett sted. Agenten gjentar dem ikke. |
| Foreslår disposisjon og **venter på godkjenning** | Du styrer innholdet før det skrives mye |
| `skills: ['nytt-tema', 'sjekk-innhold']` | Agenten har alltid oppskriften og kontrollen tilgjengelig |
| Kjører `sjekk-innhold`, `npm test` og `npm run build` til slutt | Agenten tester sitt eget arbeid |
| «Ikke kjør `git commit` eller `git push`» | Mennesket bestemmer hva som publiseres |

**Prøv:**

1. Velg **Kursforfatter** i agentlisten.
2. Skriv:

   ```text
   Lag et nytt emne om Power BI for nybegynnere med tre temaer:
   kom i gang, datamodell og DAX. Målgruppen er økonomistudenter uten
   programmeringserfaring.
   ```

3. Les disposisjonen agenten foreslår. Be om endringer, eller skriv *«Godkjent»*.
4. Se at filene lages i `content/power-bi/`, og at kontrollen kjøres.
5. Start portalen med `npm run dev`, og se emnet på http://localhost:5173.

> ⚠️ **Les alltid gjennom det agenten har skrevet.** AI kan skrive faglige feil med stor selvsikkerhet. Bruk agenten **Innholdsgjennomgåer** som et ekstra sett øyne, men det er du som har ansvaret.

---

## 3. Agenten Innholdsgjennomgåer

**Oppgave:** kvalitetssikre innhold før publisering, uten å endre noe.

```markdown
---
name: Innholdsgjennomgåer
description: Gjennomgår innhold i kursportalen for feil i struktur, frontmatter, fasit, alt-tekster og språk. Endrer aldri filer. ...
tools: ['read', 'search', 'execute']
skills: ['sjekk-innhold']
---
```

Den kombinerer **automatisk kontroll** (skriptet i `sjekk-innhold`) med **vurdering** av faglig innhold, pedagogikk og språk, og ender alltid med én av konklusjonene `KLAR FOR PUBLISERING`, `SMÅ RETTELSER` eller `MÅ RETTES`.

**Prøv:** Velg **Innholdsgjennomgåer** og skriv:

```text
Gjennomgå content/agenter-og-skills/02-oppsett-og-forste-agent.md
```

> 💡 **Kombiner agentene:** Når Kursforfatter er ferdig, kan du bytte til Innholdsgjennomgåer i samme chat og skrive *«Gjennomgå det som nettopp ble laget»*. Eller be Kursforfatter om å bruke Innholdsgjennomgåer som subagent (se eksempel 6.4 i tema 4).

---

## 4. Agenten SQL-veileder

**Oppgave:** hjelpe studenter med oppgavene i Datavarehus, uten å gi bort fasiten.

```markdown
---
name: SQL-veileder
description: Pedagogisk veileder for emnet Datavarehus. Hjelper studenter å forstå og løse SQL-oppgaver selv ...
tools: ['read', 'search']
---
```

Det spesielle med denne agenten er at den bruker **kursportalens eget innhold** som kunnskapsgrunnlag:

- temaene i `content/datavarehus/`
- de faktiske tabellene i `content/datavarehus/case/*.sql`

Derfor bruker den de samme tabellnavnene som oppgavene, og ikke oppdiktede eksempler.

**Prøv:** Velg **SQL-veileder** og skriv:

```text
Jeg jobber med lab 4 i samling 4 og skjønner ikke hvordan jeg finner
de tre beste produktene per kategori.
```

Legg merke til at du får **hint i trapper**, ikke svaret.

> **Diskusjon:** Agenten har bare `read` og `search`, og instruksjonen sier «vis aldri fasitblokkene». Men fasiten ligger jo i filene den kan lese. Er dette en sikker måte å skjule fasit på? *(Nei. Det er en instruks, ikke en sperre. Til øving er det greit, men til eksamen må fasiten ligge et annet sted.)*

---

## 5. Skillene

### `nytt-tema`: oppskrift med mal

En skill kan ha med seg filer. Denne har `mal.md`, en ferdig temamal med frontmatter, mål, eksempel, vanlige feil, oppgaver med `**Fasit:**` og lærernotat. Skillen viser til malen med en relativ lenke: `[mal.md](./mal.md)`.

**Prøv:** `/nytt-tema i emnet microsoft-fabric om Delta-tabeller og tidsreise`

### `sjekk-innhold`: skill med skript

Noen ting skal være **nøyaktige**, ikke vurderinger. Da er et skript bedre enn at AI-en sjekker selv. Skriptet kontrollerer:

- at mappe- og filnavn bare har små bokstaver, tall og bindestrek
- at `emne.json` og frontmatter har `title`, `description` og `order`
- at ingen temaer i samme emne har lik `order`
- at bilder har alt-tekst, og at bildefilene finnes
- at alle emner står på forsiden

Du kan også kjøre skriptet selv, uten AI:

```powershell
node .github/skills/sjekk-innhold/scripts/sjekk-innhold.mjs
```

```text
4 emne(r) sjekket: 0 feil, 0 advarsler.
```

**Prøv:** `/sjekk-innhold`

### `lag-quiz`: lag øvingsspørsmål fra innholdet

Lager spørsmål **bare** fra det som står i temaene, i portalens format (`**1. (F, 1 p)**` og `**Fasit:**`), slik at fasiten automatisk skjules hvis quizen lagres som tema.

**Prøv:** `/lag-quiz fra temaet om indeksering i Datavarehus, bare i chatten`

### `publiser-endringer`: bare når du ber om det

```markdown
---
name: publiser-endringer
description: Fører brukeren trygt gjennom publisering av endringer ...
disable-model-invocation: true
---
```

`disable-model-invocation: true` betyr at agenten **aldri** starter denne skillen av seg selv. Den kjøres bare når du skriver `/publiser-endringer`. Det er riktig for alt som har konsekvenser for andre, som publisering. Skillen stopper også og ber om et tydelig ja før `git commit` og `git push`, og den bruker aldri kommandoer som sletter historikk.

**Prøv:** Gjør en liten endring i `content/forside.md`, og skriv `/publiser-endringer`. Svar *nei* når den spør om bekreftelse, hvis du ikke vil publisere ennå.

---

## 6. Lag din egen agent for portalen: oppskrift

Bruk denne fremgangsmåten når du vil lage en ny agent, for eksempel «Oversetter» eller «Eksamenstrener»:

1. **Beskriv rollen i én setning.** *«Oversetter et tema til engelsk og lagrer det som et nytt emne.»*
2. **Bestem verktøyene.** Må den endre filer (`edit`)? Kjøre kommandoer (`execute`)? Velg så få som mulig.
3. **Finn kunnskapen.** Hvilke filer i portalen skal den lese? Vis til dem i stedet for å kopiere innholdet.
4. **Gjenbruk skills.** Kan den bruke `nytt-tema`, `sjekk-innhold` eller `lag-quiz`? Legg dem i `skills:`.
5. **Skriv arbeidsflyten** med nummererte steg, og bestem **når den skal stoppe og spørre**.
6. **Skriv begrensningene.** Hva skal den aldri gjøre?
7. **Test** med 2–3 typiske forespørsler i nye chatter, og forbedre én regel om gangen.
8. **Del** ved å committe filen i `.github/agents/`.

### Idébank

| Agent eller skill | Rolle | Verktøy | Gjenbruker |
|---|---|---|---|
| Eksamenstrener (agent) | Stiller muntlige eksamensspørsmål fra et emne, ett om gangen, og gir tilbakemelding | `read`, `search` | `lag-quiz` |
| Oversetter (agent) | Oversetter et emne til engelsk som et nytt emne | `read`, `search`, `edit`, `execute` | `nytt-tema`, `sjekk-innhold` |
| Ordliste (skill) | Lager en ordliste over fagbegreper i et emne | – | – |
| Lenkesjekker (skill med skript) | Sjekker at lenker mellom temaer peker på filer som finnes | – | – |
| Fabric-kilde (agent) | Svarer med kilde fra Microsoft-dokumentasjonen | `read`, `search`, `microsoftLearn/*` | – (se tema 4) |

---

## Oppgaver

**Oppgave 1:** Hvorfor har Innholdsgjennomgåer `execute`, men ikke `edit`?

**Fasit:** Den trenger `execute` for å kjøre kontrollskriptet (`sjekk-innhold`) og `git diff`, men den skal bare gi tilbakemelding. Uten `edit` kan den ikke endre filer, uansett hva instruksjonene sier.

**Oppgave 2:** Lag agenten **Eksamenstrener** fra idébanken. Den skal stille ett spørsmål om gangen fra et emne brukeren velger, vente på svar, gi tilbakemelding og en poengsum til slutt.

**Fasit:** Et godt svar har:

```markdown
---
name: Eksamenstrener
description: Øver studenter til muntlig eksamen ved å stille spørsmål fra et emne i kursportalen, ett om gangen, med tilbakemelding.
tools: ['read', 'search']
skills: ['lag-quiz']
---

Du er en vennlig sensor som øver studenter til muntlig eksamen.

## Arbeidsflyt
1. Spør hvilket emne i content/ studenten vil øve på, og hvor mange spørsmål (standard 5).
2. Les temaene i emnet. Bruk skillen lag-quiz til å lage spørsmålene, men vis dem ikke.
3. Still ett spørsmål om gangen, og vent på svar.
4. Gi tilbakemelding: riktig, delvis riktig eller feil, en kort forklaring, og hvilket tema studenten bør lese.
5. Til slutt gir du poengsum og de tre viktigste tingene å repetere.

## Regler
- Avslør aldri svaret før studenten har svart.
- Bruk bare innhold fra kursportalen.
```

Test den i en ny chat: velg **Eksamenstrener** og skriv *«Øv meg på Microsoft Fabric»*.

**Oppgave 3:** Lag skillen `ordliste` fra idébanken, og test den med `/ordliste for emnet SAP Analytics Cloud`.

**Fasit:** Lag `.github/skills/ordliste/SKILL.md` med `name: ordliste` (likt mappenavnet) og en beskrivelse som *«Lager en ordliste over fagbegreper i et emne i kursportalen. Bruk når brukeren ber om ordliste, begrepsliste eller forklaring av fagord i et emne.»* Instruksjonene bør si: les alle temaene i emnet, finn fagbegreper, lag en alfabetisk tabell med begrep og forklaring på én linje, og vis til temaet der begrepet forklares. Sjekk at skillen dukker opp når du skriver `/`.

> **Lærernotat:** La gjerne studentene teste SQL-veileder på hverandre: én spiller student og prøver å lure agenten til å gi fasit, og én observerer. Det gir en god diskusjon om forskjellen på instrukser og sperrer, og om ansvarlig bruk av AI i læring.
