param(
	[string]$Godot = "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe",
	[string]$OutDir = "build/web"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 0. Strip accidental UTF-8 BOMs (they break ConfigFile / font glyph scans).
python tools/strip_bom.py

# 1. Rebuild the CJK subset every time, so new UI strings can never be missing
#    on the web build (desktop silently falls back to system fonts; web does not).
python tools/build_font.py
if ($LASTEXITCODE -ne 0) { throw "Font build failed" }

python tools/build_icons.py
if ($LASTEXITCODE -ne 0) { throw "PWA icon build failed" }

New-Item -ItemType Directory -Force $OutDir | Out-Null
if (-not (Test-Path "build\.gdignore")) { New-Item -ItemType File "build\.gdignore" | Out-Null }

# 2. Refresh Godot's import cache and export.
& $Godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

& $Godot --headless --path $root --export-release "Web" (Join-Path $OutDir "index.html")
if ($LASTEXITCODE -ne 0) { throw "Godot Web export failed" }

python tools/patch_pwa.py
if ($LASTEXITCODE -ne 0) { throw "PWA manifest patch failed" }

Write-Output ""
Write-Output "Web build ready: $OutDir"
Get-ChildItem $OutDir | Sort-Object Name | Select-Object Name, Length
