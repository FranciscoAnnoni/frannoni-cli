<p align="center">
  <img src="assets/banner.svg" alt="FRANNONI CLI" width="100%">
</p>

<p align="center">
  <b>Dejá Claude Code listo para usar en un solo comando.</b><br>
  MCPs, skills, plugins y GSD · macOS, Windows y Linux · gratis
</p>

<p align="center">
  <a href="https://www.youtube.com/@frannoni?sub_confirmation=1"><img src="https://img.shields.io/badge/YouTube-@frannoni-FF0000?logo=youtube&logoColor=white" alt="YouTube @frannoni"></a>
</p>

## Instalación

**macOS / Linux** (Terminal o Warp):

```bash
curl -fsSL https://raw.githubusercontent.com/FranciscoAnnoni/frannoni-cli/main/install.sh | bash
```

**Windows** (PowerShell o Warp):

```powershell
irm https://raw.githubusercontent.com/FranciscoAnnoni/frannoni-cli/main/install.ps1 | iex
```

El comando instala lo que falte (Node 18+, Git y Claude Code), pregunta si querés instalar la terminal [Warp](https://www.warp.dev) (la recomendada) y abre el menú:

1) Todo · 2) MCPs base · 3) MCPs opcionales · 4) Skills · 5) Plugins · 6) GSD · 7) REA · 8) Ver config actual

**Todo** instala MCPs base, skills y plugins sin preguntar. Lo único que pregunta es si querés configurar MCPs con token y, en ese caso, cuáles. Al terminar abre el canal de YouTube [@frannoni](https://www.youtube.com/@frannoni).

Desde el repo clonado también se puede correr con `./install.sh` (Mac/Linux) o `powershell -ExecutionPolicy Bypass -File install.ps1` (Windows).

## Archivos

| Archivo | Qué es |
|---|---|
| `install.sh` | Arranque para macOS/Linux: instala dependencias y corre el instalador. |
| `install.ps1` | Arranque para Windows: ídem, con `winget`. |
| `installer.mjs` | El instalador (menú, MCPs, skills, plugins, GSD). Node puro, igual en los tres sistemas. |
| `mcps.json` | MCPs: `base` (sin token) y `optional` (con token o cuenta). |
| `skills.txt` | Repos de skills y cuáles instalar de cada uno. |
| `CLAUDE.md.template` | Instrucciones que se agregan a `~/.claude/CLAUDE.md` (find-skills y /prototype). |
| `plugins.txt` | Plugins de Claude Code y su marketplace. |

Para agregar o sacar algo, se edita el archivo correspondiente; el script no tiene nada hardcodeado.

## MCPs base (sin token)

Se agregan uno por uno con `claude mcp add-json <nombre> <json> -s user` (quedan en `~/.claude.json`, disponibles en todos los proyectos). Si uno ya existe, se mantiene.

| MCP | Para qué |
|---|---|
| `sequential-thinking` | Razonamiento paso a paso |
| `context7` | Docs actualizadas y por versión de librerías (sin key usa el límite gratis) |
| `deepwiki` | Preguntas y docs sobre cualquier repo público de GitHub |
| `chrome-devtools` | Controlar y depurar Chrome |
| `excalidraw` | Diagramas |

## MCPs opcionales (con token / cuenta)

El instalador pregunta uno por uno cuáles querés y pide el token de cada uno (el input no se muestra). Si ya existe, pregunta si reconfigurarlo, así que nunca pisa una key sin avisar.

| MCP | Auth | Dónde sacar el token |
|---|---|---|
| `github` | Token (PAT fine-grained, solo con los repos y permisos que necesites). | https://github.com/settings/personal-access-tokens/new |
| `firecrawl` | Token opcional. Sin key: scrape/search con límite. | https://www.firecrawl.dev/app/api-keys |
| `context7` | Token. Reemplaza al base con uno con más límite. | https://context7.com/dashboard |
| `obsidian` | Token. Necesita el plugin **Local REST API** con *Enable HTTP server* activado. | Obsidian → Settings → Local REST API |
| `alphavantage` | Token opcional. Sin key: login OAuth. | https://www.alphavantage.co/support/#api-key |
| `21st` | Token. Busca componentes de UI gratis; generar y bajar código consume créditos. | https://21st.dev/mcp |
| `notion` | OAuth (sin token). | — |

Los que usan OAuth se autentican la primera vez desde Claude Code con `/mcp`.

## Skills

Se instalan con [`npx skills add`](https://skills.sh) en `~/.claude/skills/` (global, solo para Claude Code).

| Repo | Skills | Para qué |
|---|---|---|
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | todas | Diseño y animación de UI. Incluye **`/prototype`**: arma varias versiones distintas de una pieza de UI con un selector para compararlas. Solo corre si la invocás. |
| [anthropics/skills](https://github.com/anthropics/skills) | `frontend-design`, `webapp-testing`, `skill-creator`, `mcp-builder` | Frontend con buen diseño, testeo de apps web, y crear tus propias skills y MCPs. |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | `find-skills` | Busca skills en todo el ecosistema de [skills.sh](https://skills.sh) (`npx skills find <tema>`) y te recomienda las que sirven para lo que estás haciendo. |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | `vercel-react-best-practices`, `web-design-guidelines` | Buenas prácticas de rendimiento en React/Next.js y revisión de UI (accesibilidad, UX). |
| [mattpocock/skills](https://github.com/mattpocock/skills) | `grill-me`, `diagnosing-bugs`, `handoff`, `improve-codebase-architecture` | **`/grill-me`** te interroga sobre un plan antes de programarlo; **`diagnosing-bugs`** encuentra la causa de un bug con un método paso a paso; **`/handoff`** resume la conversación para seguir en otra sesión; **`improve-codebase-architecture`** propone mejoras de estructura en un reporte visual. También se instalan `grilling`, `codebase-design` y `domain-modeling`, que esas skills usan por dentro. |

**No pisa lo que ya tenés:** si una skill con el mismo nombre ya está en `~/.claude/skills`, se mantiene la que estaba. Por ejemplo, Matt Pocock también tiene una `prototype`, pero no se instala: queda la de Emil.

Actualizar después: `npx skills update -g`.

### CLAUDE.md global

Junto con las skills, el instalador agrega a `~/.claude/CLAUDE.md` las instrucciones de [`CLAUDE.md.template`](CLAUDE.md.template), que Claude lee en cada sesión:

- **find-skills primero:** ante un problema grande, un proyecto nuevo o una investigación, Claude busca si ya existe una skill que lo resuelva y te la propone antes de arrancar.
- **/prototype:** cuando pedís una web o una interfaz, Claude te ofrece correr `/prototype` para comparar varias versiones.

Se escribe entre los marcadores `<!-- frannoni-cli:start -->` y `<!-- frannoni-cli:end -->`: si ya tenías un CLAUDE.md, lo tuyo no se toca, y volver a correr el instalador solo actualiza ese bloque.

## Plugins

| Plugin | Para qué |
|---|---|
| [superpowers](https://github.com/obra/superpowers) | Método de trabajo: brainstorming → plan → TDD → debugging → code review. |

Si el marketplace no está agregado, el instalador lo agrega antes.

## Seguridad

- **Leé el script antes de correrlo.** `curl | bash` e `irm | iex` ejecutan lo que esté en `main` en ese momento. Todo el código está en este repo: `install.sh`, `install.ps1` e `installer.mjs`.
- **Instala cosas de terceros, en su última versión** (`@latest`): los MCPs de npm, las skills de los repos de la tabla de [Skills](#skills), el plugin Superpowers y GSD. No están fijados a una versión, así que confiás también en esos autores.
- **Cuidado con las skills.** Una skill son instrucciones, y a veces scripts, que Claude sigue con tus permisos: puede leer tus archivos, correr comandos y mandar datos afuera. Es una vía nueva para meterte código malicioso directo en la compu. Las de este instalador están revisadas (son Markdown; `diagnosing-bugs` trae un script plantilla que solo hace preguntas por la terminal). Antes de instalar cualquier otra, leé su `SKILL.md` y sus scripts, y desconfiá de autores desconocidos o con pocas instalaciones. El CLAUDE.md que instala este repo le pide a Claude que haga esa revisión cada vez que te propone una skill con `find-skills`.
- **Los tokens quedan en texto plano en `~/.claude.json`**: así guarda Claude Code los MCPs. El instalador no los manda a ningún lado. Usá tokens con el mínimo permiso y revocalos si dejás de usarlos.
- **Lo único que se instala sin preguntar es lo imprescindible**: Node, Git, Claude Code y, en Mac, Homebrew. Warp y los MCPs con token se preguntan antes.

## REA (opcional)

[REA (Reverse Engineer Anything)](https://github.com/morluto/rea): MCP + skill para ingeniería inversa (binarios, APKs, Electron, .NET, webs, firmware). No entra en **Todo** porque trae muchas tools y pide Node 22.19+, 24.11+ o 26+. La opción 7 corre `npx rea-agents@latest setup --client claude_code --yes`. Para decompilar binarios nativos hace falta Ghidra, IDA o Hopper; `npx rea-agents doctor` dice qué falta.

## GSD (opcional)

[Get Shit Done](https://github.com/gsd-build/get-shit-done): método por fases (spec → plan → ejecución → verificación). No entra en **Todo** porque se pisa con Superpowers y es pesado: la versión completa ocupa ~12k tokens de contexto en cada sesión. La opción 6 instala la mínima (`--minimal`, 7 skills, ~700 tokens). Para la completa: `npx get-shit-done-cc@latest --claude --global`.

---

<p align="center">
  <b>¿Te sirvió? Suscribite para más contenido 👇</b><br><br>
  <a href="https://www.youtube.com/@frannoni?sub_confirmation=1"><img src="https://img.shields.io/badge/Suscribirme_en_YouTube-@frannoni-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Suscribite en YouTube"></a>
</p>
