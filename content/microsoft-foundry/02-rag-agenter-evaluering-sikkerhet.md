---
title: "RAG, agenter, evaluering og sikkerhet"
description: "Bygg en RAG-løsning og en agent i Foundry, evaluer kvaliteten, og sikre prosjektet med Entra ID, roller, innholdsfiltre og nettverk."
order: 2
---

# RAG, agenter, evaluering og sikkerhet

**Mål:** Du kan bygge en RAG-løsning og en agent i Foundry, måle kvaliteten med evaluering, og sette opp tilgang og sikkerhet på en forsvarlig måte.

**Forkunnskaper:** Tema 1 i dette emnet og emnet *RAG-løsninger*.

---

## 1. RAG i Foundry med Azure AI Search

I emnet *RAG-løsninger* bygde du kjeden selv. I Azure gjør tjenestene det meste for deg:

```text
 Dokumenter (Blob Storage)
        │
        ▼
 Azure AI Search  ── indekserer: chunking ① + embedding ③ (via deployment i Foundry) + vektorindeks ④
        │                                           hybridsøk: vektor + nøkkelord + semantisk rangering
        ▼
 Foundry-agent eller -app  ── henter relevante chunks og lar språkmodellen ⑤ svare med kilder
```

**Steg for steg (i portalen):**

1. Last opp dokumentene til en container i **Azure Blob Storage**.
2. Deploy en **embedding-modell** (for eksempel `text-embedding-3-small`) og en **chatmodell** i Foundry-prosjektet.
3. Opprett en **Azure AI Search**-tjeneste, og kjør veiviseren **Import data (new)** for vektorer. Den lager chunking, embedding og indeks for deg. (Se videoen *Create a Vector RAG Index in Minutes* i videotemaet.)
4. Legg til Azure AI Search som **tilkobling** i Foundry-prosjektet.
5. Lag en **agent** (avsnitt 2), og gi den søkeindeksen som kunnskapskilde.
6. Test i **Playground**: Sjekk at svarene har kilder, og at spørsmål utenfor dokumentene gir «vet ikke».

---

## 2. Agenter

En **agent** i Foundry er en modell, instruksjoner og verktøy som sammen kan resonnere og handle.

| Type | Hvordan | Når |
|---|---|---|
| **Prompt agent** (deklarativ) | Velg modell, skriv instruksjoner og legg til verktøy i portalen eller SDK-en. Foundry kjører agenten for deg. | De fleste behov. Start her. |
| **Hosted agent** (kode) | Egen kode (for eksempel Microsoft Agent Framework, LangGraph eller Semantic Kernel) i en container som Foundry kjører | Når du trenger full kontroll over logikken |

**Verktøy en agent kan få:** Azure AI Search (RAG), filsøk, kodekjøring, nettsøk, egne funksjoner (API-er) og **MCP-servere** (se emnet *MCP-server*).

**Eksempel på instruksjoner for en RAG-agent:**

```text
Du er en assistent for personalhåndboken i Nordlys Sport.
- Svar bare ut fra kunnskapskilden. Oppgi dokument og avsnitt for hvert svar.
- Står svaret ikke i kilden, si «Det finner jeg ikke i personalhåndboken»
  og henvis til HR.
- Gi aldri personopplysninger om ansatte.
- Svar på norsk, kort og vennlig.
```

---

## 3. Evaluering: mål kvaliteten, ikke gjett

En KI-løsning må **måles** før den settes i drift, og hver gang noe endres (modell, prompt, chunking).

**Fremgangsmåte:**

1. Lag et **testsett**: 20–100 spørsmål med forventet svar eller fasit, gjerne i en JSONL-fil.
2. Kjør løsningen på alle spørsmålene.
3. La **evaluatorene** score svarene.
4. Sammenlign versjoner. Endre én ting om gangen.

| Evaluator | Spør | Viktig for |
|---|---|---|
| **Groundedness** | Er svaret basert på de hentede kildene? | RAG: avslører hallusinasjoner |
| **Relevance** | Svarer det på spørsmålet? | Alle løsninger |
| **Retrieval** | Ble de riktige chunkene hentet? | RAG: avslører problemer med chunking og søk |
| **Coherence / Fluency** | Er svaret sammenhengende og godt formulert? | Brukeropplevelse |
| **Safety** (sikkerhet) | Inneholder svaret skadelig innhold? | Alle løsninger |
| **Task adherence / Tool call accuracy** | Fulgte agenten oppgaven og brukte riktige verktøy? | Agenter |

I tillegg finnes:
- **Tracing (sporing):** Se hvert steg i et agentkall: hvilke verktøy som ble brukt, hvilke chunks som ble hentet, og hva modellen fikk og svarte.
- **Red teaming:** Automatiserte «angrep» på løsningen, for eksempel prompt injection og forsøk på å få frem skadelig innhold, for å finne svakheter før andre gjør det.
- **Overvåking i drift:** Fortløpende evaluering av ekte trafikk.

---

## 4. Sikkerhet og administrasjon

| Område | Tiltak | Hvorfor |
|---|---|---|
| **Identitet** | Bruk **Microsoft Entra ID** og *managed identity* for apper. Skru gjerne **av** innlogging med API-nøkler (*local auth*). | Nøkler kan lekke og gir full tilgang til den som har dem |
| **Tilgang (RBAC)** | Gi minste nødvendige rolle. For eksempel **Foundry User** (tidligere *Azure AI User*) for å bruke modeller og agenter, og administratorroller bare for dem som skal sette opp ressursen. Merk at **Owner** og **Contributor** ikke gir tilgang til å kalle modeller. | Prinsippet om minste privilegium |
| **Nettverk** | **Private endpoints** og avslått offentlig tilgang for produksjon | Trafikk går ikke over internett |
| **Innholdsfiltre** | Filtre for hat, vold, seksuelt innhold og selvskading, **Prompt Shields** mot prompt injection og jailbreak, og **groundedness detection** | Stopper skadelig input og output |
| **Data** | Velg deployment-type etter krav til dataplassering (tema 1). Krypter med egne nøkler (CMK) ved behov. | Personvern og regelverk |
| **Styring** | **Azure Policy** (for eksempel «tillat bare godkjente modeller» eller «krev private endpoints»), og logging til Azure Monitor | Kontroll i stor skala |
| **Kostnad** | Kvoter (tokens per minutt) per deployment, budsjettvarsler, og sletting av ubrukte ressurser | Hindrer overraskende regninger |

> ⚠️ **Fra virkeligheten:** En lekket nøkkel til en tjeneste med en Foundry-modell bak kan gi andre gratis bruk av modellen, på *din* regning. Bruk derfor Entra ID i stedet for nøkler. Hvis nøkler likevel brukes: oppbevar dem i Azure Key Vault, regenerer dem jevnlig og straks ved mistanke om lekkasje, og slett ressurser som ikke er i bruk.

---

## Oppgaver

**Oppgave 1:** RAG-løsningen deres får høy score på *Relevance*, men lav på *Groundedness*. Hva betyr det, og hva gjør du?

**Fasit:** Svarene handler om spørsmålet, men er ikke basert på kildene. Modellen bruker egen kunnskap eller hallusinerer. Tiltak: strengere instruks («svar KUN ut fra kildene, ellers si at du ikke vet»), sjekk med *Retrieval*-evaluatoren om riktige chunks faktisk blir hentet, og senk temperaturen.

**Oppgave 2:** En utvikler har lagt API-nøkkelen til Foundry i `appsettings.json` og pushet den til GitHub. Hva gjør dere, i riktig rekkefølge?

**Fasit:** (1) **Regenerer nøkkelen umiddelbart**, slik at den lekkede blir ugyldig. (2) Sjekk bruk og kostnader i perioden nøkkelen var ute. (3) Fjern nøkkelen fra koden, og helst fra Git-historikken. (4) Gå over til Entra ID eller managed identity, og vurder å skru av nøkkelinnlogging. Ellers: legg nøkkelen i Key Vault. (5) Aktiver *secret scanning* i GitHub.

**Oppgave 3:** Hvilken type agent velger du for en enkel FAQ-bot over personalhåndboken, og hvorfor?

**Fasit:** En **prompt agent** med Azure AI Search som kunnskapskilde. Den krever ingen egen kode eller container, Foundry drifter den, og den dekker behovet. En hosted agent er bare nødvendig ved kompleks egen logikk.

> **Lærernotat:** Oppgave 2 er basert på et reelt scenario: en APIM-instans med Foundry bak, der en lekket abonnementsnøkkel kunne gitt kostnader. Det gir en god diskusjon om hvorfor nøkkelfri innlogging er standardanbefalingen.
