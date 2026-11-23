---
name: lag-quiz
description: Lager en quiz med flervalg, kortsvar og fasit ut fra ett eller flere temaer i kursportalen. Bruk når brukeren ber om quiz, repetisjonsspørsmål, test eller eksamensøving for et emne.
---

# Lag quiz fra et tema

1. **Finn kilden.** Spør hvilket emne eller tema quizen skal dekke, hvis det ikke er oppgitt. Les temafilene i `content/<emne>/`.
2. **Lag spørsmålene** bare ut fra det som står i temaene:
   - Lag 8–10 spørsmål, blandet: flervalg (F), kortsvar (K) og ett analysespørsmål (A).
   - Hvert spørsmål tester ett læringsmål. Unngå lureri og «alle de ovennevnte».
   - Flervalg har fire alternativer, og feilsvarene er typiske misforståelser.
3. **Skriv i portalens format**, slik at fasiten skjules automatisk:

   ```markdown
   **1. (F, 1 p)** Hva er en surrogatnøkkel?
   a) … b) … c) … d) …

   **Fasit:** c. Forklaring på én til to setninger, med henvisning til temaet.
   ```

4. **Spør hvor quizen skal lagres:**
   - **Som eget tema:** en ny fil `content/<emne>/NN-quiz-<tema>.md` med frontmatter (følg skillen `nytt-tema`).
   - **Bare i chatten:** til egen øving, uten å lagre noe.
5. Ta med poengsum per spørsmål og totalsum nederst.
