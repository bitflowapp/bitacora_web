param(
    [string] $Owner = 'marcoluna-nqn',
    [string] $Repo = 'bitacora_web',
    [string] $AssetName = 'BitFlow-android.apk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
$downloadUrl = "https://github.com/$Owner/$Repo/releases/latest/download/$AssetName"

$headers = @{
    'Accept' = 'application/vnd.github+json'
    'User-Agent' = 'bitflow-release-check'
}

if ($env:GITHUB_TOKEN) {
    $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
}

Write-Host "Checking latest release: $apiUrl"

try {
    $latest = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers
} catch {
    throw "Could not read latest release for $Owner/$Repo. Ensure at least one tag release exists. Details: $($_.Exception.Message)"
}

if ($null -eq $latest -or [string]::IsNullOrWhiteSpace($latest.tag_name)) {
    throw "Latest release payload is invalid (missing tag_name)."
}

$assets = @()
if ($latest.assets) {
    $assets = @($latest.assets)
}

if ($assets.Count -eq 0) {
    throw "Latest release '$($latest.tag_name)' has no assets."
}

$asset = $assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
if ($null -eq $asset) {
    $known = ($assets | ForEach-Object { $_.name }) -join ', '
    throw "Asset '$AssetName' was not found in latest release '$($latest.tag_name)'. Assets: $known"
}

try {
    $head = Invoke-WebRequest -Method Head -Uri $downloadUrl -MaximumRedirection 0 -ErrorAction Stop
    $status = [int] $head.StatusCode
} catch {
    $resp = $_.Exception.Response
    $status = if ($resp) { [int] $resp.StatusCode } else { -1 }
}

if ($status -lt 200 -or $status -ge 400) {
    throw "Stable download URL check failed for '$downloadUrl' (status: $status)."
}

Write-Host "Latest tag: $($latest.tag_name)" -ForegroundColor Green
Write-Host "Asset verified: $($asset.name)" -ForegroundColor Green
Write-Host "Download URL: $downloadUrl" -ForegroundColor Green