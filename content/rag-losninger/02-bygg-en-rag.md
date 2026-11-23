---
title: "Bygg en enkel RAG i Python"
description: "Lag en RAG over kursportalens egne temaer: chunking på overskrifter, tokentelling, embeddings, vektordatabase (Chroma) og svar fra en språkmodell."
order: 2
---

# Bygg en enkel RAG i Python

**Mål:** Du bygger en fungerende RAG som svarer på spørsmål om innholdet i denne kursportalen, og ser hvert ledd i kjeden fra tema 1 i kode.

**Forkunnskaper:** Tema 1. Python. For steg 5 trenger du tilgang til en språkmodell, for eksempel en modell deployet i Microsoft Foundry (se emnet *Microsoft Foundry*). Steg 1–4 kan kjøres helt lokalt og gratis.

---

## Oppsett

```powershell
cd C:\Work\undervisningsopplegg-nettside
python -m venv .venv
.venv\Scripts\activate
pip install tiktoken sentence-transformers chromadb openai
```

| Pakke | Ledd i kjeden |
|---|---|
| `tiktoken` | ② Tokenisering (telle tokens) |
| `sentence-transformers` | ③ Embedding-modell som kjører lokalt |
| `chromadb` | ④ Vektordatabase som kjører lokalt |
| `openai` | ⑤ Kalle språkmodellen |

Lag filen `rag/rag.py`, og legg inn kodeblokkene under i rekkefølge.

---

## Steg 1: Chunking på overskrifter

```python
from pathlib import Path
import re

CONTENT = Path(__file__).resolve().parent.parent / "content"

def chunk_markdown(fil: Path) -> list[dict]:
    """Del en temafil i biter, én per ##-seksjon, med kilde som metadata."""
    tekst = fil.read_text(encoding="utf-8")
    tekst = re.sub(r"^---\n.*?\n---\n", "", tekst, flags=re.S)  # fjern frontmatter
    deler = re.split(r"\n(?=## )", tekst)
    chunks = []
    for i, del_ in enumerate(deler):
        overskrift = del_.splitlines()[0].lstrip("# ").strip() if del_.strip() else ""
        chunks.append({
            "id": f"{fil.parent.name}/{fil.stem}#{i}",
            "tekst": del_.strip(),
            "kilde": f"{fil.parent.name}/{fil.name} › {overskrift}",
        })
    return [c for c in chunks if len(c["tekst"]) > 50]

chunks = [c for fil in CONTENT.glob("*/*.md") for c in chunk_markdown(fil)]
print(f"{len(chunks)} chunks")
```

**Hva skjer:** Frontmatteren fjernes, og teksten deles foran hver `## `-overskrift. Hver chunk får en **ID** og en **kilde**, så svaret senere kan vise hvor det kommer fra.

---

## Steg 2: Tokenisering, og sjekk av størrelse

```python
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")

for c in chunks:
    c["tokens"] = len(enc.encode(c["tekst"]))

storst = max(chunks, key=lambda c: c["tokens"])
print("Største chunk:", storst["kilde"], storst["tokens"], "tokens")
print("Eksempel på tokens:", [enc.decode([t]) for t in enc.encode("Datavarehuset oppdateres hver natt.")])
```

**Hva skjer:** Vi teller tokens i hver chunk og ser hvordan en norsk setning deles opp. Er noen chunks svært store, for eksempel over 1 500 tokens, bør de deles videre. Se oppgave 2.

---

## Steg 3: Embeddings

```python
from sentence_transformers import SentenceTransformer

# Flerspråklig modell som også forstår norsk
modell = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

vektorer = modell.encode([c["tekst"] for c in chunks], normalize_embeddings=True)
print("Dimensjoner per vektor:", vektorer.shape[1])
```

**Hva skjer:** Hver chunk gjøres om til en vektor (384 tall med denne modellen). `normalize_embeddings=True` gjør at cosinuslikhet og prikkprodukt blir det samme. Første gang lastes modellen ned (ca. 0,5 GB).

---

## Steg 4: Vektordatabase og søk

```python
import chromadb

db = chromadb.Client()  # i minnet. Bruk chromadb.PersistentClient("rag/db") for å lagre på disk.
samling = db.get_or_create_collection("kursportal", metadata={"hnsw:space": "cosine"})
samling.add(
    ids=[c["id"] for c in chunks],
    documents=[c["tekst"] for c in chunks],
    embeddings=vektorer.tolist(),
    metadatas=[{"kilde": c["kilde"]} for c in chunks],
)

def sok(sporsmal: str, k: int = 4) -> list[dict]:
    q = modell.encode([sporsmal], normalize_embeddings=True).tolist()
    res = samling.query(query_embeddings=q, n_results=k)
    return [
        {"kilde": m["kilde"], "tekst": d, "avstand": round(a, 3)}
        for m, d, a in zip(res["metadatas"][0], res["documents"][0], res["distances"][0])
    ]

for t in sok("Hvordan tar vi vare på historikk når en kunde flytter?"):
    print(t["avstand"], t["kilde"])
```

**Hva skjer:** Chunkene lagres med vektor, tekst og kilde. `"hnsw:space": "cosine"` ber Chroma bruke en HNSW-indeks med cosinusavstand, der lavere avstand betyr mer lik mening. Søket gjør spørsmålet om til en vektor **med samme modell** og henter de `k` nærmeste.

**Prøv:** Still noen spørsmål, og se om riktige temaer kommer øverst. Dette er **retrieval**-delen, og den kan testes uten noen språkmodell.

---

## Steg 5: Generer svaret med en språkmodell

```python
import os
from openai import OpenAI

# Fyll inn fra din modell-deployment, for eksempel i Microsoft Foundry.
# Bruk miljøvariabler. Legg aldri nøkler i koden.
klient = OpenAI(base_url=os.environ["LLM_ENDPOINT"], api_key=os.environ["LLM_API_KEY"])
MODELL = os.environ.get("LLM_MODEL", "gpt-4o-mini")

def svar(sporsmal: str) -> str:
    kilder = sok(sporsmal)
    kontekst = "\n\n".join(f"[{k['kilde']}]\n{k['tekst']}" for k in kilder)
    meldinger = [
        {"role": "system", "content": (
            "Du er en assistent for kursportalen. Svar på norsk og KUN ut fra kildene. "
            "Står svaret ikke i kildene, si «Det står ikke i kursmaterialet». "
            "Oppgi kilden i [hakeparentes] etter hver påstand.")},
        {"role": "user", "content": f"KILDER:\n{kontekst}\n\nSPØRSMÅL: {sporsmal}"},
    ]
    res = klient.chat.completions.create(model=MODELL, messages=meldinger, temperature=0.2)
    return res.choices[0].message.content

print(svar("Hvordan tar vi vare på historikk når en kunde flytter?"))
```

**Hva skjer:** De fire beste chunkene settes inn i prompten sammen med kildene. Systemmeldingen styrer modellen til å holde seg til kildene og vise dem, og lav `temperature` gir mer presise svar.

> **Tilkobling:** Adressen (`LLM_ENDPOINT`) og hvordan du logger inn avhenger av hvor modellen er deployet. I Microsoft Foundry er adressen `https://<ressursnavn>.openai.azure.com/openai/v1/`, og det anbefales innlogging med Microsoft Entra ID fremfor API-nøkler. Se emnet *Microsoft Foundry*, tema 1, avsnitt 5.

---

## Oppgaver

**Oppgave 1 (grunnleggende):** Kjør `sok()` med spørsmålet *«Hva er forskjellen på clustered og nonclustered indeks?»*. Hvilket emne og hvilken fil kommer øverst? Er det riktig?

**Fasit:** Det bør være `datavarehus/05-samling-5.md` (Indeksering) eller `datavarehus/07-quiz.md`. Kommer noe helt annet øverst, er chunkene trolig for store. Se oppgave 2.

**Oppgave 2 (viderekommen):** Noen chunks er svært store, fordi noen `##`-seksjoner er lange. Endre `chunk_markdown` slik at seksjoner over 800 tokens deles videre på avsnitt (`\n\n`), med ett avsnitt overlapp.

**Fasit:** Etter `deler = …`: for hver del, tell tokens med `enc`. Er den over 800, del på `"\n\n"` og bygg opp nye biter ved å legge til avsnitt til grensen nås. Start neste bit med det siste avsnittet fra forrige (overlapp). Gi bitene ID-ene `…#i-0`, `…#i-1` og samme `kilde`. Dette er *rekursiv chunking med overlapp* fra tema 1, avsnitt 3.

**Oppgave 3 (utfordring):** Fasitene i kursportalen havner også i vektordatabasen. Hvorfor kan det være et problem for en veileder-bot, og hvordan løser du det?

**Fasit:** Boten kan hente og vise fasiten til studenter som bare ville ha hint. Løsning: Fjern `**Fasit**`-blokker (se emnet *MCP-server*, tema 2, oppgave 3) før chunking, eller lagre `"er_fasit": True` som metadata og filtrer bort med `where={"er_fasit": False}` i `samling.query`. Det er sikrere enn å be modellen la være å vise fasit.

> **Lærernotat:** Steg 1–4 kan gjøres av alle uten skytilgang. Stopp og diskuter resultatet av `sok()` før steg 5. De fleste RAG-problemer ligger i gjenfinningen, ikke i språkmodellen. Legg `rag/` og `.venv/` i en egen kopi av prosjektet, eller i `.gitignore`.
