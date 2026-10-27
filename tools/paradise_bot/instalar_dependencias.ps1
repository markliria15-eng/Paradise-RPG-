# Instala tudo que o Paradise Bot precisa e configura a chave da OpenAI.
# Pode rodar quantas vezes quiser: pula o que já estiver instalado.
$ErrorActionPreference = "Continue"
$bot  = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $bot "..\..")).Path

function Titulo($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "  OK  $t" -ForegroundColor Green }
function Aviso($t)  { Write-Host "  !!  $t" -ForegroundColor Yellow }
function Tem($cmd)  { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function AtualizarPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}
function Winget($id, $nome) {
    if (-not (Tem "winget")) { Aviso "winget não existe neste Windows; instale $nome manualmente."; return }
    Write-Host "  Instalando $nome..." -ForegroundColor Gray
    winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent | Out-Host
    AtualizarPath
}

Write-Host "Paradise Bot - instalação" -ForegroundColor Cyan
Write-Host "Pasta do jogo: $repo"

Titulo "Git"
if (Tem "git") { Ok (git --version) } else { Winget "Git.Git" "Git" }

Titulo "Python 3"
$py = $null
if (Tem "py") { $py = "py" } elseif (Tem "python") { $py = "python" }
if (-not $py) { Winget "Python.Python.3.12" "Python 3.12"; if (Tem "py") { $py = "py" } elseif (Tem "python") { $py = "python" } }
if ($py) {
    Ok (& $py --version)
    Write-Host "  Instalando/atualizando Pillow..." -ForegroundColor Gray
    & $py -m pip install --upgrade --quiet pillow | Out-Host
    & $py -c "import PIL; print('  OK  Pillow', PIL.__version__)"
} else { Aviso "Python não ficou disponível. Feche e abra esta janela de novo depois da instalação." }

Titulo "Node.js (necessário para o Claude Code)"
if (Tem "node") { Ok ("Node " + (node --version)) } else { Winget "OpenJS.NodeJS.LTS" "Node.js LTS" }

Titulo "Claude Code"
if (Tem "claude") { Ok "Claude Code já instalado" }
elseif (Tem "npm") {
    Write-Host "  Instalando Claude Code..." -ForegroundColor Gray
    npm install -g @anthropic-ai/claude-code | Out-Host
    AtualizarPath
    if (Tem "claude") { Ok "Claude Code instalado" } else { Aviso "Instalou, mas o comando 'claude' ainda não aparece. Abra uma janela nova." }
} else { Aviso "npm não encontrado; feche e rode este instalador de novo depois do Node.js." }

Titulo "ffmpeg (vídeos)"
if (Tem "ffmpeg") { Ok "ffmpeg já instalado" } else { Winget "Gyan.FFmpeg" "ffmpeg" }

Titulo "Godot 4.6.3"
$godot = Join-Path $repo ".tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe"
if (Test-Path $godot) { Ok "Godot encontrado em .tools" } else { Aviso "Godot 4.6.3 não está em .tools\godot-4.6.3 (validação/gravação ficam desligadas)." }

Titulo "Configuração"
$cfg = Join-Path $bot "config.json"
if (Test-Path $cfg) { Ok "config.json já existe (mantido)" } else { Copy-Item (Join-Path $bot "config.example.json") $cfg; Ok "config.json criado" }

$envFile = Join-Path $bot ".env"
$temChave = (Test-Path $envFile) -and (Select-String -Path $envFile -Pattern "^OPENAI_API_KEY=.+" -Quiet)
if ($temChave) { Ok "Chave da OpenAI já configurada (.env)" }
else {
    Write-Host ""
    Write-Host "  Cole a sua chave da OpenAI (começa com sk-). Pegue em platform.openai.com/api-keys" -ForegroundColor Yellow
    Write-Host "  A chave fica só neste computador, no arquivo tools\paradise_bot\.env (ignorado pelo Git)." -ForegroundColor Gray
    $seguro = Read-Host "  OPENAI_API_KEY" -AsSecureString
    $chave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)).Trim()
    if ($chave) {
        Set-Content -Path $envFile -Value "OPENAI_API_KEY=$chave" -Encoding ASCII
        Ok "Chave salva em .env"
    } else { Aviso "Nenhuma chave informada; o bot roda sem gerar artes e sem voz. Rode este instalador de novo para adicionar." }
}

Titulo "Login do Claude Code"
if (Tem "claude") {
    Write-Host "  Se for a primeira vez, uma janela vai abrir para você entrar na sua conta Claude." -ForegroundColor Gray
    Write-Host "  Depois do login, digite /exit e aperte ENTER para voltar aqui." -ForegroundColor Gray
    $resp = Read-Host "  Abrir o Claude Code agora para fazer login? (s/N)"
    if ($resp -match "^[sS]") { Push-Location $repo; claude; Pop-Location }
}

Titulo "Pronto"
Write-Host "  Para usar: dê dois cliques em tools\paradise_bot\iniciar_bot.bat e digite CONTINUAR." -ForegroundColor Green
Write-Host "  Se algo foi instalado agora, feche esta janela antes de abrir o bot." -ForegroundColor Gray
Read-Host "  Aperte ENTER para fechar"
