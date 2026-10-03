#!/usr/bin/env bash
# ============================================================
#  Claude Code Installer — MCPs, Skills y Plugins
#  Compatible con el bash 3.2 de macOS (sin mapfile ni arrays asociativos)
# ============================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
GRAY='\033[38;5;250m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Rutas ────────────────────────────────────────────────────
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCPS_FILE="$DIR/mcps.json"
SKILLS_FILE="$DIR/skills.txt"
PLUGINS_FILE="$DIR/plugins.txt"
CLAUDE_JSON="$HOME/.claude.json"   # donde Claude Code guarda los MCPs de scope user
LAST_TOKEN=""                      # token ingresado en el último configure_optional_mcp
AUTO=false                         # true en "Todo": instala sin preguntar (salvo MCPs con token)
YOUTUBE_URL="https://www.youtube.com/@frannoni?sub_confirmation=1"

# ── Helpers ──────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${GRAY}══════════════════════════════════════${RESET}"; echo -e "${BOLD}${GRAY}  $*${RESET}"; echo -e "${BOLD}${GRAY}══════════════════════════════════════${RESET}\n"; }

ask_yn() {  # ask_yn "pregunta" → 0 si responde s/S
  local yn
  echo -n "$1 [s/N]: "
  read -r yn
  [[ "$yn" =~ ^[sS]$ ]]
}

check_deps() {
  local missing=() cmd
  for cmd in claude node npx jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Faltan dependencias: ${missing[*]}"
    error "Claude Code: https://claude.com/claude-code · node/jq: brew install node jq"
    exit 1
  fi
}

# ── MCPs ─────────────────────────────────────────────────────
mcp_exists() {
  [[ -f "$CLAUDE_JSON" ]] && jq -e --arg n "$1" '.mcpServers[$n] // empty' "$CLAUDE_JSON" &>/dev/null
}

# add_mcp <nombre> <json>: lo registra en scope user, reemplazando si ya existía
add_mcp() {
  local name="$1" json="$2"
  if mcp_exists "$name"; then
    claude mcp remove "$name" -s user &>/dev/null || true
  fi
  if claude mcp add-json "$name" "$json" -s user >/dev/null; then
    ok "MCP agregado: $name"
  else
    error "Falló al agregar '$name'"
  fi
}

install_base_mcps() {
  header "MCPs base (sin token)"

  local name desc
  for name in $(jq -r '.base | keys_unsorted[]' "$MCPS_FILE"); do
    desc=$(jq -r --arg n "$name" '.base[$n].description' "$MCPS_FILE")
    if mcp_exists "$name"; then
      ok "'$name' ya está instalado — se mantiene."
      continue
    fi
    info "$name — $desc"
    add_mcp "$name" "$(jq -c --arg n "$name" '.base[$n].config' "$MCPS_FILE")"
  done
}

install_optional_mcps() {
  header "MCPs opcionales (con token / cuenta)"

  echo -e "${BOLD}Disponibles:${RESET}"
  local name desc auth tag
  for name in $(jq -r '.optional | keys_unsorted[]' "$MCPS_FILE"); do
    desc=$(jq -r --arg n "$name" '.optional[$n].description' "$MCPS_FILE")
    auth=$(jq -r --arg n "$name" '.optional[$n].auth' "$MCPS_FILE")
    case "$auth" in
      token)          tag="token" ;;
      optional-token) tag="token opcional" ;;
      oauth)          tag="login OAuth" ;;
    esac
    mcp_exists "$name" && tag="$tag, ya instalado"
    echo -e "  • ${BOLD}$name${RESET} — $desc ${YELLOW}($tag)${RESET}"
  done
  echo

  if $AUTO && ! ask_yn "¿Querés configurar MCPs con token / cuenta?"; then
    info "Se saltean los MCPs opcionales."
    return 0
  fi

  local oauth_pending=()
  for name in $(jq -r '.optional | keys_unsorted[]' "$MCPS_FILE"); do
    if mcp_exists "$name"; then
      ask_yn "  '$name' ya existe. ¿Reconfigurarlo?" || continue
    else
      ask_yn "  ¿Instalar '$name'?" || continue
    fi
    if configure_optional_mcp "$name" && [[ -z "$LAST_TOKEN" ]] && \
       jq -e --arg n "$name" '.optional[$n].login_without_token == true' "$MCPS_FILE" &>/dev/null; then
      oauth_pending+=("$name")
    fi
    echo
  done

  if [[ ${#oauth_pending[@]} -gt 0 ]]; then
    warn "Estos MCPs piden login la primera vez: ${oauth_pending[*]}"
    echo -e "  ${CYAN}→ Abrí Claude Code, corré /mcp y elegí cada uno para autenticarte.${RESET}"
  fi
}

# configure_optional_mcp <nombre>: pide el token (si aplica) y lo registra
configure_optional_mcp() {
  local name="$1" auth label help token="" json
  auth=$(jq -r --arg n "$name" '.optional[$n].auth' "$MCPS_FILE")
  label=$(jq -r --arg n "$name" '.optional[$n].token_label // empty' "$MCPS_FILE")
  help=$(jq -r --arg n "$name" '.optional[$n].token_help // empty' "$MCPS_FILE")
  LAST_TOKEN=""

  if [[ "$auth" != "oauth" ]]; then
    [[ -n "$help" ]] && echo -e "    ${CYAN}$help${RESET}"

    # GitHub: ofrecer el token de la sesión de gh si existe
    if [[ "$name" == "github" ]] && command -v gh &>/dev/null && gh auth token &>/dev/null; then
      if ask_yn "    ¿Usar el token de 'gh auth token'?"; then
        token=$(gh auth token)
      fi
    fi

    if [[ -z "$token" ]]; then
      echo -n "    $label: "
      read -r -s token; echo
    fi

    if [[ -z "$token" && "$auth" == "token" ]]; then
      warn "Sin token no se puede configurar '$name' — se saltea."
      return 1
    fi
  fi

  LAST_TOKEN="$token"
  if [[ -n "$token" ]]; then
    json=$(jq -c --arg n "$name" --arg t "$token" \
      '.optional[$n].config | walk(if type == "string" then gsub("\\{\\{TOKEN\\}\\}"; $t) else . end)' "$MCPS_FILE")
  else
    json=$(jq -c --arg n "$name" '.optional[$n].config_without_token // .optional[$n].config' "$MCPS_FILE")
  fi
  add_mcp "$name" "$json"
}

# ── Skills ───────────────────────────────────────────────────
install_skills() {
  header "Skills (npx skills add)"

  local repo skills desc
  echo -e "${BOLD}Disponibles:${RESET}"
  while read -r repo skills desc <&3; do
    [[ -z "$repo" || "$repo" == \#* ]] && continue
    echo -e "  • ${BOLD}$repo${RESET} [$skills] — $desc"
  done 3< "$SKILLS_FILE"
  echo

  local all=true
  if ! $AUTO; then
    ask_yn "¿Elegir individualmente? (N = instalar todas)" && all=false
  fi

  while read -r repo skills desc <&3; do
    [[ -z "$repo" || "$repo" == \#* ]] && continue
    if ! $all; then
      ask_yn "  ¿Instalar '$repo' [$skills]?" || continue
    fi
    info "Instalando $repo [$skills]..."
    # la CLI necesita un -s por skill (no acepta "a,b")
    local skill_args=() list s
    IFS=',' read -ra list <<< "$skills"
    for s in "${list[@]}"; do skill_args+=(-s "$s"); done

    if npx -y skills@latest add "$repo" -g -a claude-code "${skill_args[@]}" -y; then
      ok "Skills instaladas: $repo"
    else
      error "Falló la instalación de '$repo'"
    fi
  done 3< "$SKILLS_FILE"
}

# ── Plugins ──────────────────────────────────────────────────
install_plugins() {
  header "Plugins"

  local plugin market desc
  while read -r plugin market desc <&3; do
    [[ -z "$plugin" || "$plugin" == \#* ]] && continue
    echo -e "  • ${BOLD}$plugin${RESET} — $desc"
    if ! $AUTO; then
      ask_yn "    ¿Instalar?" || continue
    fi

    local market_name="${plugin#*@}"
    if ! claude plugin marketplace list 2>/dev/null | grep -q "$market_name"; then
      info "Agregando marketplace $market..."
      claude plugin marketplace add "$market" || { error "No se pudo agregar el marketplace '$market'"; continue; }
    fi

    if claude plugin install "$plugin" -s user; then
      ok "Plugin instalado: $plugin"
    else
      error "Falló la instalación de '$plugin'"
    fi
  done 3< "$PLUGINS_FILE"
}

# ── GSD (aparte, no entra en "Todo") ─────────────────────────
# Versión mínima (--minimal): 7 skills del ciclo principal, ~700 tokens de contexto
# en vez de ~12k de la completa. Para pasar a la completa: npx get-shit-done-cc@latest --claude --global
install_gsd() {
  header "GSD (Get Shit Done) — versión mínima"
  info "Método por fases: spec → plan → ejecución → verificación."
  info "Se instala la versión mínima para no cargar contexto de más."
  # Global con npm (no npx) para que el comando gsd-sdk quede en el PATH
  if ! npm install -g get-shit-done-cc@latest; then
    error "Falló 'npm install -g get-shit-done-cc'"
    return 1
  fi
  if get-shit-done-cc --claude --global --minimal; then
    ok "GSD instalado (mínimo)"
  else
    error "Falló la instalación de GSD"
  fi
}

# ── Estado actual ────────────────────────────────────────────
view_current() {
  header "Configuración actual de Claude Code"

  echo -e "${BOLD}MCPs (scope user, en $CLAUDE_JSON):${RESET}"
  if [[ -f "$CLAUDE_JSON" ]] && jq -e '.mcpServers | length > 0' "$CLAUDE_JSON" &>/dev/null; then
    jq -r '.mcpServers | keys[]' "$CLAUDE_JSON" | sed 's/^/  • /'
  else
    echo -e "  ${YELLOW}Ninguno.${RESET}"
  fi

  echo
  echo -e "${BOLD}Skills (~/.claude/skills):${RESET}"
  if [[ -d "$HOME/.claude/skills" ]] && [[ -n "$(ls -A "$HOME/.claude/skills" 2>/dev/null)" ]]; then
    ls "$HOME/.claude/skills" | sed 's/^/  • /'
  else
    echo -e "  ${YELLOW}Ninguna.${RESET}"
  fi

  echo
  echo -e "${BOLD}Plugins:${RESET}"
  claude plugin list 2>/dev/null | sed 's/^/  /'
}

# ── Cierre: invitación a YouTube ─────────────────────────────
open_url() {
  if command -v open &>/dev/null; then open "$1"              # macOS
  elif command -v xdg-open &>/dev/null; then xdg-open "$1"   # Linux
  elif command -v cmd.exe &>/dev/null; then cmd.exe /c start "" "$1"  # Windows (Git Bash / WSL)
  else return 1
  fi &>/dev/null
}

outro() {
  echo
  echo -e "  ${BOLD}Esta herramienta es gratuita.${RESET}"
  echo -e "  Si te sirvió, te invito a suscribirte a mi canal de YouTube: ${CYAN}@frannoni${RESET}"
  echo
  open_url "$YOUTUBE_URL" || echo -e "  ${CYAN}→ $YOUTUBE_URL${RESET}"
}

# ── Banner ───────────────────────────────────────────────────
# '#' = bloque, '.' = sombra. Se pinta con un degradé de grises de izquierda a derecha.
BANNER_ROWS=(
'###### #####   ####  ##  ## ##  ##  ####  ##  ## ######     ##### ##     ######'
'##.....##..## ##..## ### ##.### ##.##..## ### ##. .##...   ##.....##.     .##...'
'##.    ##. ##.##. ##.######.######.##. ##.######.  ##.     ##.    ##.      ##.'
'#####  #####..######.##.###.##.###.##. ##.##.###.  ##.     ##.    ##.      ##.'
'##.... ##.##. ##..##.##. ##.##. ##.##. ##.##. ##.  ##.     ##.    ##.      ##.'
'##.    ##. ## ##. ##.##. ##.##. ##.##. ##.##. ##.  ##.     ##.    ##.      ##.'
'##.    ##. ##.##. ##.##. ##.##. ##. ####..##. ##.######     ##### ###### ######'
' ..     ..  .. ..  .. ..  .. ..  ..  ....  ..  .. ......     ..... ...... ......'
)

banner() {
  local width=80 from=255 to=242   # grises de la paleta de 256 colores (232–255)
  local row i ch color line
  echo
  for row in "${BANNER_ROWS[@]}"; do
    line=""
    for ((i = 0; i < ${#row}; i++)); do
      ch="${row:i:1}"
      color=$(( from - (from - to) * i / (width - 1) ))
      case "$ch" in
        '#') line+="\033[38;5;${color}m█" ;;
        '.') line+="\033[38;5;${color}m░" ;;
        *)   line+=" " ;;
      esac
    done
    echo -e "${line}${RESET}"
  done
  echo
}

# ── Menú principal ───────────────────────────────────────────
show_menu() {
  clear 2>/dev/null || true
  banner
  echo -e "  ${GRAY}Instalador de Claude Code · MCPs · Skills · Plugins${RESET}"
  echo
  echo -e "  ${BOLD}¿Qué querés instalar?${RESET}"
  echo
  echo "  1) Todo (instala MCPs base, Skills y Plugins sin preguntar)"
  echo "  2) MCPs base (sin token)"
  echo "  3) MCPs opcionales (con token / cuenta)"
  echo "  4) Skills"
  echo "  5) Plugins"
  echo "  6) GSD (opcional, versión mínima)"
  echo "  7) Ver configuración actual"
  echo "  8) Salir"
  echo
  echo -n "  Opción [1-8]: "
}

main() {
  check_deps

  local option
  while true; do
    show_menu
    read -r option
    echo

    case "$option" in
      1) AUTO=true; install_base_mcps; install_optional_mcps; install_skills; install_plugins ;;
      2) install_base_mcps ;;
      3) install_optional_mcps ;;
      4) install_skills ;;
      5) install_plugins ;;
      6) install_gsd ;;
      7)
        view_current
        echo
        echo -n "Presioná Enter para volver al menú..."
        read -r
        continue
        ;;
      8) echo -e "${CYAN}¡Hasta luego!${RESET}"; exit 0 ;;
      *) warn "Opción inválida. Elegí entre 1 y 8."; sleep 1; continue ;;
    esac

    echo
    ok "¡Listo!"
    echo -e "  ${YELLOW}Reiniciá Claude Code para que tome los cambios.${RESET}"
    outro
    break
  done
}

main "$@"
