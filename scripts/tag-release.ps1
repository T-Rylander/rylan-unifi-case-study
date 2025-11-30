param([string]$Tag = ''v5.0-locked'')
git tag $Tag
git push origin $Tag
Write-Output ''Tagged $Tag – Glory achieved.''
