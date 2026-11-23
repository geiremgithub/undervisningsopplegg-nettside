---
name: nytt-tema
description: Lager en ny temafil (.md) i et emne i kursportalen med riktig frontmatter, struktur, oppgaver og fasit. Bruk når et nytt tema, en ny leksjon eller en ny side skal legges til i content/.
---

# Nytt tema i kursportalen

1. **Finn emnet.** Temaet skal ligge i `content/<emne>/`. Finnes ikke emnet, lager du mappen og `emne.json` først (se `VEILEDNING-nye-emner.md`, kapittel 3–4).
2. **Velg filnavn og rekkefølge.**
   - Se på de eksisterende filene i emnet, og bruk neste ledige nummer: `NN-kort-navn.md`.
   - Filnavnet har bare små bokstaver, tall og bindestrek, uten æ, ø og å.
   - `order` er ett høyere enn det høyeste i emnet. Skal temaet ligge mellom to andre, bruker du et desimaltall, for eksempel `2.5`.
3. **Ta utgangspunkt i malen** [mal.md](./mal.md), og fyll inn alle delene.
4. **Sjekk reglene:**
   - Frontmatter står helt øverst. Tekst med kolon står i anførselstegn.
   - Det er bare én `#`-overskrift, og den er lik `title`.
   - Kodeblokker har språknavn (` ```sql `, ` ```python ` …).
   - Hver oppgave har en `**Fasit:**`, og lærertips starter med `> **Lærernotat:**`.
   - Bilder har beskrivende alt-tekst, og bildefilen ligger i emnemappen.
5. **Kontroller** med skillen `sjekk-innhold`, eller kjør `npm run build`.

Gi aldri eksisterende temafiler nytt navn, fordi studentenes fremdrift er lagret på filnavnet.
