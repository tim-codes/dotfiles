# Revert Satisfactory from CL 513885 (Steam update 2026-10-15) back to CL 495413,
# using the depot copy already on disk from the August downgrade. No download needed.

$game = "D:\SteamLibrary\steamapps\common\Satisfactory"
$old  = "D:\SteamLibrary\steamapps\common\Satisfactory-25782416"
$src  = "C:\Program Files (x86)\Steam\steamapps\content\app_526870\depot_526871"

function Fail($m) { Write-Host "ABORT: $m" -ForegroundColor Red; exit 1 }

# --- preflight ---------------------------------------------------------------
if (Get-Process -Name "FactoryGame*" -ErrorAction SilentlyContinue) { Fail "Satisfactory is running - close it first." }
if (-not (Test-Path $game)) { Fail "Game folder not found: $game" }
if (-not (Test-Path $src))  { Fail "Depot source not found: $src" }
if (Test-Path $old)         { Fail "$old already exists - move or delete it first." }

$v = Get-Content "$src\Engine\Binaries\Win64\FactoryGameSteam-Win64-Shipping.version" -Raw | ConvertFrom-Json
if ($v.BuildId -ne "495413") { Fail "Depot source is BuildId $($v.BuildId), expected 495413." }
if (-not (Test-Path "$src\FactoryGameSteam.exe")) { Fail "Depot source has no FactoryGameSteam.exe." }
if (-not (Test-Path "$game\FactoryGame\Mods")) { Fail "No Mods folder in current install - nothing to carry over." }

$free = (Get-PSDrive D).Free / 1GB
if ($free -lt 40) { Fail ("Only {0:N1} GB free on D: - need ~35 GB." -f $free) }
Write-Host ("Preflight OK. Depot source is CL {0}. {1:N0} GB free on D:.`n" -f $v.BuildId, $free)

# --- swap --------------------------------------------------------------------
Write-Host "1/3 Setting current 513885 install aside..."
Rename-Item -Path $game -NewName (Split-Path $old -Leaf) -ErrorAction Stop

Write-Host "2/3 Copying 495413 from depot cache (~29 GB, a few minutes)..."
robocopy $src $game /E /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "robocopy failed copying game files (exit $LASTEXITCODE)" }

Write-Host "3/3 Carrying your mods across..."
robocopy "$old\FactoryGame\Mods" "$game\FactoryGame\Mods" /E /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Fail "robocopy failed copying mods (exit $LASTEXITCODE)" }

# --- verify ------------------------------------------------------------------
$nv = Get-Content "$game\Engine\Binaries\Win64\FactoryGameSteam-Win64-Shipping.version" -Raw | ConvertFrom-Json
$modCount = (Get-ChildItem "$game\FactoryGame\Mods" -Directory).Count
Write-Host ""
Write-Host ("DONE. Game is now CL {0} ({1}), {2} mod folders restored." -f $nv.BuildId, $nv.GameVersion, $modCount) -ForegroundColor Green
Write-Host "The 513885 build is kept at: $old"
Write-Host "appmanifest still reports 25782416, so Steam will not re-patch this build."
