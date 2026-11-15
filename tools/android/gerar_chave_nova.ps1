# Gera a CHAVE NOVA de assinatura do Android (a antiga ficou publica no historico do GitHub)
# e, se o GitHub CLI estiver logado, grava os 3 secrets que o workflow release-android.yml usa.
#
# - A senha e digitada aqui (nao aparece na tela) e nunca e salva em arquivo nem no Git.
# - A chave fica FORA da pasta do jogo: %USERPROFILE%\ParadiseRPG_chaves\
# - Se ja existir uma chave nesse lugar, o script para (nao sobrescreve nada).
#
# uso: GERAR_CHAVE_ANDROID.bat (na raiz do jogo)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repo = "markliria15-eng/Paradise-RPG-"
$alias = "paradise"
$destDir = Join-Path $env:USERPROFILE "ParadiseRPG_chaves"
$keystore = Join-Path $destDir "paradise-release-2026.keystore"

function Say($text, $color = "White") { Write-Host $text -ForegroundColor $color }

Say "============================================================" Cyan
Say " Paradise RPG - chave nova de assinatura do Android" Cyan
Say "============================================================" Cyan
Say ""
Say "Essa chave assina o APK. Guarde bem: sem ela nao da para lancar"
Say "atualizacoes do app. A chave vai para: $destDir"
Say ""

if (Test-Path -LiteralPath $keystore) {
    Say "Ja existe uma chave em $keystore." Yellow
    Say "Nao vou sobrescrever. Se quiser gerar outra, mova ou renomeie a atual antes." Yellow
    exit 1
}

$keytool = Get-ChildItem -Path (Join-Path $root ".tools") -Recurse -Filter "keytool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $keytool) {
    $cmd = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { Say "Nao achei o keytool (vem com o Java JDK em .tools\jdk17)." Red; exit 1 }
    $keytoolPath = $cmd.Source
} else {
    $keytoolPath = $keytool.FullName
}

function Read-Secret($prompt) {
    $secure = Read-Host -AsSecureString $prompt
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

while ($true) {
    $pass1 = Read-Secret "Crie uma senha para a chave (minimo 6 letras/numeros)"
    if ($pass1.Length -lt 6) { Say "Senha curta demais, tente de novo." Yellow; continue }
    $pass2 = Read-Secret "Digite a mesma senha de novo"
    if ($pass1 -ne $pass2) { Say "As senhas nao conferem, tente de novo." Yellow; continue }
    break
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$env:PARADISE_KEY_PASS = $pass1
try {
    & $keytoolPath -genkeypair -v -keystore $keystore -alias $alias -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass:env PARADISE_KEY_PASS -keypass:env PARADISE_KEY_PASS `
        -dname "CN=Paradise RPG, OU=Jogos, O=Paradise RPG, C=BR" | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $keystore)) { throw "o keytool nao conseguiu criar a chave" }
} finally {
    Remove-Item Env:\PARADISE_KEY_PASS -ErrorAction SilentlyContinue
}
Say ""
Say "Chave criada: $keystore" Green

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
$b64File = Join-Path $destDir "paradise-release-2026.keystore.base64.txt"
Set-Content -LiteralPath $b64File -Value $b64 -NoNewline -Encoding ascii
Set-Content -LiteralPath (Join-Path $destDir "LEIA-ME.txt") -Encoding utf8 -Value @"
Chave de assinatura Android do Paradise RPG (gerada em $(Get-Date -Format 'yyyy-MM-dd HH:mm')).
Apelido (alias): $alias
A senha NAO esta salva aqui: guarde-a num gerenciador de senhas.
Faca uma copia desta pasta num pendrive ou na nuvem. Sem a chave nao da para atualizar o app.
NUNCA coloque esta pasta dentro da pasta do jogo nem no GitHub.
"@

$gh = Get-ChildItem -Path (Join-Path $root ".tools\gh") -Recurse -Filter "gh.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
$saved = $false
if ($null -ne $gh) {
    & $gh.FullName auth status *> $null
    if ($LASTEXITCODE -eq 0) {
        Say "Gravando os secrets no GitHub ($repo)..." Cyan
        $b64 | & $gh.FullName secret set ANDROID_RELEASE_KEYSTORE_BASE64 -R $repo
        $alias | & $gh.FullName secret set ANDROID_RELEASE_KEY_ALIAS -R $repo
        $pass1 | & $gh.FullName secret set ANDROID_RELEASE_KEY_PASSWORD -R $repo
        if ($LASTEXITCODE -eq 0) { $saved = $true }
    }
}
$pass1 = $null; $pass2 = $null

Say ""
if ($saved) {
    Say "Pronto! Os 3 secrets foram gravados no GitHub. O proximo release ja sai com a chave nova." Green
} else {
    Say "Falta gravar os secrets no GitHub (o GitHub CLI nao esta logado):" Yellow
    Say "  1. Abra https://github.com/$repo/settings/secrets/actions"
    Say "  2. 'New repository secret' 3 vezes:"
    Say "     ANDROID_RELEASE_KEYSTORE_BASE64 = conteudo do arquivo $b64File"
    Say "     ANDROID_RELEASE_KEY_ALIAS       = $alias"
    Say "     ANDROID_RELEASE_KEY_PASSWORD    = a senha que voce acabou de criar"
}
Say ""
Say "IMPORTANTE: quem ja instalou o APK antigo precisa desinstalar uma vez antes de" Yellow
Say "instalar o novo (a assinatura mudou). Depois disso as atualizacoes voltam ao normal." Yellow
Say "Faca uma copia de seguranca da pasta $destDir agora." Yellow
