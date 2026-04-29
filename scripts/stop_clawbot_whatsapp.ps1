param(
  [string]$RepoRoot = "D:\Work\bitflow_pr50_clean"
)

$ErrorActionPreference = "Continue"
$matches = Get-CimInstance Win32_Process |
  Where-Object {
    $_.Name -match "^(node|cmd)(\.exe)?$" -and
    $_.CommandLine -match "whatsapp_web_qr_bot\.mjs|clawbot-whatsapp"
  }

if (-not $matches) {
  Write-Host "No Clawbot WhatsApp Node process found for $RepoRoot." -ForegroundColor Yellow
  exit 0
}

foreach ($proc in $matches) {
  Write-Host "Stopping Clawbot WhatsApp process PID $($proc.ProcessId)" -ForegroundColor Cyan
  Stop-Process -Id $proc.ProcessId -Force
}
