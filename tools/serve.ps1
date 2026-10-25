param(
	[int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$web = Join-Path $root "build\web"
if (-not (Test-Path (Join-Path $web "index.html"))) {
	throw "No web build found. Run tools\build_web.ps1 first."
}

Write-Output "Serving $web"
Write-Output "Open http://127.0.0.1:$Port/"
python -m http.server $Port --directory $web
