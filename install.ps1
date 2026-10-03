# ============================================================
#  FRANNONI CLI — arranque para Windows (PowerShell, también dentro de Warp)
#  Instala lo que falte (Node, Git, Claude Code, Warp) y corre el instalador.
#
#  irm https://raw.githubusercontent.com/FranciscoAnnoni/frannoni-cli/main/install.ps1 | iex
# ============================================================

# Todo va dentro de un bloque: con `irm | iex` un `exit` cerraría la ventana del usuario.
& {
  $ErrorActionPreference = 'Stop'
  $Repo = 'FranciscoAnnoni/frannoni-cli'

  function Info($m) { Write-Host '[INFO]  ' -ForegroundColor Cyan -NoNewline; Write-Host $m }
  function Ok($m)   { Write-Host '[OK]    ' -ForegroundColor Green -NoNewline; Write-Host $m }
  function Warn($m) { Write-Host '[WARN]  ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
  function Has($c)  { [bool](Get-Command $c -ErrorAction SilentlyContinue) }

  # winget instala pero no actualiza el PATH de esta sesión: se recarga a mano
  function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User') + ";$env:USERPROFILE\.local\bin"
  }

  function Winget-Install($id, $label) {
    Info "Instalando $label..."
    winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
  }

  # ── Dependencias ─────────────────────────────────────────
  if (-not (Has 'winget')) {
    Write-Host '[ERROR] Falta winget (App Installer). Instalalo desde Microsoft Store y volvé a correr el comando.' -ForegroundColor Red
    return
  }

  if (-not (Has 'node')) { Winget-Install 'OpenJS.NodeJS.LTS' 'Node.js' }
  # Claude Code en Windows necesita Git for Windows (usa su Git Bash)
  if (-not (Has 'git'))  { Winget-Install 'Git.Git' 'Git' }

  winget list --id Warp.Warp -e --accept-source-agreements *> $null
  if ($LASTEXITCODE -eq 0) { Ok 'Warp ya está instalado.' }
  else {
    try { Winget-Install 'Warp.Warp' 'Warp (terminal recomendada)' }
    catch { Warn 'No se pudo instalar Warp — seguí con esta terminal.' }
  }

  if (-not (Has 'claude')) {
    Info 'Instalando Claude Code...'
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Refresh-Path
  }

  # ── Archivos del instalador ──────────────────────────────
  # Si se corre desde el repo clonado, se usan esos archivos; con irm | iex, se baja el repo.
  $Src = $PSScriptRoot
  if (-not $Src -or -not (Test-Path (Join-Path $Src 'installer.mjs'))) {
    $Tmp = Join-Path $env:TEMP "frannoni-cli-$(Get-Random)"
    New-Item -ItemType Directory -Path $Tmp | Out-Null
    $Zip = Join-Path $Tmp 'repo.zip'
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $Zip -UseBasicParsing
    Expand-Archive $Zip -DestinationPath $Tmp
    $Src = Join-Path $Tmp 'frannoni-cli-main'
  }

  if ($env:TERM_PROGRAM -ne 'WarpTerminal') { Warn 'Tip: para usar Claude Code te recomiendo la terminal Warp.' }

  node (Join-Path $Src 'installer.mjs')
}
