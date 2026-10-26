"""Ponte com o Claude Code em modo headless (claude -p)."""
from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path

from util import Cor, achar_executavel, say

# Leitura: só olha o projeto, não altera nada.
FERRAMENTAS_LEITURA = [
    "Read", "Grep", "Glob", "LS",
    "Bash(git status:*)", "Bash(git log:*)", "Bash(git diff:*)", "Bash(git show:*)",
    "Bash(rg:*)", "Bash(ls:*)", "Bash(dir:*)",
]

# Implementação: edita arquivos e roda validações locais.
FERRAMENTAS_IMPLEMENTAR = FERRAMENTAS_LEITURA + [
    "Edit", "MultiEdit", "Write", "TodoWrite",
    "Bash(node --check:*)", "Bash(node -e:*)",
    "Bash(python:*)", "Bash(py:*)", "Bash(python3:*)",
    "Bash(mkdir:*)", "Bash(cp:*)", "Bash(copy:*)",
]

# Nunca permitido ao Claude Code dentro do bot (regras do CLAUDE.md).
FERRAMENTAS_PROIBIDAS = [
    "Bash(git add:*)", "Bash(git commit:*)", "Bash(git push:*)", "Bash(git reset:*)",
    "Bash(git clean:*)", "Bash(git checkout:*)", "Bash(git stash:*)", "Bash(git rebase:*)",
    "Bash(git tag:*)", "Bash(git restore:*)", "Bash(rm -rf:*)", "Bash(del /s:*)",
    "Bash(npm install:*)", "Bash(npm i:*)", "Bash(pip install:*)",
    "Bash(npm run build-patch:*)",
]


@dataclass
class RespostaClaude:
    texto: str
    sessao: str | None
    erro: bool
    custo_usd: float = 0.0


class ClaudeCode:
    def __init__(self, repo: Path, comando: str = "claude", modelo: str = "", log_dir: Path | None = None):
        self.repo = repo
        self.exe = achar_executavel(comando)
        self.modelo = modelo
        self.log_dir = log_dir
        self.custo_total = 0.0

    def disponivel(self) -> bool:
        return self.exe is not None

    def rodar(self, prompt: str, modo: str = "leitura", sessao: str | None = None,
              nome_log: str = "claude", mostrar: bool = True, timeout_s: int = 3600) -> RespostaClaude:
        if not self.exe:
            raise RuntimeError("Claude Code não encontrado. Instale com: npm install -g @anthropic-ai/claude-code")
        permitidas = FERRAMENTAS_IMPLEMENTAR if modo == "implementar" else FERRAMENTAS_LEITURA
        bloqueadas = FERRAMENTAS_PROIBIDAS + ([] if modo == "implementar" else ["Edit", "MultiEdit", "Write", "NotebookEdit"])
        args = [self.exe, "-p", "--output-format", "stream-json", "--verbose",
                "--allowedTools", ",".join(permitidas),
                "--disallowedTools", ",".join(bloqueadas)]
        if modo == "implementar":
            args += ["--permission-mode", "acceptEdits"]
        if self.modelo:
            args += ["--model", self.modelo]
        if sessao:
            args += ["--resume", sessao]

        log = None
        if self.log_dir:
            self.log_dir.mkdir(parents=True, exist_ok=True)
            log = open(self.log_dir / f"{nome_log}.jsonl", "a", encoding="utf-8")

        proc = subprocess.Popen(args, cwd=self.repo, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
        assert proc.stdin and proc.stdout
        proc.stdin.write(prompt)
        proc.stdin.close()

        texto_final, sessao_id, erro, custo = "", sessao, False, 0.0
        textos: list[str] = []
        try:
            for linha in proc.stdout:
                if log:
                    log.write(linha)
                linha = linha.strip()
                if not linha:
                    continue
                try:
                    ev = json.loads(linha)
                except json.JSONDecodeError:
                    continue
                tipo = ev.get("type")
                if tipo == "system" and ev.get("session_id"):
                    sessao_id = ev["session_id"]
                elif tipo == "assistant":
                    for parte in ev.get("message", {}).get("content", []):
                        if parte.get("type") == "text" and parte.get("text", "").strip():
                            textos.append(parte["text"])
                            if mostrar:
                                say(_resumir(parte["text"], 600), Cor.CINZA)
                        elif parte.get("type") == "tool_use" and mostrar:
                            say(f"   ⚙ {parte.get('name')} {_resumo_ferramenta(parte.get('input', {}))}", Cor.AZUL)
                elif tipo == "result":
                    texto_final = ev.get("result") or ""
                    sessao_id = ev.get("session_id", sessao_id)
                    erro = bool(ev.get("is_error"))
                    custo = float(ev.get("total_cost_usd") or 0)
            proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            proc.kill()
            erro = True
            texto_final = "Tempo limite excedido."
        finally:
            if log:
                log.close()
        if proc.returncode not in (0, None) and not texto_final:
            erro = True
            texto_final = (proc.stderr.read() if proc.stderr else "") or "Claude Code terminou com erro."
        if not texto_final and textos:
            texto_final = textos[-1]
        self.custo_total += custo
        return RespostaClaude(texto_final, sessao_id, erro, custo)


def _resumir(texto: str, limite: int) -> str:
    texto = texto.strip()
    return texto if len(texto) <= limite else texto[:limite] + " …"


def _resumo_ferramenta(entrada: dict) -> str:
    for chave in ("file_path", "path", "pattern", "command", "description"):
        if chave in entrada:
            return _resumir(str(entrada[chave]), 90)
    return ""
