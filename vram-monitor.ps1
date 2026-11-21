# AICK Studio LIVE - shows GPU memory and load once per second (Ctrl+C to stop)
$host.UI.RawUI.WindowTitle = "VRAM monitor"
while ($true) {
  $q = (& nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits) -split ","
  $used = [int]$q[1].Trim(); $total = [int]$q[2].Trim()
  $pct = [math]::Round(100 * $used / $total)
  $bar = ("#" * [math]::Round($pct / 4)).PadRight(25, ".")
  Clear-Host
  Write-Host ""
  Write-Host ("  " + $q[0].Trim()) -ForegroundColor Cyan
  Write-Host ("  VRAM  [{0}] {1:N1} / {2:N1} GB  ({3}%)" -f $bar, ($used / 1024), ($total / 1024), $pct) -ForegroundColor Green
  Write-Host ("  GPU load {0}%   temp {1} C" -f $q[3].Trim(), $q[4].Trim()) -ForegroundColor Yellow
  Start-Sleep -Seconds 1
}
