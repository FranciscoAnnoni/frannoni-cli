#!/usr/bin/env bash
# ============================================================
#  FRANNONI CLI — arranque para macOS / Linux
#  Instala lo que falte (Node, Git, Claude Code, Warp) y corre el instalador.
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

OS="$(uname -s)"

# ── Dependencias ─────────────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  if ! has brew; then
    info "Instalando Homebrew (te va a pedir la contraseña de la Mac)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  has node || { info "Instalando Node..."; brew install node; }
  has git  || { info "Instalando Git...";  brew install git; }
  if [[ -d /Applications/Warp.app ]]; then
    ok "Warp ya está instalado."
  else
    info "Instalando Warp (terminal recomendada)..."
    brew install --cask warp || warn "No se pudo instalar Warp — seguí con esta terminal."
  fi
else
  if ! has node || ! has git; then
    has apt-get || die "Instalá Node (https://nodejs.org) y Git, y volvé a correr este comando."
    info "Instalando Node y Git (te va a pedir sudo)..."
    sudo apt-get update -qq && sudo apt-get install -y nodejs npm git
  fi
fi

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
