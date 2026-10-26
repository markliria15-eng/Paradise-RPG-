"""Utilitários compartilhados do bot de melhorias do Paradise RPG."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

BOT_DIR = Path(__file__).resolve().parent


def configurar_console() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if os.name == "nt":
        os.system("")  # habilita cores ANSI no terminal do Windows


class Cor:
    RESET = "\033[0m"
    NEGRITO = "\033[1m"
    VERDE = "\033[92m"
    AMARELO = "\033[93m"
    AZUL = "\033[94m"
    CIANO = "\033[96m"
    VERMELHO = "\033[91m"
    CINZA = "\033[90m"


def say(texto: str = "", cor: str = "") -> None:
    print(f"{cor}{texto}{Cor.RESET if cor else ''}", flush=True)


def titulo(texto: str) -> None:
    linha = "═" * max(10, min(70, len(texto) + 4))
    say(f"\n{linha}\n  {texto}\n{linha}", Cor.CIANO + Cor.NEGRITO)


def agora() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M")


def carregar_json(caminho: Path, padrao):
    try:
        return json.loads(Path(caminho).read_text(encoding="utf-8"))
    except FileNotFoundError:
        return padrao
    except json.JSONDecodeError:
        say(f"Aviso: {caminho} está corrompido; usando valores padrão.", Cor.AMARELO)
        return padrao


def salvar_json(caminho: Path, dados) -> None:
    caminho = Path(caminho)
    caminho.parent.mkdir(parents=True, exist_ok=True)
    tmp = caminho.with_suffix(caminho.suffix + ".tmp")
    tmp.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(caminho)


def carregar_env_local() -> None:
    """Lê tools/paradise_bot/.env (ignorado pelo Git) sem sobrescrever variáveis já definidas."""
    arquivo = BOT_DIR / ".env"
    if not arquivo.exists():
        return
    for linha in arquivo.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        chave, valor = linha.split("=", 1)
        os.environ.setdefault(chave.strip(), valor.strip().strip('"').strip("'"))


def extrair_json(texto: str):
    """Pega o último bloco ```json``` do texto (ou o próprio texto, se for JSON puro)."""
    blocos = re.findall(r"```(?:json)?\s*(\{.*?\}|\[.*?\])\s*```", texto, flags=re.S)
    candidatos = list(reversed(blocos)) + [texto.strip()]
    for bruto in candidatos:
        try:
            return json.loads(bruto)
        except json.JSONDecodeError:
            continue
    # último recurso: do primeiro { ao último }
    ini, fim = texto.find("{"), texto.rfind("}")
    if ini != -1 and fim > ini:
        try:
            return json.loads(texto[ini : fim + 1])
        except json.JSONDecodeError:
            pass
    raise ValueError("Não encontrei JSON válido na resposta.")


def achar_executavel(nome_ou_caminho: str, repo: Path | None = None) -> str | None:
    if not nome_ou_caminho:
        return None
    p = Path(nome_ou_caminho)
    if not p.is_absolute() and repo is not None and (repo / p).exists():
        return str((repo / p).resolve())
    if p.exists():
        return str(p.resolve())
    return shutil.which(nome_ou_caminho)


def rodar(args, cwd=None, timeout=None, env=None, entrada=None) -> subprocess.CompletedProcess:
    return subprocess.run(
        args,
        cwd=cwd,
        input=entrada,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        env=env,
    )


def perguntar(texto: str) -> str:
    try:
        return input(f"{Cor.AMARELO}{texto}{Cor.RESET} ").strip()
    except EOFError:
        return "SAIR"


def comando_jogo(cfg: dict, repo: Path, headless: bool = False) -> tuple[list[str], dict] | tuple[None, None]:
    """Comando e ambiente para abrir o jogo direto no gameplay offline (igual ao TESTAR_JOGO_OFFLINE.bat)."""
    godot = achar_executavel(cfg.get("godot_exe", ""), repo)
    if not godot:
        return None, None
    args = [godot, "--path", str(repo)]
    if headless:
        args += ["--headless", "--quit-after", str(cfg.get("godot_quit_after", 600))]
    else:
        args += list(cfg.get("godot_args_janela", []))
    args += list(cfg.get("godot_args_jogo", []))
    env = dict(os.environ, **{k: str(v) for k, v in (cfg.get("godot_env") or {}).items()})
    return args, env
