# Kursportalen – instruksjoner for AI-agenter

Statisk nettside (Vite og vanlig JavaScript) som viser undervisningsopplegg skrevet i Markdown i `content/`.

- **Innhold:** Hvert emne er en mappe `content/<emne>/` med `emne.json` (`title`, `description`, `order`) og temaer som `.md`-filer med frontmatter (`title`, `description`, `order`). Alle regler står i `VEILEDNING-nye-emner.md`.
- **Ikke endre kode** i `src/`, `scripts/` eller `tests/` for å legge til innhold. Menyen lages automatisk.
- **Navn:** Mappe- og filnavn har bare små bokstaver, tall og bindestrek, uten æ, ø og å. Ikke gi eksisterende emner eller temaer nytt navn, fordi studentenes fremdrift er lagret på navnet.
- **Språk:** Norsk bokmål, enkelt og tydelig. Engelske fagtermer står i parentes første gang.
- **Fasit og lærerstoff:** Fasit starter med `**Fasit:**`. Lærerstoff starter med `**Lærernotat:**`. Portalen skjuler dem bak knapper.
- **Forsiden:** Når et nytt emne legges til, skal det også legges til i listen i `content/forside.md`.
- **Kontroll:** Etter endringer kjøres `npm test` og `npm run build`. Begge må gå uten feil.
