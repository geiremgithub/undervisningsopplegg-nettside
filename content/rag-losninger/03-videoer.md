---
title: "Videoer: RAG-løsninger"
description: "Utvalgte videoer om hele RAG-kjeden og hver del: chunking, tokenisering, embedding-modell, vektordatabase og språkmodell."
order: 3
---

# Videoer: RAG-løsninger

Videoene er sortert etter delene i RAG-kjeden. Alle er på engelsk og gratis på YouTube. Lenkene er kontrollert og var offentlig tilgjengelige i november 2026. Beskrivelsene bygger på videoenes egen beskrivelse, kapitler og lengde. Jeg har ikke sett hele videoene.

**Anbefalt rekkefølge:** IBM «What is RAG» (oversikt) → én video per del under → LangChain eller Tech With Tim for å bygge selv.

---

## Oversikt: hva er RAG?

Hører til [RAG-kjeden: fra dokument til svar](01-rag-kjeden.md).

### What is Retrieval-Augmented Generation (RAG)?

- **Kanal / kilde:** YouTube – IBM Technology · 6:35 · 2023
- **Lenke:** https://www.youtube.com/watch?v=T-D1OfcDW1M
- **Nivå:** Nybegynner
- **Innhold:** IBM-forsker Marina Danilevsky forklarer på tavla hvorfor språkmodeller kan gi ufullstendige eller feil svar når treningsdataene blir utdaterte, og hvordan RAG løser det ved å hente oppdatert kunnskap og la modellen vise kilder. Svært mye sett, og den klassiske innføringen.

### RAG Explained For Beginners

- **Kanal / kilde:** YouTube – KodeKloud · 10:09 · 2025
- **Lenke:** https://www.youtube.com/watch?v=_HQ2H_0Ayy0
- **Nivå:** Nybegynner
- **Innhold:** Viser med animasjoner hvordan en KI-assistent kan søke i, lese og forstå store dokumentsamlinger i en bedrift ved hjelp av **vektor-embeddings** og **semantisk søk**. Går gjennom hele kjeden, inkludert chunking-strategier og vektordatabaser. God visuell helhet.

### RAG From Scratch: Part 1 (Overview)

- **Kanal / kilde:** YouTube – LangChain · 5:13 · 2024
- **Lenke:** https://www.youtube.com/watch?v=wd7TZ4w1mSw
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Første video i LangChains serie *RAG From Scratch*: RAG som en generell metode for å koble språkmodeller til private eller nye data, delt i **indeksering**, **gjenfinning** og **generering**. Serien bygger videre til avanserte teknikker.

---

## ① Chunking

Hører til [RAG-kjeden, avsnitt 3](01-rag-kjeden.md#3-chunking-del-dokumentene-opp).

### Chunking Strategies Explained

- **Kanal / kilde:** YouTube – Redis · 8:25 · 2025
- **Lenke:** https://www.youtube.com/watch?v=ZTOtxiWb2bE
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Ricardo Ferreira (Redis) forklarer hvorfor chunking avgjør om svarene blir relevante, hvordan du balanserer **chunk-størrelse** mellom støy og relevans, og strategiene fra **fast størrelse** til **semantisk chunking**, med kodeeksempler i LangChain. **Beste start for dette leddet.**

### Chunking Strategies in RAG: Optimising Data for Advanced AI Responses

- **Kanal / kilde:** YouTube – Mervin Praison · 14:02 · 2024
- **Lenke:** https://www.youtube.com/watch?v=pIGRwMjhMaQ
- **Nivå:** Viderekommen
- **Innhold:** Praktisk gjennomgang med kode av flere chunking-metoder, blant annet tegnbasert, rekursiv, dokumentspesifikk og semantisk splitting. Videoen viser også hvordan chunkene gjøres om til embeddings og lagres i en vektordatabase.

### Semantic Chunking – 3 Methods for Better RAG

- **Kanal / kilde:** YouTube – James Briggs · 10:13 · 2024
- **Lenke:** https://www.youtube.com/watch?v=7JS0pqXvha8
- **Nivå:** Viderekommen
- **Innhold:** Fordypning i **semantisk chunking**: tre ulike metoder (StatisticalChunker, ConsecutiveChunker og CumulativeChunker) som deler der meningen skifter, med kode i notebook. Til slutt også semantisk chunking av video og lyd.

---

## ② Tokenisering

Hører til [RAG-kjeden, avsnitt 4](01-rag-kjeden.md#4-tokenisering-tekst-blir-tall).

### Most devs don't understand how LLM tokens work

- **Kanal / kilde:** YouTube – Matt Pocock · 10:57 · 2025
- **Lenke:** https://www.youtube.com/watch?v=nKSk_TiR8YA
- **Nivå:** Nybegynner
- **Innhold:** Praktisk forklaring av tokens for utviklere, med kapitler om input- og output-tokens, overvåking av tokenbruk, hva tokens er, **tiktoken**, hele LLM-prosessen og hvordan ordforrådet bygges (fra tegn til BPE). Forklarer også hvorfor pris og fakturering per token varierer mellom leverandører. **Beste start for dette leddet.**

### LLM Tokenizers Explained: BPE Encoding, WordPiece and SentencePiece

- **Kanal / kilde:** YouTube – DataMListic · 5:13 · 2024
- **Lenke:** https://www.youtube.com/watch?v=hL4ZnAWSyuU
- **Nivå:** Viderekommen
- **Innhold:** Kort og presis gjennomgang av de tre vanligste tokenizerne for språkmodeller: **Byte Pair Encoding (BPE)**, **WordPiece** og **SentencePiece**, med henvisning til forskningsartiklene.

### Tokens vs Embeddings – what are they + how are they different?

- **Kanal / kilde:** YouTube – Annie Sexton · 6:52 · 2025
- **Lenke:** https://www.youtube.com/watch?v=izbifbq3-eI
- **Nivå:** Nybegynner
- **Innhold:** Forklarer forskjellen på **tokens** og **embeddings**, to begreper som ofte blandes. Fin bro mellom ledd ② og ③.

### Let's build the GPT Tokenizer

- **Kanal / kilde:** YouTube – Andrej Karpathy · 2:13:34 · 2024
- **Lenke:** https://www.youtube.com/watch?v=zduSFxRajkE
- **Nivå:** Viderekommen–ekspert
- **Innhold:** Andrej Karpathy (medgründer av OpenAI) bygger tokenizeren i GPT-serien fra bunnen av i Python: treningsalgoritmen **BPE** og funksjonene `encode()` og `decode()`. Han viser også hvordan mange rare oppførsler i språkmodeller kan spores tilbake til tokeniseringen. For de som vil forstå i dybden.

---

## ③ Embedding-modell

Hører til [RAG-kjeden, avsnitt 5](01-rag-kjeden.md#5-embedding-modell-tekst-blir-mening-i-tall).

### What are text embeddings?

- **Kanal / kilde:** YouTube – Google Cloud Tech · 4:47 · 2024
- **Lenke:** https://www.youtube.com/watch?v=vlcQV4j2kTo
- **Nivå:** Nybegynner
- **Innhold:** Aja og Jason fra Google forklarer hvordan embeddings gjør tekst og bilder om til tall. Kapitler: hva vektorer er, bruksområder, hvordan embeddings lages, og en kort demo. **Beste start for dette leddet.**

### What are Word Embeddings?

- **Kanal / kilde:** YouTube – IBM Technology · 8:38 · 2024
- **Lenke:** https://www.youtube.com/watch?v=wgfSDrqYMJ4
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Martin Keen forklarer hvordan naturlig språk gjøres om til vektorer, de klassiske metodene (**word2vec**, **CBOW**, **GloVe**) og hvordan transformer-modeller har endret embeddings. Gir historikken bak moderne embedding-modeller.

### How to choose an embedding model

- **Kanal / kilde:** YouTube – Weaviate vector database · 4:03 · 2025
- **Lenke:** https://www.youtube.com/watch?v=djp4205tHGU
- **Nivå:** Viderekommen
- **Innhold:** Hvordan embedding-modeller virker, og hvordan du **velger** riktig modell for ditt bruk, blant annet med **MTEB-oversikten** på Hugging Face. Direkte nyttig for valget i tema 1, avsnitt 5.

### Word Embedding and Word2Vec, Clearly Explained!!!

- **Kanal / kilde:** YouTube – StatQuest with Josh Starmer · 16:11 · 2023
- **Lenke:** https://www.youtube.com/watch?v=viZrOnJclY0
- **Nivå:** Viderekommen
- **Innhold:** Steg-for-steg-forklaring av hvordan et nevralt nett **lærer** word embeddings, hvordan de visualiseres og valideres, og hvordan word2vec virker. Forutsetter grunnleggende kunnskap om nevrale nett.

---

## ④ Vektordatabase

Hører til [RAG-kjeden, avsnitt 6](01-rag-kjeden.md#6-vektordatabase-lagre-og-soke-pa-mening).

### What is a Vector Database? Powering Semantic Search & AI Applications

- **Kanal / kilde:** YouTube – IBM Technology · 9:48 · 2025
- **Lenke:** https://www.youtube.com/watch?v=gl1r1XV0SLw
- **Nivå:** Nybegynner
- **Innhold:** Martin Keen forklarer hvordan vektordatabaser bruker embeddings til å bygge bro over det *semantiske gapet* og gjøre **semantisk søk** mulig, for eksempel å finne bilder med lignende farger og landskap. Viser også rollen i RAG og hvordan likhetssøk gjøres effektivt. **Beste start for dette leddet.**

### Vector Databases simply explained! (Embeddings & Indexes)

- **Kanal / kilde:** YouTube – AssemblyAI · 4:23 · 2023
- **Lenke:** https://www.youtube.com/watch?v=dN0lsF2cvm4
- **Nivå:** Nybegynner
- **Innhold:** Kort forklaring av hvorfor vi trenger vektordatabaser, hva vektor-embeddings og **indekser** er, bruksområder, og en oversikt over databaser du kan velge mellom.

### Vector Database Search – Hierarchical Navigable Small Worlds (HNSW) Explained

- **Kanal / kilde:** YouTube – DataMListic · 8:02 · 2024
- **Lenke:** https://www.youtube.com/watch?v=77QH0Y2PYKg
- **Nivå:** Viderekommen
- **Innhold:** Hvordan **HNSW**-algoritmen indekserer vektorer i en lagdelt graf, og hvorfor den gjør det mye raskere å finne de mest like vektorene. Forklarer indeksen som Chroma og Azure AI Search bruker (tema 2, steg 4).

### Create a Vector RAG Index in Minutes with Azure AI Search Wizard

- **Kanal / kilde:** YouTube – Azure Innovation Station · 8:38 · 2025
- **Lenke:** https://www.youtube.com/watch?v=VdkCzaKRbeA
- **Nivå:** Nybegynner
- **Innhold:** Steg-for-steg i **Azure AI Search**: bygg en vektorbasert RAG-indeks med veiviseren *Import Data*, uten kode. Viser hele indekseringsfasen (chunking, embedding og indeks) i en Azure-tjeneste.

---

## ⑤ LLM: språkmodellen som skriver svaret

Hører til [RAG-kjeden, avsnitt 7](01-rag-kjeden.md#7-llm-generer-svaret).

### Large Language Models explained briefly

- **Kanal / kilde:** YouTube – 3Blue1Brown · 7:58 · 2024
- **Lenke:** https://www.youtube.com/watch?v=LPZh9BOjkQs
- **Nivå:** Nybegynner
- **Innhold:** Lett og svært visuell innføring i språkmodeller, chatboter, forhåndstrening og transformere. Laget for en utstilling på Computer History Museum. **Beste start for dette leddet.**

### Transformers, the tech behind LLMs | Deep Learning Chapter 5

- **Kanal / kilde:** YouTube – 3Blue1Brown · 27:14 · 2024
- **Lenke:** https://www.youtube.com/watch?v=wjZofJX0v4M
- **Nivå:** Viderekommen
- **Innhold:** Visualiserer hvordan data flyter gjennom en språkmodell: fra tokens via embeddings til transformerlagene og sannsynlighetene for neste ord. Knytter ledd ②, ③ og ⑤ sammen.

### Setting up Retrieval Augmented Generation (RAG) in 3 Steps

- **Kanal / kilde:** YouTube – IBM Technology · 2:51 · 2024
- **Lenke:** https://www.youtube.com/watch?v=LpKGm1jJXv4
- **Nivå:** Nybegynner
- **Innhold:** Nicholas Renotte viser kort hvordan RAG settes opp for å **forankre** (*grounde*) språkmodellen i relevante data, altså hvordan hentet kontekst og spørsmål kombineres.

---

## Bygg hele kjeden selv

Hører til [Bygg en enkel RAG i Python](02-bygg-en-rag.md).

### How to Build RAG From Scratch in 50 Lines of Python – Full Tutorial

- **Kanal / kilde:** YouTube – Tech With Tim · 26:34 · 2026
- **Lenke:** https://www.youtube.com/watch?v=f9uAG3AQGWM
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Bygger en komplett RAG fra bunnen av i rundt 50 linjer Python. Nyeste video i listen og nærmest tema 2.

### Learn RAG From Scratch – Python AI Tutorial from a LangChain Engineer

- **Kanal / kilde:** YouTube – freeCodeCamp.org · 2:33:11 · 2024
- **Lenke:** https://www.youtube.com/watch?v=sVcwVQRHIc8
- **Nivå:** Viderekommen
- **Innhold:** Fullt kurs av Lance Martin (LangChain): implementer RAG fra bunnen av i Python og kombiner egne data med språkmodeller, fra grunnleggende indeksering til avanserte teknikker. Kode på GitHub (`langchain-ai/rag-from-scratch`).

### Build an Agentic RAG with Azure AI Search & Microsoft Foundry

- **Kanal / kilde:** YouTube – Azure Innovation Station · 14:00 · 2025
- **Lenke:** https://www.youtube.com/watch?v=xXTuxKdzZrI
- **Nivå:** Viderekommen
- **Innhold:** Bygger en *agentisk* RAG i Azure: last opp PDF-er til Azure Storage, vektoriser dem i Azure AI Search, og koble indeksen til en agent i Microsoft Foundry. Bro til emnet *Microsoft Foundry*.

---

> **Lærernotat:** Én video per ledd (merket «Beste start») gir rundt 45 minutter samlet og dekker hele kjeden. Karpathy og freeCodeCamp passer bare for studenter som vil gå i dybden.
