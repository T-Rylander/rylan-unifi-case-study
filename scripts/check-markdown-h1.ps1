Param()
$ErrorActionPreference = 'Stop'
$root = (Get-Location)
$files = git -C $root ls-files "**/*.md"
$bad = @()
foreach ($f in $files) {
  $line = (Get-Content $f -First 1)
  if (-not $line.StartsWith('# ')) {
    $bad += $f
  }
}
if ($bad.Count -gt 0) {
  Write-Output "FAIL: Files without H1 header:";
  $bad | ForEach-Object { Write-Output " - $_" }
  exit 1
} else {
  Write-Output "OK: All Markdown files start with an H1 header"
}
