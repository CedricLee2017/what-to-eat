param(
	[switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	if (-not $SkipBuild) {
		& powershell -ExecutionPolicy Bypass -File (Join-Path $root "tools\build_web.ps1")
		if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
	}

	python (Join-Path $root "tools\prepare_game_assets.py")
	if ($LASTEXITCODE -ne 0) { throw "Game asset preparation failed" }

	Push-Location (Join-Path $root "workers\game")
	try {
		& npx.cmd wrangler deploy
		if ($LASTEXITCODE -ne 0) { throw "Game Worker deploy failed" }
	} finally {
		Pop-Location
	}

	Push-Location (Join-Path $root "workers\leaderboard")
	try {
		& npx.cmd wrangler deploy
		if ($LASTEXITCODE -ne 0) { throw "Leaderboard Worker deploy failed" }
	} finally {
		Pop-Location
	}

	Compress-Archive -Path (Join-Path $root "build\web\*") -DestinationPath (Join-Path $root "build\web.zip") -Force
	Write-Host "Deployed game + leaderboard. Static zip: build\web.zip"
} finally {
	Pop-Location
}
