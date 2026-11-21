<#
  AICK Studio LIVE - start SenseNova-Loop-9B + the App Builder page
  Usage (normal PowerShell is fine):
    cd .\sensenova-loop-9b-app-builder
    .\start-live.ps1                 # text mode, 32K context
    .\start-live.ps1 -Vision         # also load the image projector (sketch-to-app)
    .\start-live.ps1 -Ctx 16384      # smaller context if VRAM gets tight
  Stop the model: press Ctrl+C in this window.
#>
param(
  [string]$Root  = "C:\aick-live",
  [string]$Quant = "Q4_K_M",
  [int]$Ctx      = 32768,
  [int]$Port     = 8080,
  [switch]$Vision
)
$ErrorActionPreference = "Stop"

$exe = Get-ChildItem -Path (Join-Path $Root "llama.cpp-sensenova\build") -Filter "llama-server.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { throw "llama-server.exe not found. Run .\setup.ps1 first." }
$model = Join-Path $Root "models\SenseNova-Loop-9B-$Quant.gguf"
if (-not (Test-Path $model)) { throw "Model not found: $model. Run .\setup.ps1 first." }
$ui = Join-Path $PSScriptRoot "ui"

$a = @("-m", $model, "--jinja", "-ngl", "99", "-c", "$Ctx",
       "--host", "127.0.0.1", "--port", "$Port",
       "--alias", "SenseNova-Loop-9B-$Quant",
       "--path", $ui)
if ($Vision) {
  $mm = Join-Path $Root "models\mmproj-SenseNova-Loop-9B-F16.gguf"
  if (Test-Path $mm) { $a += @("--mmproj", $mm) } else { Write-Host "Vision projector not found, starting text-only." -ForegroundColor Yellow }
}

$url = "http://127.0.0.1:$Port/"
# Open the App Builder in the browser as soon as the model is ready
Start-Job -ArgumentList $url -ScriptBlock {
  param($u)
  for ($i = 0; $i -lt 300; $i++) {
    try { if ((Invoke-RestMethod ($u + "health") -TimeoutSec 2).status -eq "ok") { Start-Process $u; break } } catch {}
    Start-Sleep -Seconds 1
  }
} | Out-Null

Clear-Host
Write-Host ""
Write-Host "  SenseNova-Loop-9B  |  $Quant  |  context $Ctx  |  100% local, no cloud" -ForegroundColor Cyan
Write-Host "  App Builder opens at $url when the model is loaded" -ForegroundColor Cyan
Write-Host "  Command:" -ForegroundColor DarkGray
Write-Host ("  " + $exe.FullName + " " + ($a -join " ")) -ForegroundColor DarkGray
Write-Host ""
& $exe.FullName @a
