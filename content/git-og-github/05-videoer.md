---
title: "Videoer: GitHub og versjonskontroll"
description: "Utvalgte videoer for nybegynnere om Git-kommandoer, GitHub, pull requests, merge-konflikter og Git i VS Code."
order: 5
---

# Videoer: GitHub og versjonskontroll

Alle videoene er på engelsk og gratis på YouTube. Lenkene er kontrollert og var offentlig tilgjengelige i november 2026. Beskrivelsene bygger på videoenes egen beskrivelse, kapitler og lengde. Jeg har ikke sett hele videoene.

**Anbefalt rekkefølge:** Start med Fireship (2 min) for helheten. Se så Kevin Stratvert, som dekker nesten hele emnet. Avslutt med VS Code-videoen (7 min) før du gjør oppgavene i [Git i VS Code](04-git-i-vs-code.md). Har du dårlig tid: Kevin Stratvert alene dekker temaene 1–3.

---

## Hovedvideoer

### Git and GitHub Tutorial for Beginners

- **Kanal / kilde:** YouTube – Kevin Stratvert · ca. 46 min · 2022
- **Lenke:** https://www.youtube.com/watch?v=tRZGeaHPoaw
- **Nivå:** Nybegynner
- **Innhold:** Den mest komplette gjennomgangen for dette emnet, med kapitler du kan hoppe mellom. Første halvdel er Git lokalt: installasjon og `git config`, `git init`, `git status`, `git add` og staging, `.gitignore`, `git commit`, `git diff`, `git restore`, `git log` og `--amend`. Deretter kommer **branches** (23:12), **merge** (27:19) og **merge-konflikter** (28:30), og en typisk arbeidsflyt (32:16). Andre halvdel er GitHub: opprette konto og repo, **pushe et lokalt repo til GitHub** (35:09), issues, **pull requests** (40:17), releases, og `fetch` og `pull` (45:00). Det følger med eksempelfiler og en jukselapp.
- **Hvorfor:** Dekker alle tre fagtemaene i én video, i samme rekkefølge som portalen. Rolig tempo med forklaring av hvert steg.

### Git and GitHub for Beginners – Crash Course

- **Kanal / kilde:** YouTube – freeCodeCamp.org · ca. 68 min · 2020
- **Lenke:** https://www.youtube.com/watch?v=RGOj5yH7evk
- **Nivå:** Nybegynner
- **Innhold:** Gwen Faraday forklarer hva Git og versjonskontroll er, og går gjennom begrepene og kommandoene du trenger (2:10–7:05). Så viser hun hvordan du lager en GitHub-konto, installerer Git, **kloner et repo med VS Code** (14:30), og gjør `git add`, `git commit` og `git push`. Hun sammenligner arbeidsflyten lokalt og på GitHub (31:40). Den lengste delen handler om **branching** (32:42–56:30), og videoen avslutter med å angre endringer og **forking**. Lenke til en liste med kommandoene ligger i beskrivelsen.
- **Hvorfor:** Godt alternativ til Kevin Stratvert, med mer tid på branches. Merk: SSH-nøkler (20:30) kan du hoppe over. På Windows logger du inn i et nettleservindu i stedet.

### Using Git with Visual Studio Code (Official Beginner Tutorial)

- **Kanal / kilde:** YouTube – Visual Studio Code (Microsoft) · ca. 7 min · 2022
- **Lenke:** https://www.youtube.com/watch?v=i_23KUAEtUM
- **Nivå:** Nybegynner
- **Innhold:** Reynald Adolphe viser Git i VS Code steg for steg: opprette repo (*Initialize Repository*), endre navn på grenen, **stage** og **commit** filer, lage en ny gren, fargekodene i margen (*gutter*), sammenligne filer, **merge** grener, **publisere til GitHub** og **klone** et repo.
- **Hvorfor:** Den offisielle og korteste innføringen i akkurat det temaet [Git i VS Code](04-git-i-vs-code.md) handler om. Fin å se rett før du prøver selv.

### How GitHub works

- **Kanal / kilde:** YouTube – GitHub · ca. 4 min · 2016
- **Lenke:** https://www.youtube.com/watch?v=w3jLJU7DT5E
- **Nivå:** Nybegynner
- **Innhold:** En kort animasjon fra GitHub selv som følger Eddie og teamet hans gjennom hvordan de bruker GitHub til å samarbeide. Den viser ideen bak arbeidsflyten med repoer, branches og pull requests, uten kommandoer.
- **Hvorfor:** Gir et bilde av *hvorfor* GitHub flow fungerer, før du går inn i detaljene i [Samarbeid og arbeidsflyt](03-samarbeid.md). Merk: Videoen er fra 2016, så GitHub ser annerledes ut i dag, men arbeidsflyten er den samme.

---

## Ekstra: korte forklaringer og fordypning

### Git Explained in 100 Seconds

- **Kanal / kilde:** YouTube – Fireship · ca. 2 min · 2020
- **Lenke:** https://www.youtube.com/watch?v=hwP7WQkmECE
- **Nivå:** Nybegynner
- **Innhold:** Lynrask oversikt: opprette repo (`git init`), stage filer, commit et øyeblikksbilde, lage en gren («et alternativt univers») og merge den inn i hovedgrenen.
- **Hvorfor:** Perfekt som repetisjon eller som start på en forelesning. Høyt tempo, så se den gjerne to ganger.

### How Git Works: Explained in 4 Minutes

- **Kanal / kilde:** YouTube – ByteByteGo · ca. 4 min · 2023
- **Lenke:** https://www.youtube.com/watch?v=e9lnsKot_SQ
- **Nivå:** Nybegynner–viderekommen
- **Innhold:** Animert forklaring av hvordan Git virker, i ByteByteGos diagramstil. Passer til figuren med de fire stedene i [Grunnleggende virkemåte](01-grunnleggende.md#3-de-fire-stedene-en-endring-gar-gjennom). Kanalen har også en oppfølger om *merge vs. rebase* (lenket i videobeskrivelsen).
- **Hvorfor:** Visuell repetisjon av hvordan en endring går fra arbeidsmappen til GitHub. Videobeskrivelsen sier lite om innholdet, så beskrivelsen her bygger mest på tittelen.

### Git Tutorial for Beginners: Learn Git in 1 Hour

- **Kanal / kilde:** YouTube – Programming with Mosh · ca. 69 min · 2020
- **Lenke:** https://www.youtube.com/watch?v=8JJ101D3knE
- **Nivå:** Nybegynner
- **Innhold:** Grundig gjennomgang av Git **lokalt**: installasjon og konfigurasjon, opprette repo, arbeidsflyten (17:10), staging, commit og gode commit-vaner (27:37), slette, flytte og ignorere filer, `git diff` og visuelle diff-verktøy, historikk, og å angre endringer og hente tilbake gamle versjoner av filer.
- **Hvorfor:** Den beste videoen for å forstå [staging area og commits](02-kommandoer.md) i dybden. Merk: Ut fra kapitlene dekker den *ikke* branches, GitHub eller pull requests. Det gjør bare fullversjonen, som koster penger.

---

## Mal for flere videoer

Vil du legge til en video, bruk samme oppsett, og sjekk alltid at lenken virker. Se kapittel 12 i `VEILEDNING-nye-emner.md`.

```markdown
### Videotittel

- **Kanal / kilde:** YouTube – Kanalnavn · lengde · år
- **Lenke:** https://www.youtube.com/watch?v=…
- **Nivå:** Nybegynner / viderekommen
- **Innhold:** Hva videoen viser, og hvilke kommandoer eller begreper den går gjennom.
- **Hvorfor:** Hvorfor den er nyttig, og hvilket tema i emnet den hører til.
```
