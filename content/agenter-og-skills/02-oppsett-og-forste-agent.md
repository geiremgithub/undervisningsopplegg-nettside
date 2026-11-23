---
title: "Oppsett og din første agent"
description: "Installer det du trenger, og lag, test og forbedre din første agent steg for steg på 15 minutter."
order: 2
---

# Oppsett og din første agent

**Mål:** Etter dette temaet har du Copilot klart i VS Code, og du har laget, testet og forbedret en egen agent.

**Tid:** ca. 30 minutter, inkludert oppsett.

---

## 1. Dette trenger du

| Hva | Hvorfor | Slik får du det |
|---|---|---|
| **VS Code** | Editoren der agentene kjører | <https://code.visualstudio.com> |
| **GitHub-konto** | Copilot er knyttet til GitHub-kontoen | <https://github.com/signup> |
| **Tilgang til GitHub Copilot** | Selve AI-assistenten | Gratisversjonen *Copilot Free* holder til å starte. Verifiserte studenter kan få mer gratis gjennom **GitHub Education** (<https://education.github.com>). Sjekk gjeldende vilkår. |
| **Et prosjekt å jobbe i** | Agenter lagres i prosjektmappen | Bruk denne kursportalen. Se *VEILEDNING-git-og-publisering.md* for hvordan du laster den ned. |

## 2. Koble Copilot til VS Code

1. Åpne VS Code.
2. Klikk på **Copilot-ikonet** øverst i vinduet, eller åpne chatten med `Ctrl + Alt + I`.
3. Velg **Sign in** og logg inn med GitHub-kontoen. Følg stegene i nettleseren.
4. Åpne prosjektmappen med **File → Open Folder…**.
5. Øverst i chatvinduet velger du **Copilot** under **Session Target**.

**Test:** Skriv `Hva gjør dette prosjektet?` i chatten. Får du et svar som handler om kursportalen, er alt klart.

---

## 3. Lag din første agent: «Forklarer»

Vi lager en agent som forklarer filer i prosjektet for en nybegynner. Den skal **bare lese** og aldri endre noe.

### Steg 1: Opprett agentfilen

1. Trykk `Ctrl + Shift + P` og kjør **Chat: Open Customizations**.
2. Velg fanen **Agents**.
3. Klikk **+** (New Agent) ved **Workspace**.
4. Skriv filnavnet `forklarer`.

VS Code lager filen `.github/agents/forklarer.agent.md` og åpner den.

> Du kan også lage filen selv i den mappen. Filnavnet må slutte på `.agent.md`.

### Steg 2: Skriv agenten

Erstatt innholdet med dette:

```markdown
---
name: Forklarer
description: Forklarer filer og kode i prosjektet for nybegynnere, uten å endre noe.
tools: ['read', 'search']
---

Du forklarer filer og kode for studenter som er nye i programmering.

## Slik svarer du
1. Start med én setning om hva filen eller koden er til for.
2. Forklar de viktigste delene ovenfra og ned, med enkle ord.
3. Avslutt med én ting nybegynnere ofte misforstår her.

## Regler
- Endre aldri filer.
- Forklar fagord første gang du bruker dem.
- Er du usikker, si det i stedet for å gjette.
```

Lagre med `Ctrl + S`.

**Hva betyr delene?**

| Del | Forklaring |
|---|---|
| `---` … `---` | *Frontmatter*: innstillingene for agenten |
| `name` | Navnet du ser i agentlisten |
| `description` | Hva agenten gjør. Brukes også når andre agenter skal velge den. |
| `tools: ['read', 'search']` | Agenten kan bare **lese** og **søke**. Den har ikke `edit` (endre filer) eller `execute` (kjøre kommandoer). |
| Teksten under | Instruksjonene agenten følger: rolle, fremgangsmåte og regler |

### Steg 3: Sjekk at VS Code har funnet agenten

1. I **Chat: Open Customizations → Agents** skal **Forklarer** stå i listen, uten feilmerke.
2. Start en **ny chat** med **+**-knappen øverst i chatvinduet.
3. Åpne nedtrekksmenyen **Agent** under skrivefeltet, og velg **Forklarer**.

### Steg 4: Test agenten

Skriv:

```text
Forklar filen site.config.json
```

**Sjekk svaret:**

- [ ] Starter det med én setning om hva filen er til for?
- [ ] Er fagord som *JSON* forklart?
- [ ] Står det en «vanlig misforståelse» til slutt?
- [ ] Se på **verktøybruken** i chatten (linjene om hva agenten gjorde). Har den bare lest filer, og ikke endret noe?

Prøv også å be den gjøre noe den ikke skal:

```text
Endre tittelen i site.config.json til "Min portal"
```

Agenten bør si nei, eller forklare at den ikke kan endre filer. Den har ikke verktøyet `edit`.

> 🔒 **Viktig å forstå:** Det er **verktøylisten** som faktisk hindrer agenten i å endre filer. Setningen «Endre aldri filer» er bare en instruks, og en instruks er ingen garanti. Vil du være sikker på at en agent ikke gjør noe, tar du bort verktøyet.

### Steg 5: Forbedre agenten

Agenter blir gode av å bli prøvd og justert. Gjør én endring om gangen:

1. Se på svaret og finn én ting som kunne vært bedre, for eksempel at det var for langt.
2. Legg til én regel, for eksempel `- Hold svaret under 15 linjer.`
3. Lagre, start en **ny chat**, velg agenten og still **samme spørsmål** igjen.
4. Sammenlign. Ble det bedre? Behold regelen. Ble det ikke det? Fjern den og prøv noe annet.

> 💡 Start alltid en ny chat når du tester en endring. En gammel chat husker det som ble sagt tidligere, og da ser du ikke effekten av endringen.

### Steg 6: Del agenten

Agenten ligger i prosjektet (`.github/agents/`). Når du committer og pusher filen, får alle som jobber i prosjektet den samme agenten. Se *VEILEDNING-git-og-publisering.md*.

---

## 4. La Copilot hjelpe deg å lage agenter

Du kan også be Copilot lage et utkast, og så justere det selv:

```text
Lag en workspace-agent i .github/agents/ som heter Ordlisteskriver.
Den skal lese et tema i content/ og lage en ordliste med fagbegrepene
og en enkel forklaring av hvert. Den skal bare lese og søke, ikke endre filer.
```

Les alltid gjennom det som lages, særlig **verktøylisten**, før du tar agenten i bruk.

---

## 5. Hurtigoversikt: kommandoer i VS Code

| Det du vil | Slik gjør du det |
|---|---|
| Se, lage og redigere agenter og skills | `Ctrl + Shift + P` → **Chat: Open Customizations** |
| Lage en ny agent direkte | `Ctrl + Shift + P` → **Chat: New Custom Agent** |
| Velge agent | Nedtrekksmenyen **Agent** under skrivefeltet i chatten |
| Bruke en skill direkte | Skriv `/` i chatten og velg skillen |
| Starte en ny chat | **+** øverst i chatvinduet |

---

## Oppgave

**Oppgave 1:** Gjør om Forklarer-agenten til en «Engelsklærer» som forklarer på engelsk, med en norsk ordliste nederst. Test den på `content/forside.md`.

**Fasit:** Endre `name` og `description`. Legg til regelen «Svar på engelsk.» og et nytt punkt 4 i «Slik svarer du»: «Avslutt med en ordliste med de 5 vanskeligste ordene oversatt til norsk.» Behold `tools: ['read', 'search']`. Start en ny chat, velg agenten og skriv `Explain content/forside.md`.

> **Lærernotat:** Det vanligste problemet er at studentene ikke starter ny chat, eller ikke bytter agent i nedtrekksmenyen. Be dem vise frem agentlisten i **Chat: Open Customizations** hvis agenten «ikke finnes».
