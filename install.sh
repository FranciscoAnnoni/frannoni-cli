#!/usr/bin/env bash
# ============================================================
#  FRANNONI CLI — arranque para macOS / Linux
#  Instala lo que falte (Node, Git, Claude Code; Warp si querés) y corre el instalador.
#
#  curl -fsSL https://raw.githubusercontent.com/FranciscoAnnoni/frannoni-cli/main/install.sh | bash
# ============================================================

set -euo pipefail

REPO="FranciscoAnnoni/frannoni-cli"
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
has()  { command -v "$1" &>/dev/null; }
# </dev/tty: con curl | bash la entrada es el script, la respuesta se lee del teclado
ask_yn() { local a; read -r -p "$1 [s/N]: " a </dev/tty || return 1; [[ "$a" =~ ^[sS]$ ]]; }
# Claude Code y el instalador necesitan Node 18 o más nuevo
node_ok() { has node && [[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ]]; }

OS="$(uname -s)"

# ── Dependencias ─────────────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  if ! has brew; then
    info "Instalando Homebrew (te va a pedir la contraseña de la Mac)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  node_ok || { info "Instalando Node..."; brew install node || brew upgrade node; }
  has git || { info "Instalando Git...";  brew install git; }
  if [[ -d /Applications/Warp.app ]]; then
    ok "Warp ya está instalado."
  elif ask_yn "¿Querés instalar Warp (la terminal que recomiendo para Claude Code)?"; then
    info "Instalando Warp..."
    brew install --cask warp || warn "No se pudo instalar Warp — seguí con esta terminal."
  else
    info "Se saltea Warp."
  fi
else
  if ! node_ok; then
    has apt-get || die "Necesitás Node 18 o más nuevo (https://nodejs.org). Instalalo y volvé a correr este comando."
    # el nodejs de apt suele ser viejo (Ubuntu 22.04 trae Node 12): se usa el repo oficial de NodeSource
    info "Instalando Node LTS (te va a pedir sudo)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
  if ! has git; then
    has apt-get || die "Instalá Git y volvé a correr este comando."
    info "Instalando Git (te va a pedir sudo)..."
    sudo apt-get install -y git
  fi
fi
node_ok || die "Se necesita Node 18 o más nuevo y hay $(node -v 2>/dev/null || echo 'ninguno'). Actualizalo (https://nodejs.org) y volvé a correr este comando."

if ! has claude; then
  info "Instalando Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
fi

# ── Archivos del instalador ──────────────────────────────────
# Si se corre desde el repo clonado, se usan esos archivos; con curl | bash, se baja el repo.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
if [[ ! -f "$SRC/installer.mjs" ]]; then
  SRC="$(mktemp -d)/frannoni-cli"
  mkdir -p "$SRC"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar xz -C "$SRC" --strip-components=1
fi

[[ "${TERM_PROGRAM:-}" == "WarpTerminal" ]] || warn "Tip: para usar Claude Code te recomiendo la terminal Warp."

# </dev/tty: con curl | bash la entrada es el script, y el menú necesita leer el teclado
exec node "$SRC/installer.mjs" </dev/tty
