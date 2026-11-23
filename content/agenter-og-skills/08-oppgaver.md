---
title: "Øvingsoppgaver og sjekkliste"
description: "Sju øvingsoppgaver med fasit, fra første skill til et helt agentteam for kursportalen, og sjekklister."
order: 8
---

# Øvingsoppgaver og sjekkliste

**Mål:** Du øver på å lage, teste og forbedre agenter og skills, fra enkle til sammensatte.

Oppgave 1–3 er **grunnleggende**, 4–5 **viderekommen** og 6–7 **utfordring**. Gjør oppgavene i kursportalen, så har du ekte innhold å teste på.

---

## 9. Øvingsoppgaver

### Oppgave 1: Din første skill (15 min) 🟢

Lag en personlig skill `forklar-kode` som forklarer valgt kode for en nybegynner:

- først én setning om *hva* koden gjør
- deretter linje for linje
- til slutt én ting nybegynnere ofte misforstår

**Test:** Åpne `src/progress.js`, marker en funksjon og skriv `/forklar-kode`. Prøv deretter uten skråstrek: *«forklar denne koden»*.

**Fasit:** Opprett skillen med **Chat: Open Customizations → Skills → + ved User**, eller lag `~/.copilot/skills/forklar-kode/SKILL.md`:

```markdown
---
name: forklar-kode
description: Forklarer markert kode linje for linje for nybegynnere. Bruk når brukeren ber om å forklare, gå gjennom eller forstå kode.
---

# Forklar kode

1. Start med én setning om hva koden gjør.
2. Forklar linje for linje i en tabell (linje → hva skjer), med enkle ord.
3. Avslutt med «Vanlig misforståelse:» og én ting nybegynnere ofte tar feil av.
4. Forklar fagord første gang de brukes.
```

Virker `/forklar-kode`, men ikke «forklar denne koden», bør du legge flere nøkkelord i `description`.

---

### Oppgave 2: Skill med skript (30 min) 🟢

Lag skillen `sjekk-passord` med et Python-skript som vurderer om et passord er sterkt (lengde, tall, spesialtegn). Skillen skal *alltid* bruke skriptet og aldri vurdere selv.

**Fasit:** Mappen `.github/skills/sjekk-passord/` har `SKILL.md` og `scripts/sjekk.py`. I `SKILL.md` står det tydelig: *«Kjør `python scripts/sjekk.py "<passord>"`. Ikke vurder passordet selv.»* Skriptet sjekker minst `len(p) >= 12`, `any(c.isdigit() for c in p)` og om det finnes tegn som ikke er bokstaver eller tall, og skriver ut «sterkt» eller «svakt» med begrunnelse. Godt poeng: Skillen bør si at ekte passord **ikke** skal limes inn i chatten.

---

### Oppgave 3: Read-only agent (20 min) 🟢

Lag agenten **Portalhjelp**, som bare har verktøyene `read` og `search`, og som svarer på spørsmål om hvordan kursportalen brukes ut fra `README.md` og `VEILEDNING-*.md`. Den skal svare «Det står ikke i dokumentasjonen» når svaret mangler.

**Refleksjon:** Hva skjer hvis du ber den endre en fil? Hvorfor?

**Fasit:**

```markdown
---
name: Portalhjelp
description: Svarer på spørsmål om hvordan kursportalen brukes og vedlikeholdes, ut fra README og veiledningene.
tools: ['read', 'search']
---

Du svarer på spørsmål om kursportalen.

1. Søk i README.md og VEILEDNING-*.md.
2. Svar kort, og oppgi filen og kapitlet svaret står i.
3. Finner du ikke svaret, skriver du nøyaktig: «Det står ikke i dokumentasjonen.»
```

Ber du den endre en fil, kan den ikke gjøre det, fordi den mangler verktøyet `edit`. Den kan bare foreslå endringen.

---

### Oppgave 4: Planlegg og utfør (45 min) 🟡

Lag agentene **Testskriver** og **Implementerer** for kursportalen:

- Testskriver leser et krav og skriver **bare** nye tester i `tests/`. Den kjører testene og viser at de feiler (rødt).
- Implementerer får testene og endrer koden i `src/` til testene passerer (grønt).

Bruk dem på kravet: *«Forsiden skal vise antall temaer totalt i alle emner.»*

**Fasit:** Testskriver har `tools: ['read', 'search', 'edit', 'execute']`, men en instruks om å bare endre filer i `tests/`, og en avslutning som: *«Bytt til Implementerer og skriv: Få testene over til å passere.»* Implementerer har de samme verktøyene og en arbeidsflyt som: kjør `npm test`, endre minst mulig i `src/`, kjør `npm test` til alt er grønt, og ikke endre testene. Du bytter agent selv i samme chat. (`handoffs` virker bare i den gamle Local-modusen.)

**Diskusjon:** Begge har `edit`. Hva hindrer Testskriver i å endre `src/`? *(Bare instruksjonen. Derfor må du se over endringene.)*

---

### Oppgave 5: Agent som bruker kursportalens skills (45 min) 🟡

Lag agenten **Oversetter**, som oversetter et emne i kursportalen til engelsk og lagrer det som et nytt emne, `content/<emne>-en/`. Den skal bruke skillene `nytt-tema` og `sjekk-innhold`.

**Fasit:**

```markdown
---
name: Oversetter
description: Oversetter et emne i kursportalen til engelsk og lagrer det som et nytt emne med -en i mappenavnet.
tools: ['read', 'search', 'edit', 'execute']
skills: ['nytt-tema', 'sjekk-innhold']
---

1. Spør hvilket emne som skal oversettes.
2. Lag content/<emne>-en/emne.json med oversatt title og description, og order like etter originalen.
3. Oversett hvert tema til en fil med samme filnavn. Behold koden, men oversett kommentarene.
   Behold **Fasit:** og **Lærernotat:** på norsk, så portalen fortsatt skjuler dem.
4. Kjør sjekk-innhold og npm run build. Rett feil.
5. Ikke endre originalemnet.
```

Et ekstra godt poeng: Portalen kjenner bare igjen de norske ordene **Fasit** og **Lærernotat**. Derfor må de stå på norsk, ellers vises fasiten åpent.

---

### Oppgave 6: Leder med subagenter (60 min) 🔴

Lag agenten **Redaktør**, som lager et nytt tema ved å bruke **Kursforfatter** som subagent, deretter **Innholdsgjennomgåer** som subagent, og som sender funnene tilbake til Kursforfatter til konklusjonen er `KLAR FOR PUBLISERING`, med maks 2 runder.

**Fasit:** `tools: ['read', 'search', 'agent', 'todo']`, ingen `edit`. Arbeidsflyten nevner agentnavnene nøyaktig. Hver delegering forteller hva subagenten skal gjøre, hvilke filer det gjelder, og hva den skal levere tilbake. Det må stå at Redaktør selv **ikke** endrer filer, og at den viser resultatet til brukeren før noe annet skjer. Sjekk i chatten at subagentene faktisk ble startet.

---

### Oppgave 7: Agentteam for et prosjekt (gruppe, 90 min) 🔴

Velg ett av emnene i kursportalen, for eksempel Microsoft Fabric. Lag et lite «team» som hjelper studentene i det emnet:

- 1 instruksjonsfil som gjelder emnet (`.github/instructions/<emne>.instructions.md` med `applyTo: "content/<emne>/**"`)
- 2 skills, for eksempel `ordliste` og `lag-quiz`-variant for emnet
- 2 agenter, for eksempel en veileder og en eksamenstrener
- valgfritt: en MCP-server for kilder, som Microsoft Learn

**Presenter for klassen:**

1. Hvilke valg tok dere, og hvorfor ble noe en skill og noe annet en agent?
2. Vis verktøylistene. Hvorfor har hver agent akkurat de verktøyene?
3. Vis én test der agenten gjorde feil, og hvordan dere forbedret den.

> **Lærernotat:** Vurder særlig punkt 2 og 3. At studentene kan begrunne verktøyvalg og vise en forbedringssløyfe, er viktigere enn hvor mange filer de har laget.

---

## 10. Sjekklister

### Før du tar i bruk en skill

- [ ] Mappen og `name` har samme navn (små bokstaver og bindestrek)
- [ ] Filen heter nøyaktig `SKILL.md` og ligger i `.github/skills/<navn>/` eller `~/.copilot/skills/<navn>/`
- [ ] `description` sier **hva** og **når** («Bruk når …»)
- [ ] Instruksjonene er konkrete og nummererte
- [ ] Det som må være nøyaktig, gjøres av et skript
- [ ] Skills med konsekvenser (publisering, sletting) har `disable-model-invocation: true`
- [ ] Ingen hemmeligheter
- [ ] Testet både med `/navn` og med en vanlig forespørsel, i en ny chat

### Før du tar i bruk en agent

- [ ] Filen slutter på `.agent.md` og ligger i `.github/agents/` eller `~/.copilot/agents/`
- [ ] `description` beskriver tydelig hva agenten gjør og når den skal brukes
- [ ] `tools` er begrenset til det agenten faktisk trenger
- [ ] Instruksjonene har rolle, arbeidsflyt, svarformat og begrensninger
- [ ] Det står når agenten skal **stoppe og spørre**
- [ ] Ingen `handoffs` eller `agents:` hvis du bruker Copilot-modus
- [ ] Testet i en ny chat med **Copilot** valgt. Svaret og verktøybruken er sjekket.

---

## Videre lesning

- VS Code: *Custom agents*: <https://code.visualstudio.com/docs/agent-customization/custom-agents>
- VS Code: *Agent Skills*: <https://code.visualstudio.com/docs/agent-customization/agent-skills>
- VS Code: *Custom instructions*: <https://code.visualstudio.com/docs/agent-customization/custom-instructions>
- VS Code: *MCP servers*: <https://code.visualstudio.com/docs/agent-customization/mcp-servers>
- VS Code: *Subagents*: <https://code.visualstudio.com/docs/agents/run/subagents>
- Den åpne standarden for skills: <https://agentskills.io>
- Eksempler fra fellesskapet: <https://github.com/github/awesome-copilot>
- Ekte eksempler: mappen `.github/` i denne kursportalen (tema 6)

> **Lærernotat:** La studentene starte med tema 2 (første agent) og oppgave 1 og 3. Da opplever de raskt forskjellen mellom en skill (kunnskap ved behov) og en agent (rolle med begrensede verktøy). Copilot og VS Code endres ofte. Sjekk menynavnene mot dokumentasjonen over før kurset.
