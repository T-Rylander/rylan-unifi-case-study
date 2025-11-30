<#
Tags the repository with v5.0-locked and pushes the tag.
#>

param(
    [string]$Tag = "v5.0-locked"
)

Write-Host "Tagging current commit with '$Tag' and pushing..." -ForegroundColor Cyan

$branch = git rev-parse --abbrev-ref HEAD
if ($LASTEXITCODE -ne 0) { Write-Error "Not a git repo"; exit 1 }

$exists = git tag --list $Tag
if ($exists) {
    Write-Host "Tag '$Tag' already exists. Re-tagging current commit." -ForegroundColor Yellow
    git tag -d $Tag
}

git tag $Tag
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create tag"; exit 1 }

git push origin $Tag
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to push tag"; exit 1 }

Write-Host "✅ Tag '$Tag' pushed to origin" -ForegroundColor Green
