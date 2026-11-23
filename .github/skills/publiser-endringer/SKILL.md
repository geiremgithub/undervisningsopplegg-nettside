---
name: publiser-endringer
description: Fører brukeren trygt gjennom publisering av endringer i kursportalen med Git (pull, kontroll, add, commit, push) og en god commit-melding.
disable-model-invocation: true
---

# Publiser endringer

Denne skillen kjøres bare når brukeren selv skriver `/publiser-endringer`.

1. Kjør `git pull`. Får du en konflikt, stopper du og forklarer den med enkle ord (se `VEILEDNING-git-og-publisering.md`, kapittel 7.2).
2. Kjør `git status`, og vis en kort liste over endrede og nye filer.
3. Kjør `npm test` og `npm run build`. Hvis noe feiler, stopper du og forklarer feilen. Ikke publiser.
4. Foreslå en commit-melding på norsk som starter med et verb og er kortere enn 70 tegn, for eksempel `Legg til emne: Power BI for nybegynnere`.
5. **Spør brukeren** om melding og filer er riktige. Vent på et tydelig ja.
6. Kjør `git add -A`, deretter `git commit -m "<melding>"` og `git push`.
7. Fortell at nettsiden oppdateres om 1–3 minutter, og at status kan sjekkes under **Actions** på GitHub.

Kjør aldri `git push --force`, `git reset --hard` eller andre kommandoer som sletter historikk.
