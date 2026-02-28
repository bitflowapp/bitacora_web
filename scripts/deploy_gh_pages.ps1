param(
  [string]$Flutter = "flutter",
  [string]$Branch = "gh-pages",
  [switch]$SkipBuild,
  [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Run-Git {
  param([string[]]$Args)
  & git @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Args -join ' ') failed (exit $LASTEXITCODE)."
  }
}

try {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git no está disponible en PATH."
  }

  if (-not $AllowDirty) {
    $status = git status --porcelain
    if ($status) {
      throw "Working tree con cambios. Usa -AllowDirty si quieres continuar."
    }
  }

  if (-not $SkipBuild) {
    & "$PSScriptRoot\\release_web.ps1" -Flutter $Flutter
    if ($LASTEXITCODE -ne 0) {
      throw "release_web.ps1 falló."
    }
  }

  $webOut = Join-Path $repoRoot "build\\web"
  if (-not (Test-Path $webOut)) {
    throw "No existe build/web. Ejecuta primero release_web.ps1."
  }

  $tmp = Join-Path $repoRoot ".tmp_gh_pages_worktree"
  if (Test-Path $tmp) {
    Remove-Item $tmp -Recurse -Force
  }

  Run-Git -Args @("fetch", "origin", $Branch)

  $remoteRef = "refs/remotes/origin/$Branch"
  $remoteExists = (git show-ref $remoteRef) -ne $null

  if ($remoteExists) {
    Run-Git -Args @("worktree", "add", "$tmp", "origin/$Branch")
  } else {
    Run-Git -Args @("worktree", "add", "-b", $Branch, "$tmp")
  }

  try {
    Push-Location $tmp

    Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $webOut "*") -Destination $tmp -Recurse -Force

    New-Item -ItemType File -Path ".nojekyll" -Force | Out-Null

    Run-Git -Args @("add", "-A")

    $hasChanges = git status --porcelain
    if (-not $hasChanges) {
      Write-Host "Sin cambios para publicar en $Branch." -ForegroundColor Yellow
      return
    }

    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Run-Git -Args @("commit", "-m", "deploy: web release $stamp")
    Run-Git -Args @("push", "origin", "HEAD:$Branch")

    Write-Host "Deploy completado a branch '$Branch'." -ForegroundColor Green
  }
  finally {
    Pop-Location
    Run-Git -Args @("worktree", "remove", "$tmp", "--force")
    if (Test-Path $tmp) {
      Remove-Item $tmp -Recurse -Force
    }
  }
}
finally {
  Pop-Location
}
