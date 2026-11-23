---
title: "Bygg og koble til en MCP-server"
description: "Koble en ferdig MCP-server til VS Code, og lag din egen MCP-server i Python med to verktøy."
order: 2
---

# Bygg og koble til en MCP-server

**Mål:** Etter dette temaet kan du koble en MCP-server til GitHub Copilot i VS Code, og lage og teste en enkel MCP-server selv.

**Forkunnskaper:** Tema 1. Grunnleggende Python. VS Code med GitHub Copilot (se emnet *AI-agenter og skills*, tema 2).

---

## 1. Koble til en ferdig server (5 min)

Microsoft Learn har en gratis MCP-server som søker i offisiell dokumentasjon. Den krever ingen innlogging.

1. Velg **Copilot** under **Session Target** i chatten i VS Code.
2. `Ctrl + Shift + P` → **Chat: Open Customizations** → fanen **MCP Servers**.
3. Klikk **+** ved **User**, og velg **HTTP**.
4. Lim inn `https://learn.microsoft.com/api/mcp`, og gi serveren navnet `microsoftLearn`.
5. Godkjenn spørsmålet om tillit.

**Test:** Skriv i chatten *«Søk i Microsoft-dokumentasjonen: hva er Microsoft Foundry?»*. Du skal se at et verktøy fra `microsoftLearn` blir brukt, og svaret skal ha lenker til learn.microsoft.com.

---

## 2. Lag din egen MCP-server i Python

Vi lager en server for kursportalen med to verktøy: ett som lister emnene, og ett som søker i temaene.

### Steg 1: Installer SDK-en

```powershell
cd C:\Work\undervisningsopplegg-nettside
python -m venv .venv
.venv\Scripts\activate
pip install "mcp[cli]"
```

`mcp` er den offisielle Python-SDK-en for MCP. `[cli]` tar med verktøy for testing.

### Steg 2: Skriv serveren

Lag filen `mcp-server/kursportal_server.py`:

```python
from pathlib import Path
import json

from mcp.server.fastmcp import FastMCP

# Navnet vises i VS Code
mcp = FastMCP("kursportal")

CONTENT = Path(__file__).resolve().parent.parent / "content"


@mcp.tool()
def list_emner() -> list[dict]:
    """List alle emnene i kursportalen med tittel og beskrivelse."""
    emner = []
    for mappe in sorted(CONTENT.iterdir()):
        meta = mappe / "emne.json"
        if mappe.is_dir() and meta.exists():
            data = json.loads(meta.read_text(encoding="utf-8"))
            emner.append({"emne": mappe.name, "tittel": data.get("title"), "beskrivelse": data.get("description")})
    return emner


@mcp.tool()
def sok_i_temaer(sokeord: str, maks_treff: int = 5) -> list[dict]:
    """Søk etter et ord i alle temaene. Returnerer emne, fil og linjen der ordet står."""
    treff = []
    for fil in CONTENT.glob("*/*.md"):
        for nr, linje in enumerate(fil.read_text(encoding="utf-8").splitlines(), start=1):
            if sokeord.lower() in linje.lower():
                treff.append({"emne": fil.parent.name, "fil": fil.name, "linje": nr, "tekst": linje.strip()[:200]})
                if len(treff) >= maks_treff:
                    return treff
    return treff


if __name__ == "__main__":
    mcp.run()  # stdio-transport som standard
```

**Linje for linje:**

| Del | Hva skjer |
|---|---|
| `FastMCP("kursportal")` | Lager serveren. FastMCP tar seg av protokollen (JSON-RPC, `initialize`, `tools/list` og `tools/call`). |
| `@mcp.tool()` | Gjør funksjonen om til et MCP-**tool** |
| Docstringen `"""…"""` | Blir verktøyets **beskrivelse**. Modellen bruker den til å velge verktøy, så skriv tydelig *hva* og *når*. |
| Typene (`sokeord: str`, `maks_treff: int = 5`) | Blir et **JSON-skjema** for parameterne. Modellen ser hvilke argumenter som kreves. |
| `mcp.run()` | Starter serveren med **stdio**: den leser meldinger fra standard inn og svarer på standard ut |

### Steg 3: Test serveren med MCP Inspector

```powershell
mcp dev mcp-server/kursportal_server.py
```

Dette åpner **MCP Inspector** i nettleseren. Velg **Tools → List Tools**, og prøv `sok_i_temaer` med søkeordet `stjerneskjema`. Du ser nøyaktig de JSON-meldingene som sendes.

> Krever Node.js, fordi Inspector startes med `npx`. Det har du hvis du kan kjøre kursportalen.

### Steg 4: Koble serveren til VS Code

Lag filen `.vscode/mcp.json` i prosjektet:

```json
{
  "servers": {
    "kursportal": {
      "type": "stdio",
      "command": "${workspaceFolder}/.venv/Scripts/python.exe",
      "args": ["${workspaceFolder}/mcp-server/kursportal_server.py"]
    }
  }
}
```

Lagre. VS Code viser **Start** over serveren i filen. Klikk den, og sjekk under **Chat: Open Customizations → MCP Servers** at serveren kjører og har to verktøy.

**Test i chatten:** *«Hvilke emner finnes i kursportalen?»* og *«Hvor i kursportalen står det om slowly changing dimensions?»*. Godkjenn verktøykallet når du blir spurt.

### Steg 5: Bruk serveren fra en agent

I en agentfil (se emnet *AI-agenter og skills*, tema 4) gir du tilgang til alle verktøyene fra serveren med:

```yaml
tools: ['read', 'search', 'kursportal/*']
```

---

## 3. Andre språk

| Språk | SDK | Kom i gang |
|---|---|---|
| Python | `mcp` (FastMCP) | Som over |
| TypeScript/JavaScript | `@modelcontextprotocol/sdk` | Se videoen fra Web Dev Simplified i videotemaet |
| C#/.NET | `ModelContextProtocol` (NuGet) | Se videoen fra James Montemagno i videotemaet |

Alle offisielle SDK-er er lenket fra <https://modelcontextprotocol.io>.

---

## Oppgaver

**Oppgave 1 (grunnleggende):** Legg til et verktøy `les_tema(emne, fil)` som returnerer hele innholdet i en temafil.

**Fasit:**

```python
@mcp.tool()
def les_tema(emne: str, fil: str) -> str:
    """Les hele innholdet i ett tema, f.eks. emne='datavarehus', fil='02-samling-2.md'."""
    sti = (CONTENT / emne / fil).resolve()
    if CONTENT.resolve() not in sti.parents or sti.suffix != ".md":
        raise ValueError("Ugyldig emne eller fil.")
    return sti.read_text(encoding="utf-8")
```

Sjekken på `sti.parents` er viktig. Uten den kan noen be om `../../hemmelig.txt` (*path traversal*), og serveren ville lest filer utenfor `content/`.

**Oppgave 2 (viderekommen):** Hvorfor bør `sok_i_temaer` ha en `maks_treff`-parameter?

**Fasit:** Alt verktøyet returnerer, sendes inn i modellens kontekst. Ubegrenset mange treff kan fylle konteksten, gjøre svaret dårligere og koste flere tokens. Begrens alltid størrelsen på det et verktøy returnerer.

**Oppgave 3 (utfordring):** Kursportalens fasit ligger i `**Fasit:**`-blokker. Endre `les_tema` slik at fasit fjernes før teksten returneres, slik at serveren kan brukes av en veilederagent.

**Fasit:** Del teksten i avsnitt (`tekst.split("\n\n")`), hopp over avsnitt som starter med `**Fasit` og avsnittene som hører til, frem til neste overskrift, `---` eller nytt `**Oppgave`. Bruk samme regel som portalen (se *VEILEDNING-nye-emner.md*, kapittel 11). Merk at dette er bedre enn en instruks til agenten, fordi fasiten da aldri når modellen.

> **Lærernotat:** Steg 3 (MCP Inspector) er det viktigste for forståelsen. La studentene se `tools/list`-svaret og koble docstringen og typene til JSON-skjemaet. `.venv` og `mcp-server/` er ikke en del av kursportalen. Be studentene lage dem i en egen kopi, eller legge `.venv/` i `.gitignore`.
