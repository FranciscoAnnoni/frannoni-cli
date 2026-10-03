#!/usr/bin/env node
// ============================================================
//  FRANNONI CLI — Instalador de Claude Code (MCPs, Skills, Plugins, GSD)
//  Corre igual en macOS, Linux y Windows. Sin dependencias: solo Node.
// ============================================================

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, renameSync, writeFileSync } from "node:fs";
import { homedir, platform } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const IS_WIN = platform() === "win32";
const DIR = dirname(fileURLToPath(import.meta.url));
const MCPS = JSON.parse(readFileSync(join(DIR, "mcps.json"), "utf8"));
const CLAUDE_JSON = join(homedir(), ".claude.json"); // donde Claude Code guarda los MCPs de scope user
const SKILLS_DIR = join(homedir(), ".claude", "skills");
const YOUTUBE_URL = "https://www.youtube.com/@frannoni?sub_confirmation=1";

let AUTO = false; // true en "Todo": instala sin preguntar (salvo MCPs con token)

// ── Colores y helpers ────────────────────────────────────────
const c = {
  red: "\x1b[0;31m", green: "\x1b[0;32m", yellow: "\x1b[1;33m", gray: "\x1b[38;5;250m",
  cyan: "\x1b[0;36m", bold: "\x1b[1m", reset: "\x1b[0m",
};
const info = (m) => console.log(`${c.cyan}[INFO]${c.reset}  ${m}`);
const ok = (m) => console.log(`${c.green}[OK]${c.reset}    ${m}`);
const warn = (m) => console.log(`${c.yellow}[WARN]${c.reset}  ${m}`);
const error = (m) => console.error(`${c.red}[ERROR]${c.reset} ${m}`);
const header = (m) => {
  const line = `${c.bold}${c.gray}══════════════════════════════════════${c.reset}`;
  console.log(`\n${line}\n${c.bold}${c.gray}  ${m}${c.reset}\n${line}\n`);
};

// ── Input ────────────────────────────────────────────────────
// Lector propio en vez de readline: readline deja la terminal en modo raw mientras
// corren npx/claude, y con entrada por pipe se come las respuestas que llegan juntas.
let buffer = "";
let stdinEnded = false;
process.stdin.setEncoding("utf8");
process.stdin.on("end", () => { stdinEnded = true; });

function readLine() {
  const take = () => {
    const i = buffer.indexOf("\n");
    if (i < 0) return null;
    const line = buffer.slice(0, i).replace(/\r$/, "");
    buffer = buffer.slice(i + 1);
    return line;
  };
  const line = take();
  if (line !== null) return Promise.resolve(line);
  if (stdinEnded) return Promise.resolve(null);

  return new Promise((resolve) => {
    const done = (l) => {
      process.stdin.off("data", onData).off("end", onEnd).pause();
      resolve(l);
    };
    const onData = (d) => { buffer += d; const l = take(); if (l !== null) done(l); };
    const onEnd = () => done(buffer ? buffer : null);
    process.stdin.on("data", onData).once("end", onEnd).resume();
  });
}

async function ask(q) {
  process.stdout.write(q);
  const a = await readLine();
  if (a === null) { console.log(); process.exit(0); } // sin más entrada: no hay quién responda
  return a.trim();
}
const askYN = async (q) => /^[sS]$/.test(await ask(`${q} [s/N]: `));

// askHidden: no muestra lo que se escribe (para tokens)
function askHidden(q) {
  if (!process.stdin.isTTY) return ask(q);
  process.stdout.write(q);
  process.stdin.setRawMode(true);
  return new Promise((resolve) => {
    let value = "";
    const onData = (chunk) => {
      for (const ch of chunk) {
        if (ch === "\r" || ch === "\n") {
          process.stdin.off("data", onData).pause();
          process.stdin.setRawMode(false);
          process.stdout.write("\n");
          return resolve(value.trim());
        }
        if (ch === "\u0003") { process.stdin.setRawMode(false); process.exit(130); } // Ctrl+C
        if (ch === "\u007f" || ch === "\b") value = value.slice(0, -1);
        else value += ch;
      }
    };
    process.stdin.on("data", onData).resume();
  });
}

// ── Procesos ─────────────────────────────────────────────────
// run: muestra la salida. En Windows npx/npm/claude suelen ser .cmd → hace falta shell
// (solo se usa con argumentos simples, sin comillas ni JSON).
const run = (cmd, args, opts = {}) =>
  spawnSync(cmd, args, { stdio: "inherit", shell: IS_WIN, ...opts }).status === 0;
const capture = (cmd, args) => {
  const r = spawnSync(cmd, args, { encoding: "utf8", shell: IS_WIN });
  return r.status === 0 ? r.stdout.trim() : null;
};
const hasCmd = (cmd) =>
  spawnSync(IS_WIN ? "where" : "which", [cmd], { stdio: "ignore" }).status === 0;

function checkDeps() {
  const missing = ["claude", "npx", "git"].filter((d) => !hasCmd(d));
  if (missing.length) {
    error(`Faltan dependencias: ${missing.join(", ")}`);
    error("Corré el instalador de arranque (install.sh en Mac/Linux, install.ps1 en Windows): las instala solo.");
    process.exit(1);
  }
}

// ── MCPs ─────────────────────────────────────────────────────
const readClaudeJson = () => {
  try { return JSON.parse(readFileSync(CLAUDE_JSON, "utf8")); } catch { return {}; }
};
const mcpExists = (name) => Boolean(readClaudeJson().mcpServers?.[name]);

// addMcp: lo registra en scope user reemplazando si ya existía.
// Usa `claude mcp add-json` sin shell (el JSON no pasa por cmd.exe). Si en Windows
// claude es un .cmd (instalado con npm) y no se puede lanzar sin shell, escribe ~/.claude.json directo.
function addMcp(name, config) {
  const json = JSON.stringify(config);
  if (mcpExists(name)) spawnSync("claude", ["mcp", "remove", name, "-s", "user"], { stdio: "ignore" });
  const r = spawnSync("claude", ["mcp", "add-json", name, json, "-s", "user"], { stdio: ["ignore", "ignore", "inherit"] });
  if (r.status === 0) return ok(`MCP agregado: ${name}`);
  if (r.error?.code === "ENOENT") {
    const data = readClaudeJson();
    data.mcpServers = { ...data.mcpServers, [name]: config };
    const tmp = `${CLAUDE_JSON}.tmp`;
    writeFileSync(tmp, JSON.stringify(data, null, 2));
    renameSync(tmp, CLAUDE_JSON);
    return ok(`MCP agregado: ${name}`);
  }
  error(`Falló al agregar '${name}'`);
}

function installBaseMcps() {
  header("MCPs base (sin token)");
  for (const [name, m] of Object.entries(MCPS.base)) {
    if (mcpExists(name)) { ok(`'${name}' ya está instalado — se mantiene.`); continue; }
    info(`${name} — ${m.description}`);
    addMcp(name, m.config);
  }
}

const fillToken = (value, token) =>
  typeof value === "string" ? value.replaceAll("{{TOKEN}}", token)
  : Array.isArray(value) ? value.map((v) => fillToken(v, token))
  : value && typeof value === "object" ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, fillToken(v, token)]))
  : value;

// configureOptionalMcp: pide el token (si aplica) y lo registra. Devuelve el token, o null si se salteó.
async function configureOptionalMcp(name) {
  const m = MCPS.optional[name];
  let token = "";

  if (m.auth !== "oauth") {
    if (m.token_help) console.log(`    ${c.cyan}${m.token_help}${c.reset}`);

    // GitHub: ofrecer el token de la sesión de gh si existe
    if (name === "github" && hasCmd("gh")) {
      const ghToken = capture("gh", ["auth", "token"]);
      if (ghToken && await askYN("    ¿Usar el token de 'gh auth token'?")) token = ghToken;
    }
    if (!token) token = await askHidden(`    ${m.token_label}: `);
    if (!token && m.auth === "token") {
      warn(`Sin token no se puede configurar '${name}' — se saltea.`);
      return null;
    }
  }

  addMcp(name, token ? fillToken(m.config, token) : (m.config_without_token ?? m.config));
  return token;
}

async function installOptionalMcps() {
  header("MCPs opcionales (con token / cuenta)");

  console.log(`${c.bold}Disponibles:${c.reset}`);
  const tags = { token: "token", "optional-token": "token opcional", oauth: "login OAuth" };
  for (const [name, m] of Object.entries(MCPS.optional)) {
    const tag = tags[m.auth] + (mcpExists(name) ? ", ya instalado" : "");
    console.log(`  • ${c.bold}${name}${c.reset} — ${m.description} ${c.yellow}(${tag})${c.reset}`);
  }
  console.log();

  if (AUTO && !(await askYN("¿Querés configurar MCPs con token / cuenta?"))) {
    info("Se saltean los MCPs opcionales.");
    return;
  }

  const oauthPending = [];
  for (const [name, m] of Object.entries(MCPS.optional)) {
    const q = mcpExists(name) ? `  '${name}' ya existe. ¿Reconfigurarlo?` : `  ¿Instalar '${name}'?`;
    if (!(await askYN(q))) continue;
    const token = await configureOptionalMcp(name);
    if (token === "" && m.login_without_token) oauthPending.push(name);
    console.log();
  }

  if (oauthPending.length) {
    warn(`Estos MCPs piden login la primera vez: ${oauthPending.join(" ")}`);
    console.log(`  ${c.cyan}→ Abrí Claude Code, corré /mcp y elegí cada uno para autenticarte.${c.reset}`);
  }
}

// ── Skills y Plugins (archivos de texto: <col1> <col2> <descripción>) ──
const readList = (file) =>
  readFileSync(join(DIR, file), "utf8").split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"))
    .map((l) => { const [a, b, ...rest] = l.split(/\s+/); return [a, b, rest.join(" ")]; });

async function installSkills() {
  header("Skills (npx skills add)");
  const skills = readList("skills.txt");

  console.log(`${c.bold}Disponibles:${c.reset}`);
  for (const [repo, list, desc] of skills) console.log(`  • ${c.bold}${repo}${c.reset} [${list}] — ${desc}`);
  console.log();

  const pick = !AUTO && (await askYN("¿Elegir individualmente? (N = instalar todas)"));

  for (const [repo, list] of skills) {
    if (pick && !(await askYN(`  ¿Instalar '${repo}' [${list}]?`))) continue;
    info(`Instalando ${repo} [${list}]...`);
    // la CLI necesita un -s por skill (no acepta "a,b"); '*' va entre comillas para que el shell no lo expanda
    const skillArgs = list.split(",").flatMap((s) => ["-s", s === "*" ? '"*"' : s]);
    if (run("npx", ["-y", "skills@latest", "add", repo, "-g", "-a", "claude-code", ...skillArgs, "-y"], { shell: true })) {
      ok(`Skills instaladas: ${repo}`);
    } else {
      error(`Falló la instalación de '${repo}'`);
    }
  }
}

async function installPlugins() {
  header("Plugins");
  for (const [plugin, market, desc] of readList("plugins.txt")) {
    console.log(`  • ${c.bold}${plugin}${c.reset} — ${desc}`);
    if (!AUTO && !(await askYN("    ¿Instalar?"))) continue;

    const marketName = plugin.split("@")[1];
    if (!(capture("claude", ["plugin", "marketplace", "list"]) ?? "").includes(marketName)) {
      info(`Agregando marketplace ${market}...`);
      if (!run("claude", ["plugin", "marketplace", "add", market])) {
        error(`No se pudo agregar el marketplace '${market}'`);
        continue;
      }
    }
    if (run("claude", ["plugin", "install", plugin, "-s", "user"])) ok(`Plugin instalado: ${plugin}`);
    else error(`Falló la instalación de '${plugin}'`);
  }
}

// ── GSD (aparte, no entra en "Todo") ─────────────────────────
// Versión mínima (--minimal): 7 skills del ciclo principal, ~700 tokens de contexto
// en vez de ~12k de la completa. Para pasar a la completa: npx get-shit-done-cc@latest --claude --global
function installGsd() {
  header("GSD (Get Shit Done) — versión mínima");
  info("Método por fases: spec → plan → ejecución → verificación.");
  info("Se instala la versión mínima para no cargar contexto de más.");
  // Global con npm (no npx) para que el comando gsd-sdk quede en el PATH
  if (!run("npm", ["install", "-g", "get-shit-done-cc@latest"])) {
    return error("Falló 'npm install -g get-shit-done-cc'");
  }
  if (run("get-shit-done-cc", ["--claude", "--global", "--minimal"])) ok("GSD instalado (mínimo)");
  else error("Falló la instalación de GSD");
}

// ── Estado actual ────────────────────────────────────────────
function viewCurrent() {
  header("Configuración actual de Claude Code");

  console.log(`${c.bold}MCPs (scope user, en ${CLAUDE_JSON}):${c.reset}`);
  const mcps = Object.keys(readClaudeJson().mcpServers ?? {});
  console.log(mcps.length ? mcps.map((n) => `  • ${n}`).join("\n") : `  ${c.yellow}Ninguno.${c.reset}`);

  console.log(`\n${c.bold}Skills (${SKILLS_DIR}):${c.reset}`);
  const skills = existsSync(SKILLS_DIR) ? readdirSync(SKILLS_DIR) : [];
  console.log(skills.length ? skills.map((n) => `  • ${n}`).join("\n") : `  ${c.yellow}Ninguna.${c.reset}`);

  console.log(`\n${c.bold}Plugins:${c.reset}`);
  run("claude", ["plugin", "list"]);
}

// ── Cierre: invitación a YouTube ─────────────────────────────
function openUrl(url) {
  const [cmd, args] =
    IS_WIN ? ["cmd", ["/c", "start", '""', url]]
    : platform() === "darwin" ? ["open", [url]]
    : ["xdg-open", [url]];
  // verbatim: que Node no escape el "" que `start` necesita como título de ventana
  return spawnSync(cmd, args, { stdio: "ignore", windowsVerbatimArguments: IS_WIN }).status === 0;
}

function outro() {
  console.log(`\n  ${c.bold}Esta herramienta es gratuita.${c.reset}`);
  console.log(`  Si te sirvió, te invito a suscribirte a mi canal de YouTube: ${c.cyan}@frannoni${c.reset}\n`);
  if (!openUrl(YOUTUBE_URL)) console.log(`  ${c.cyan}→ ${YOUTUBE_URL}${c.reset}`);
}

// ── Banner ───────────────────────────────────────────────────
// '#' = bloque, '.' = sombra. Se pinta con un degradé de grises de izquierda a derecha.
const BANNER_ROWS = [
  "###### #####   ####  ##  ## ##  ##  ####  ##  ## ######     ##### ##     ######",
  "##.....##..## ##..## ### ##.### ##.##..## ### ##. .##...   ##.....##.     .##...",
  "##.    ##. ##.##. ##.######.######.##. ##.######.  ##.     ##.    ##.      ##.",
  "#####  #####..######.##.###.##.###.##. ##.##.###.  ##.     ##.    ##.      ##.",
  "##.... ##.##. ##..##.##. ##.##. ##.##. ##.##. ##.  ##.     ##.    ##.      ##.",
  "##.    ##. ## ##. ##.##. ##.##. ##.##. ##.##. ##.  ##.     ##.    ##.      ##.",
  "##.    ##. ##.##. ##.##. ##.##. ##. ####..##. ##.######     ##### ###### ######",
  " ..     ..  .. ..  .. ..  .. ..  ..  ....  ..  .. ......     ..... ...... ......",
];

function banner() {
  const width = 80, from = 255, to = 242; // grises de la paleta de 256 colores (232–255)
  console.log();
  for (const row of BANNER_ROWS) {
    let line = "";
    for (let i = 0; i < row.length; i++) {
      const color = Math.round(from - ((from - to) * i) / (width - 1));
      line += row[i] === "#" ? `\x1b[38;5;${color}m█` : row[i] === "." ? `\x1b[38;5;${color}m░` : " ";
    }
    console.log(line + c.reset);
  }
  console.log();
}

// ── Menú principal ───────────────────────────────────────────
function showMenu() {
  console.clear();
  banner();
  console.log(`  ${c.gray}Instalador de Claude Code · MCPs · Skills · Plugins${c.reset}\n`);
  console.log(`  ${c.bold}¿Qué querés instalar?${c.reset}\n`);
  console.log("  1) Todo (instala MCPs base, Skills y Plugins sin preguntar)");
  console.log("  2) MCPs base (sin token)");
  console.log("  3) MCPs opcionales (con token / cuenta)");
  console.log("  4) Skills");
  console.log("  5) Plugins");
  console.log("  6) GSD (opcional, versión mínima)");
  console.log("  7) Ver configuración actual");
  console.log("  8) Salir\n");
}

async function main() {
  checkDeps();

  while (true) {
    showMenu();
    const option = await ask("  Opción [1-8]: ");
    console.log();

    switch (option) {
      case "1": AUTO = true; installBaseMcps(); await installOptionalMcps(); await installSkills(); await installPlugins(); break;
      case "2": installBaseMcps(); break;
      case "3": await installOptionalMcps(); break;
      case "4": await installSkills(); break;
      case "5": await installPlugins(); break;
      case "6": installGsd(); break;
      case "7": viewCurrent(); await ask("\nPresioná Enter para volver al menú..."); continue;
      case "8": console.log(`${c.cyan}¡Hasta luego!${c.reset}`); return;
      default: warn("Opción inválida. Elegí entre 1 y 8."); await new Promise((r) => setTimeout(r, 1000)); continue;
    }

    console.log();
    ok("¡Listo!");
    console.log(`  ${c.yellow}Reiniciá Claude Code para que tome los cambios.${c.reset}`);
    outro();
    return;
  }
}

main();
