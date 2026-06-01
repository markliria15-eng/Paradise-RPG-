param(
    [string]$Message = "Atualiza Paradise RPG"
)

$ErrorActionPreference = "Stop"

git add .

$hasChanges = git status --short
if ($hasChanges) {
    git commit -m $Message
} else {
    Write-Host "Nenhuma alteracao nova para commitar."
}

git branch -M main

$remote = git remote get-url origin 2>$null
if (-not $remote) {
    git remote add origin https://github.com/markliria15-eng/Paradise-RPG-.git
}

git push -u origin main
