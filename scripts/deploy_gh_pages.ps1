param(
  [string]$Flutter = "flutter",
  [string]$Branch = "gh-pages",
  [string]$BaseHref = "",
  [string]$ProCtaUrl = "",
  [string]$SupportEmail = "",
  [string]$SupportWhatsApp = "",
  [switch]$SkipBuild,
  [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Run-Git {
  param([string[]]$GitArgs)
  & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE)."
  }
}

try {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git no esta disponible en PATH."
  }

  if (-not $AllowDirty) {
    $status = git status --porcelain
    if ($status) {
      throw "Working tree con cambios. Usa -AllowDirty si quieres continuar."
    }
  }

  if (-not $SkipBuild) {
    & "$PSScriptRoot\release_web.ps1" `
      -Flutter $Flutter `
      -BaseHref $BaseHref `
      -ProCtaUrl $ProCtaUrl `
      -SupportEmail $SupportEmail `
      -SupportWhatsApp $SupportWhatsApp
    if ($LASTEXITCODE -ne 0) {
      throw "release_web.ps1 fallo."
    }
  }

  $webOut = Join-Path $repoRoot "build\web"
  if (-not (Test-Path $webOut)) {
    throw "No existe build/web. Ejecuta primero release_web.ps1."
  }

  $tmp = Join-Path $repoRoot ".tmp_gh_pages_worktree"
  if (Test-Path $tmp) {
    Remove-Item $tmp -Recurse -Force
  }

  Run-Git -GitArgs @("fetch", "origin", $Branch)

  $remoteRef = "refs/remotes/origin/$Branch"
  $remoteExists = (git show-ref $remoteRef) -ne $null

  if ($remoteExists) {
    Run-Git -GitArgs @("worktree", "add", "$tmp", "origin/$Branch")
  }
  else {
    Run-Git -GitArgs @("worktree", "add", "-b", $Branch, "$tmp")
  }

  try {
    Push-Location $tmp

    Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $webOut "*") -Destination $tmp -Recurse -Force

    New-Item -ItemType File -Path ".nojekyll" -Force | Out-Null

    Run-Git -GitArgs @("add", "-A")

    $hasChanges = git status --porcelain
    if (-not $hasChanges) {
      Write-Host "Sin cambios para publicar en $Branch." -ForegroundColor Yellow
      return
    }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Run-Git -GitArgs @("commit", "-m", "deploy: web release $stamp")
    Run-Git -GitArgs @("push", "origin", "HEAD:$Branch")

    Write-Host "Deploy completado a branch '$Branch'." -ForegroundColor Green
  }
  finally {
    Pop-Location
    Run-Git -GitArgs @("worktree", "remove", "$tmp", "--force")
    if (Test-Path $tmp) {
      Remove-Item $tmp -Recurse -Force
    }
  }
}
finally {
  Pop-Location
}
