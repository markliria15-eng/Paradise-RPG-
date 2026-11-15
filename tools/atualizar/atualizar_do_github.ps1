# Atualiza a pasta do jogo no notebook com o main do GitHub, sem perder nada.
#
# Por que nao "git pull": a pasta tem arquivos mexidos aqui (bot, Codex, pacotes zip do Claude)
# e o pull para no primeiro conflito. Este script:
#   1. baixa o main do GitHub (git fetch; pela chave SSH da pasta ou, se falhar, pelo HTTPS publico);
#   2. so continua se o notebook nao tiver commits proprios fora do GitHub;
#   3. para cada arquivo que mudou no GitHub: se o arquivo daqui for diferente do que o GitHub
#      tinha antes E do que tem agora (mudanca local), guarda uma copia em .tmp\backup_<data>\;
#   4. grava a versao nova desses arquivos e anda o "main" local ate o GitHub
#      (git reset --mixed: so mexe no ponteiro/indice, nunca apaga arquivo da pasta);
#   5. arquivo apagado no GitHub vai para o backup (nao e apagado de vez);
#   6. cria/atualiza o atalho "Atualizar Paradise RPG" na Area de Trabalho.
# Sem Git instalado: baixa o zip do GitHub (~1,3 GB) e copia so o que mudou, com o mesmo backup.
#
# uso: ATUALIZAR_E_TESTAR.bat (raiz do jogo) ou o atalho da Area de Trabalho

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $root
$repoHttps = "https://github.com/markliria15-eng/Paradise-RPG-.git"
$zipUrl = "https://codeload.github.com/markliria15-eng/Paradise-RPG-/zip/refs/heads/main"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $root ".tmp\backup_$stamp"

function Say($text, $color = "White") { Write-Host $text -ForegroundColor $color }
function Fail($text) {
    Say ""
    Say $text Red
    Say "Nada foi apagado. Tire um print desta janela e mande para o Claude." Red
    exit 1
}

function Make-Shortcut {
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (Test-Path -LiteralPath (Join-Path $desktop "Atualizar Paradise RPG.bat")) { return }
        $lnk = Join-Path $desktop "Atualizar Paradise RPG.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $s = $shell.CreateShortcut($lnk)
        $s.TargetPath = Join-Path $root "ATUALIZAR_E_TESTAR.bat"
        $s.WorkingDirectory = $root
        $s.Description = "Baixa a versao nova do Paradise RPG do GitHub e abre o teste offline"
        $icon = Join-Path $root ".tools\godot-4.6.3\Godot_v4.6.3-stable_win64.exe"
        if (Test-Path -LiteralPath $icon) { $s.IconLocation = "$icon,0" }
        $s.Save()
    } catch {
        Say "(nao consegui criar o atalho na Area de Trabalho: $($_.Exception.Message))" Yellow
    }
}

function Backup-File($rel) {
    $src = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { return }
    $dst = Join-Path $backup $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

function Find-Git {
    $cmd = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    $desktopApp = Get-ChildItem -Path "$env:LOCALAPPDATA\GitHubDesktop" -Recurse -Filter git.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*\cmd\git.exe" } | Select-Object -First 1
    if ($null -ne $desktopApp) { $candidates += $desktopApp.FullName }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

Say "============================================================" Cyan
Say " Paradise RPG: atualizando pelo GitHub (main)" Cyan
Say "============================================================" Cyan
Make-Shortcut

$git = Find-Git
if ($null -ne $git -and (Test-Path -LiteralPath (Join-Path $root ".git"))) {
    # ------------------------------------------------------------ caminho com Git
    Say "Baixando do GitHub..."
    & $git fetch --no-tags origin main
    if ($LASTEXITCODE -ne 0) {
        Say "A chave SSH nao funcionou; tentando pelo endereco publico (HTTPS)..." Yellow
        & $git fetch --no-tags $repoHttps main
        if ($LASTEXITCODE -ne 0) { Fail "Nao consegui baixar do GitHub (sem internet?)." }
    }
    $new = (& $git rev-parse FETCH_HEAD).Trim()
    $old = (& $git rev-parse HEAD).Trim()
    if ($new -eq $old) {
        Say "Ja esta na versao mais nova do GitHub ($($new.Substring(0,8)))." Green
        exit 0
    }
    & $git merge-base --is-ancestor $old $new
    if ($LASTEXITCODE -ne 0) {
        Fail "Este notebook tem commits que nao estao no GitHub; nao vou mexer sozinho."
    }

    Say "Comparando arquivos ($($old.Substring(0,8)) -> $($new.Substring(0,8)))..."
    $oldBlobs = @{}
    foreach ($line in (& $git ls-tree -r $old)) {
        $tab = $line.IndexOf("`t"); if ($tab -lt 0) { continue }
        $oldBlobs[$line.Substring($tab + 1)] = $line.Split(" ")[2].Split("`t")[0]
    }
    $newBlobs = @{}
    foreach ($line in (& $git ls-tree -r $new)) {
        $tab = $line.IndexOf("`t"); if ($tab -lt 0) { continue }
        $newBlobs[$line.Substring($tab + 1)] = $line.Split(" ")[2].Split("`t")[0]
    }
    $changed = @()
    $deleted = @()
    foreach ($line in (& $git diff --name-status --no-renames $old $new)) {
        $parts = $line.Split("`t")
        if ($parts.Count -lt 2) { continue }
        if ($parts[0] -eq "D") { $deleted += $parts[1] } else { $changed += $parts[1] }
    }
    # hash dos arquivos daqui (um processo so, com as mesmas regras de fim de linha do Git)
    $existing = @($changed + $deleted | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf })
    $localHash = @{}
    if ($existing.Count -gt 0) {
        $hashes = @($existing | & $git hash-object --stdin-paths)
        for ($i = 0; $i -lt $existing.Count; $i++) { $localHash[$existing[$i]] = $hashes[$i] }
    }
    $toWrite = New-Object System.Collections.Generic.List[string]
    $saved = 0
    foreach ($rel in $changed) {
        $h = $localHash[$rel]
        if ($h -eq $newBlobs[$rel]) { continue }          # ja esta igual ao GitHub (pacote zip)
        if ($null -ne $h -and $h -ne $oldBlobs[$rel]) { Backup-File $rel; $saved++ }  # mudanca local
        $toWrite.Add($rel)
    }
    $removed = 0
    $keptLocal = @()
    foreach ($rel in $deleted) {
        $h = $localHash[$rel]
        if ($null -eq $h) { continue }
        Backup-File $rel
        if ($h -eq $oldBlobs[$rel]) {
            Remove-Item -LiteralPath (Join-Path $root $rel) -Force
            $removed++
        } else {
            $keptLocal += $rel; $saved++
        }
    }
    if ($toWrite.Count -gt 0) {
        $list = Join-Path $root ".tmp\atualizar_lista.txt"
        New-Item -ItemType Directory -Force -Path (Split-Path $list) | Out-Null
        [IO.File]::WriteAllLines($list, $toWrite)
        & $git checkout $new "--pathspec-from-file=$list"
        $code = $LASTEXITCODE
        Remove-Item -LiteralPath $list -Force -ErrorAction SilentlyContinue
        if ($code -ne 0) { Fail "O Git nao conseguiu gravar os arquivos novos (as copias de seguranca estao em $backup)." }
    }
    & $git reset -q --mixed $new
    if ($LASTEXITCODE -ne 0) { Fail "Arquivos atualizados, mas o Git nao conseguiu marcar a versao nova." }
    Say ""
    Say "Atualizado para $($new.Substring(0,8)): $($toWrite.Count) arquivos novos/alterados, $removed removidos." Green
    if ($saved -gt 0) { Say "Arquivos que voce tinha mudado aqui: $saved (copias em $backup)" Yellow }
    foreach ($k in $keptLocal) { Say "  mantido (o GitHub apagou, mas voce tinha mudado): $k" Yellow }
    Say ""
    & $git log --oneline -3
    exit 0
}

# ------------------------------------------------------------ sem Git: zip do GitHub
Say "Git nao encontrado: vou baixar o pacote completo do GitHub (~1,3 GB, so desta vez demora)." Yellow
Say "Dica: instalando o Git (https://git-scm.com) as proximas atualizacoes ficam bem mais rapidas." Yellow
$tmp = Join-Path $root ".tmp\github_main"
$zip = Join-Path $root ".tmp\github_main.zip"
New-Item -ItemType Directory -Force -Path (Split-Path $zip) | Out-Null
& curl.exe -L --fail -o $zip $zipUrl
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $zip)) { Fail "Nao consegui baixar o pacote do GitHub." }
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
Say "Abrindo o pacote..."
try { Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force } catch { Fail "O pacote baixado veio com defeito." }
$top = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
if ($null -eq $top) { Fail "O pacote baixado veio vazio." }
$n = 0; $b = 0
Get-ChildItem -LiteralPath $top.FullName -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($top.FullName.Length + 1)
    if ($rel -like ".github\*") { return }
    $dest = Join-Path $root $rel
    if (Test-Path -LiteralPath $dest) {
        if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $_.FullName).Hash) { return }
        Backup-File $rel; $b++
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
    $n++
}
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Say ""
Say "Atualizado: $n arquivos. Copias de seguranca: $b (em $backup)." Green
exit 0
