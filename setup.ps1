<#
  AICK Studio LIVE kit - SenseNova-Loop-9B on Windows + NVIDIA (12 GB)
  ---------------------------------------------------------------------
  Run ONCE before the stream, in an ADMIN PowerShell window:

    Set-ExecutionPolicy -Scope Process Bypass -Force
    cd .\sensenova-loop-9b-app-builder
    .\setup.ps1

  Safe to re-run: every step skips work that is already done.
  Heavy files go to C:\aick-live  (source, build, models, logs).
#>
param(
  [string]$Root  = "C:\aick-live",
  [string]$Quant = "Q4_K_M",      # Q4_K_M (5.82 GB) | Q5_K_M (6.67 GB) | Q8_0 (9.8 GB)
  [switch]$SkipInstall,           # don't auto-install missing build tools
  [switch]$SkipSmokeTest
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$Commit = "24ea7bb78410e0f0f7bbb362e37c60cd9ecfc761"   # commit named on SenseNova's GGUF model card
$Repo   = "https://github.com/blueswhen/llama.cpp"      # branch sensenova-loop holds that commit
$Src    = Join-Path $Root "llama.cpp-sensenova"
$Build  = Join-Path $Src  "build"
$Models = Join-Path $Root "models"
$Logs   = Join-Path $Root "logs"
$NLog   = Join-Path $Logs "build-output.log"
New-Item -ItemType Directory -Force -Path $Root, $Models, $Logs | Out-Null
Start-Transcript -Path (Join-Path $Logs "setup.log") -Append | Out-Null

function Step([string]$t) { Write-Host ""; Write-Host "==== $t ====" -ForegroundColor Cyan }
function Ok([string]$t)   { Write-Host "  [OK] $t" -ForegroundColor Green }
function Warn([string]$t) { Write-Host "  [!!] $t" -ForegroundColor Yellow }
function Have([string]$c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }

# Run a native tool, show + log its output, return its exit code (no false "errors" from stderr)
function Run([string]$Exe, [string[]]$ArgList) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $Exe @ArgList 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $NLog -Append | Out-Host
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  return $code
}

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  $cp = [Environment]::GetEnvironmentVariable("CUDA_PATH", "Machine")
  if ($cp) { $env:CUDA_PATH = $cp; $env:Path = "$cp\bin;$env:Path" }
}

function Find-VS {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) { return $null }
  $p = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($p) { return ($p | Select-Object -First 1).Trim() }
  return $null
}

function Find-Server {
  if (-not (Test-Path $Build)) { return $null }
  Get-ChildItem -Path $Build -Filter "llama-server.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}

try {
  # ---------------------------------------------------------------- 1
  Step "1/6  Checking your GPU"
  if (-not (Have "nvidia-smi")) { throw "nvidia-smi not found. Install the latest NVIDIA Game Ready / Studio driver first." }
  $gpu = (& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader) -join "; "
  Ok "GPU: $gpu"

  # ---------------------------------------------------------------- 2
  Step "2/6  Build tools: Git, CMake, Visual Studio C++ Build Tools, CUDA Toolkit"
  Refresh-Path
  $need = @()
  if (-not (Have "git"))  { $need += "git" }
  if (-not (Have "cmake") -and -not (Find-VS)) { $need += "cmake" }
  if (-not (Find-VS))     { $need += "vs" }
  if (-not (Have "nvcc")) { $need += "cuda" }

  if ($need.Count -eq 0) {
    Ok "All build tools already installed"
  } elseif ($SkipInstall) {
    throw "Missing: $($need -join ', '). Re-run without -SkipInstall."
  } else {
    if (-not (Have "winget")) { throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run." }
    Warn "Installing: $($need -join ', ')  (watch the taskbar for Windows 'Yes/No' prompts)"
    $wg = @("--accept-source-agreements", "--accept-package-agreements", "-e", "--silent")
    if ($need -contains "git")   { Run "winget" (@("install", "--id", "Git.Git") + $wg) | Out-Null }
    if ($need -contains "cmake") { Run "winget" (@("install", "--id", "Kitware.CMake") + $wg) | Out-Null }
    if ($need -contains "vs")    {
      Run "winget" @("install", "--id", "Microsoft.VisualStudio.2022.BuildTools", "-e",
        "--accept-source-agreements", "--accept-package-agreements",
        "--override", "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended") | Out-Null
    }
    # CUDA must come AFTER Visual Studio so it can register with it
    if ($need -contains "cuda")  { Run "winget" (@("install", "--id", "Nvidia.CUDA") + $wg) | Out-Null }
    Refresh-Path
  }

  $vs = Find-VS
  if (-not $vs) { throw "Visual Studio C++ Build Tools still not found. Open 'Visual Studio Installer' and add 'Desktop development with C++'." }
  foreach ($t in @("git", "nvcc")) {
    if (-not (Have $t)) { throw "$t is installed but not on PATH yet. Close this window, open a NEW admin PowerShell and run .\setup.ps1 again." }
  }

  # Load the Visual Studio compiler environment into this PowerShell window
  Import-Module (Join-Path $vs "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
  Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64" | Out-Null
  if (-not (Have "cmake")) { throw "cmake not found even inside the Visual Studio shell." }

  Ok ("Visual Studio : " + $vs)
  Ok ((& git --version) -join " ")
  Ok ((& cmake --version | Select-Object -First 1) -join " ")
  Ok ((& nvcc --version | Select-String "release") -join " ")

  # ---------------------------------------------------------------- 3
  Step "3/6  Getting SenseNova's llama.cpp fork (commit 24ea7bb)"
  if (-not (Test-Path (Join-Path $Src ".git"))) {
    if ((Run "git" @("-c", "core.longpaths=true", "clone", "-b", "sensenova-loop", $Repo, $Src)) -ne 0) { throw "git clone failed (check internet / GitHub access)." }
  } else { Ok "Source folder already there" }
  # The sensenova-loop branch was rebased on Nov 20, so the commit the model card pins is no longer on any branch.
  # GitHub still serves it by its full hash, so fetch it directly before checking it out.
  if ((Run "git" @("-C", $Src, "fetch", "origin", $Commit)) -ne 0) { throw "Could not download commit $Commit from GitHub." }
  if ((Run "git" @("-C", $Src, "-c", "advice.detachedHead=false", "checkout", $Commit)) -ne 0) { throw "Could not check out commit $Commit." }
  Ok "Source ready: $Src"

  # ---------------------------------------------------------------- 4
  Step "4/6  Building llama-server with CUDA (first build takes 10-30 min - grab a coffee)"
  $exe = Find-Server
  if ($exe) {
    Ok "Already built: $($exe.FullName)"
  } else {
    $gen = @()
    if (Have "ninja") { $gen = @("-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release") }
    $cfg = @("-S", $Src, "-B", $Build) + $gen + @(
      "-DGGML_CUDA=ON",
      "-DCMAKE_CUDA_ARCHITECTURES=native",   # compile only for YOUR GPU = much faster build
      "-DLLAMA_USE_PREBUILT_UI=OFF",         # model card: without this the build looks for a UI release that doesn't exist
      "-DLLAMA_CURL=OFF",
      "-DLLAMA_BUILD_TESTS=OFF")
    if ((Run "cmake" $cfg) -ne 0) { throw "CMake configure failed. Send me C:\aick-live\logs\build-output.log" }
    if ((Run "cmake" @("--build", $Build, "--config", "Release", "-j", "--target", "llama-server", "llama-cli")) -ne 0) {
      throw "Build failed. Send me C:\aick-live\logs\build-output.log"
    }
    $exe = Find-Server
    if (-not $exe) { throw "Build finished but llama-server.exe was not found under $Build" }
    Ok "Built: $($exe.FullName)"
  }

  # ---------------------------------------------------------------- 5
  Step "5/6  Downloading SenseNova-Loop-9B ($Quant) + vision projector from Hugging Face"
  $files = @("SenseNova-Loop-9B-$Quant.gguf", "mmproj-SenseNova-Loop-9B-F16.gguf")
  foreach ($f in $files) {
    $dst  = Join-Path $Models $f
    $done = "$dst.done"
    if (Test-Path $done) { Ok "$f already downloaded"; continue }
    $url = "https://huggingface.co/sensenova/SenseNova-Loop-9B-GGUF/resolve/main/$f"
    Write-Host "  -> $url"
    & curl.exe -L --fail --retry 5 --retry-delay 3 -C - -o $dst $url
    if ($LASTEXITCODE -ne 0) { throw "Download failed for $f (curl exit $LASTEXITCODE). Re-run setup.ps1 to resume." }
    New-Item -ItemType File -Force -Path $done | Out-Null
    Ok ("{0}  ({1:N2} GB)" -f $f, ((Get-Item $dst).Length / 1GB))
  }

  # ---------------------------------------------------------------- 6
  if ($SkipSmokeTest) {
    Warn "Smoke test skipped"
  } else {
    Step "6/6  Smoke test: load the model on the GPU and measure speed"
    $model = Join-Path $Models "SenseNova-Loop-9B-$Quant.gguf"
    $out = Join-Path $Logs "server-smoke.out.log"; $err = Join-Path $Logs "server-smoke.err.log"
    $p = Start-Process -FilePath $exe.FullName -PassThru -WindowStyle Hidden `
         -RedirectStandardOutput $out -RedirectStandardError $err `
         -ArgumentList @("-m", "`"$model`"", "--jinja", "-ngl", "99", "-c", "8192", "--host", "127.0.0.1", "--port", "8091")
    $ready = $false
    for ($i = 0; $i -lt 240; $i++) {
      Start-Sleep -Seconds 1
      if ($p.HasExited) { break }
      try { if ((Invoke-RestMethod "http://127.0.0.1:8091/health" -TimeoutSec 2).status -eq "ok") { $ready = $true; break } } catch {}
    }
    if (-not $ready) {
      Get-Content $err -Tail 30 | Out-Host
      throw "Server did not start. Last lines of C:\aick-live\logs\server-smoke.err.log are shown above."
    }
    Ok "Model loaded"
    $body = @{
      messages             = @(@{ role = "user"; content = "In two short sentences, explain why running AI on your own PC matters." })
      max_tokens           = 160
      temperature          = 0.6
      chat_template_kwargs = @{ enable_thinking = $false }
    } | ConvertTo-Json -Depth 6
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r  = Invoke-RestMethod -Uri "http://127.0.0.1:8091/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600
    $sw.Stop()
    $tps = $r.timings.predicted_per_second
    if (-not $tps) { $tps = $r.usage.completion_tokens / [math]::Max($sw.Elapsed.TotalSeconds, 0.1) }
    $vram = (& nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader) -join "; "
    Write-Host ""
    Write-Host ("  Answer : " + $r.choices[0].message.content.Trim())
    Ok ("Speed  : {0:N1} tokens/sec" -f $tps)
    Ok ("VRAM   : " + $vram)
    @(
      "date=$(Get-Date -Format s)", "gpu=$gpu", "quant=$Quant",
      ("tokens_per_sec={0:N1}" -f $tps), "vram=$vram", "answer=$($r.choices[0].message.content.Trim())"
    ) | Set-Content (Join-Path $Logs "smoke.txt")
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  }

  Write-Host ""
  Write-Host "==================== SETUP COMPLETE ====================" -ForegroundColor Green
  Write-Host "  Start the live builder with:   .\start-live.ps1" -ForegroundColor Green
  Write-Host "  Watch VRAM in a 2nd window:    .\vram-monitor.ps1" -ForegroundColor Green
  Write-Host "=========================================================" -ForegroundColor Green
}
catch {
  Write-Host ""
  Write-Host "SETUP STOPPED: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Full log: C:\aick-live\logs\setup.log" -ForegroundColor Red
}
finally {
  Stop-Transcript | Out-Null
}
