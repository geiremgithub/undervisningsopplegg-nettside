---
title: "Oppbygning og modeller"
description: "Hva Microsoft Foundry er, ressurs og prosjekter, modellkatalogen, deployment-typer og ditt første modellkall."
order: 1
---

# Oppbygning og modeller

**Mål:** Etter dette temaet kan du forklare hvordan Microsoft Foundry er bygd opp, velge og deploye en modell fra katalogen, og kalle den fra kode.

**Forkunnskaper:** En Azure-konto. Emnet *RAG-løsninger*, tema 1, er en fordel.

> **Navnebytte:** *Azure AI Studio* ble til *Azure AI Foundry* (2024), og heter nå **Microsoft Foundry** (fra november 2025). Mange videoer og artikler bruker fortsatt de gamle navnene. Det er samme plattform.

---

## 1. Hva er Microsoft Foundry?

Microsoft Foundry samler det du trenger for å lage KI-løsninger på ett sted, i én Azure-ressurs:

| Del | Hva den gir deg |
|---|---|
| **Modeller** | En katalog med over 10 000 modeller fra Microsoft, OpenAI, Anthropic, Meta og andre |
| **Agenter** | Foundry Agent Service: agenter som kombinerer modell, instruksjoner og verktøy |
| **Verktøy og kunnskap** | Søk (blant annet Azure AI Search for RAG), kodekjøring, MCP-servere og minne |
| **Observability** | Sporing (*tracing*), evaluering og overvåking |
| **Styring og sikkerhet** | Microsoft Entra ID, rollebasert tilgang (RBAC), innholdsfiltre, nettverksisolasjon og Azure Policy |

Du jobber med Foundry gjennom **portalen** <https://ai.azure.com>, **SDK-er** (Python, C#, JavaScript og Java), **Azure Developer CLI** (`azd`) eller **VS Code** med Foundry-utvidelsen.

---

## 2. Oppbygning: ressurs og prosjekter

```text
Azure-abonnement (subscription)
└── Ressursgruppe
    └── Foundry-ressurs              ← én Azure-ressurs: tilgang, nettverk, policy, kostnad
        ├── Modell-deployments       ← f.eks. gpt-4o-mini, text-embedding-3-small
        ├── Tilkoblinger             ← f.eks. Azure AI Search, Storage
        ├── Prosjekt: «hr-assistent»   ← arbeidsområde for ett team eller én løsning
        │     ├── Agenter
        │     ├── Evalueringer og sporing
        │     └── Filer og data
        └── Prosjekt: «kundeservice»
```

| Begrep | Forklaring |
|---|---|
| **Foundry-ressurs** | Azure-ressursen som holder alt sammen. Tilgang, nettverk og policyer settes her og gjelder alle prosjektene. |
| **Prosjekt** | Et arbeidsområde for én løsning eller ett team, med egne agenter, evalueringer og filer |
| **Deployment** | En modell som er gjort tilgjengelig med et navn du velger, og som du kaller fra kode |
| **Prosjektendepunkt** | Én adresse per prosjekt som SDK-er og `OpenAI()`-klienten kobler seg til |

> **Hub-baserte prosjekter** er den eldre modellen (*Foundry classic*). De finnes fortsatt, men nye løsninger bør bruke Foundry-ressurs med prosjekter.

---

## 3. Modellkatalogen: velg riktig modell

I portalen: **Models** (modellkatalogen). Du kan filtrere på leverandør, oppgave (chat, embeddings, bilde, tale), og **sammenligne** modeller på kvalitet, pris og hastighet (*benchmarks*).

| Behov | Typisk modelltype | Eksempel |
|---|---|---|
| Chat, oppsummering og RAG-svar | Chat- eller språkmodell | GPT-4o-mini, GPT-4.1, Phi, Llama, Mistral |
| Gjøre tekst om til vektorer (RAG) | Embedding-modell | text-embedding-3-small eller -large |
| Krevende resonnering | Resonneringsmodell (*reasoning*) | o-serien og tilsvarende |
| Billig, rask og liten | Small Language Model (SLM) | Phi-familien |

**Tips for valg:** Start med en **liten og billig** modell, mål kvaliteten med evaluering (tema 2), og gå bare opp i størrelse når målingene viser at det trengs.

---

## 4. Deployment: gjør modellen tilgjengelig

Når du deployer en modell, velger du **deployment-type**. Den bestemmer *hvor* data behandles, *hvordan* du betaler og hvilken *ytelse* du får.

| Type | Betaling | Hvor data behandles | Når |
|---|---|---|---|
| **Global Standard** | Per token | Hvilken som helst Azure-region | **Start her.** Lavest pris, nye modeller kommer her først. |
| **Data Zone Standard** | Per token | Innenfor en sone (for eksempel EU) | Krav om at data skal behandles i EU |
| **Standard** (regional) | Per token | Valgt geografi | Strenge krav til dataplassering |
| **Provisioned** (PTU) | Reservert kapasitet | Global, Data Zone eller regional | Stabil og høy trafikk med krav til forutsigbar ytelse |
| **Batch** | Rabattert, per token | Global eller Data Zone | Store jobber som kan vente, for eksempel å klassifisere 100 000 dokumenter |

> Data som er **lagret** blir værende i valgt Azure-geografi. Det er *behandlingen* av forespørsler (inferens) som kan skje andre steder med Global-typene. Har virksomheten krav om at data skal behandles i EU, velger du **Data Zone (EU)**.

Åpne modeller (for eksempel fra Hugging Face) kan også kjøres på **managed compute**, det vil si virtuelle maskiner du betaler for per time. Da gjelder ikke tabellen over.

**Slik deployer du i portalen:**

1. Åpne prosjektet på <https://ai.azure.com>.
2. **Models** → velg en modell, for eksempel `gpt-4o-mini` → **Deploy**.
3. Gi deploymenten et navn, velg type (**Global Standard**) og kvote (tokens per minutt).
4. Prøv modellen i **Playground**.

---

## 5. Ditt første modellkall fra kode

Foundry kan kalles med den vanlige `openai`-pakken mot prosjektets endepunkt. Innlogging skjer med **Microsoft Entra ID**, slik at du slipper API-nøkler:

```powershell
pip install openai azure-identity
az login
```

```python
import os
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

token = get_bearer_token_provider(DefaultAzureCredential(), "https://ai.azure.com/.default")

klient = OpenAI(
    base_url=os.environ["FOUNDRY_OPENAI_ENDPOINT"],  # f.eks. https://<ressursnavn>.openai.azure.com/openai/v1/
    api_key=token,  # gir et nytt token automatisk ved hvert kall
)

svar = klient.chat.completions.create(
    model="gpt-4o-mini",  # navnet på DIN deployment
    messages=[{"role": "user", "content": "Forklar RAG med én setning."}],
)
print(svar.choices[0].message.content)
```

| Del | Forklaring |
|---|---|
| `DefaultAzureCredential()` | Bruker innloggingen din fra `az login` lokalt, og *managed identity* når koden kjører i Azure |
| `get_bearer_token_provider(..., "https://ai.azure.com/.default")` | Henter tilgangstoken for Foundry. Ingen nøkkel lagres noe sted. |
| `model="gpt-4o-mini"` | **Navnet på deploymenten**, ikke nødvendigvis modellnavnet |

> **Endepunktet** er `https://<ressursnavn>.openai.azure.com/openai/v1/` (eller `https://<ressursnavn>.services.ai.azure.com/openai/v1/`), der `<ressursnavn>` er navnet på Foundry-ressursen. Token-omfanget er `https://ai.azure.com/.default`. Begge deler er hentet fra dokumentasjonen *Configure keyless authentication with Microsoft Entra ID* på Microsoft Learn (november 2026).
>
> Du trenger rollen **Foundry User** (tidligere *Azure AI User*) på Foundry-ressursen eller prosjektet for å kalle modeller med Entra ID. **Owner** og **Contributor** gir *ikke* denne tilgangen. Det tar opptil 5 minutter før en ny rolle virker. Se tema 2.

---

## Oppgaver

**Oppgave 1:** En kommune vil bruke en språkmodell, og data skal ikke behandles utenfor EU. Hvilken deployment-type velger du?

**Fasit:** **Data Zone Standard** med EU-sonen (eller *Data Zone Provisioned* ved høy, jevn trafikk). Global Standard kan behandle data i alle regioner og oppfyller ikke kravet.

**Oppgave 2:** Hva er forskjellen på en Foundry-*ressurs* og et Foundry-*prosjekt*?

**Fasit:** Ressursen er Azure-ressursen der tilgang, nettverk, policy, modell-deployments og kostnad styres. Prosjektet er et arbeidsområde inne i ressursen for én løsning eller ett team, med egne agenter, evalueringer og filer.

**Oppgave 3:** Hvorfor bruker eksempelkoden `DefaultAzureCredential` i stedet for en API-nøkkel?

**Fasit:** En API-nøkkel gir full tilgang til den som har den, kan lekke (for eksempel i Git) og må roteres manuelt. Med Entra ID styres tilgangen per person eller tjeneste med roller, den kan trekkes tilbake, og den logges. Det finnes ingen hemmelighet å lekke.

> **Lærernotat:** Studenter forveksler ofte *modellnavn* og *deployment-navn*. La dem deploye samme modell to ganger med ulike navn og typer, og kalle begge. Pass også på at studentene sletter deployments og ressurser etter kurset, fordi Provisioned koster penger selv uten trafikk.
