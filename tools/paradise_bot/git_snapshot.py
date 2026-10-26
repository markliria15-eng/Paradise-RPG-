"""Snapshots não destrutivos do working tree.

Usa um índice Git TEMPORÁRIO (GIT_INDEX_FILE) para fotografar todo o working tree,
inclusive arquivos não rastreados, sem tocar no índice real, no HEAD nem nos arquivos.
O snapshot fica guardado em refs/paradise-bot/<nome> e permite DESFAZER uma atualização
restaurando apenas os arquivos que ela alterou.
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

from util import rodar


class ErroGit(RuntimeError):
    pass


def _git(repo: Path, *args, env=None, entrada=None) -> str:
    r = rodar(["git", *args], cwd=repo, env=env, entrada=entrada, timeout=900)
    if r.returncode != 0:
        raise ErroGit(f"git {' '.join(args)} falhou:\n{r.stderr.strip()}")
    return r.stdout.strip()


def eh_repo_git(repo: Path) -> bool:
    try:
        return _git(repo, "rev-parse", "--is-inside-work-tree") == "true"
    except Exception:
        return False


def _arvore_atual(repo: Path, pasta_tmp: Path) -> str:
    """Grava a árvore do working tree atual (tracked + untracked, respeitando .gitignore)."""
    pasta_tmp.mkdir(parents=True, exist_ok=True)
    indice = Path(tempfile.mkstemp(prefix="indice_", dir=pasta_tmp)[1])
    try:
        env = dict(os.environ, GIT_INDEX_FILE=str(indice))
        indice.unlink(missing_ok=True)
        try:
            _git(repo, "read-tree", "HEAD", env=env)  # acelera: parte do HEAD
        except ErroGit:
            pass
        _git(repo, "add", "-A", env=env)
        return _git(repo, "write-tree", env=env)
    finally:
        indice.unlink(missing_ok=True)


def criar_snapshot(repo: Path, nome: str, pasta_tmp: Path) -> str:
    arvore = _arvore_atual(repo, pasta_tmp)
    try:
        pai = ["-p", _git(repo, "rev-parse", "HEAD")]
    except ErroGit:
        pai = []
    commit = _git(repo, "commit-tree", arvore, *pai, "-m", f"paradise-bot snapshot {nome}")
    _git(repo, "update-ref", f"refs/paradise-bot/{nome}", commit)
    return commit


def mudancas_desde(repo: Path, snapshot: str, pasta_tmp: Path) -> list[tuple[str, str]]:
    """Lista (status, caminho) do que mudou entre o snapshot e o working tree atual."""
    atual = _arvore_atual(repo, pasta_tmp)
    saida = _git(repo, "diff", "--no-renames", "--name-status", f"{snapshot}^{{tree}}", atual)
    itens = []
    for linha in saida.splitlines():
        if "\t" in linha:
            status, caminho = linha.split("\t", 1)
            itens.append((status.strip()[0], caminho.strip()))
    return itens


def diff_resumo(repo: Path, snapshot: str, pasta_tmp: Path, max_chars: int = 12000) -> str:
    atual = _arvore_atual(repo, pasta_tmp)
    stat = _git(repo, "diff", "--stat", f"{snapshot}^{{tree}}", atual)
    corpo = _git(repo, "diff", "--unified=2", f"{snapshot}^{{tree}}", atual, "--", "*.gd", "*.js", "*.json", "*.tscn", "*.md")
    texto = stat + "\n\n" + corpo
    return texto if len(texto) <= max_chars else texto[:max_chars] + "\n...[diff cortado]"


def desfazer(repo: Path, snapshot: str, pasta_tmp: Path) -> list[str]:
    """Restaura só os arquivos alterados desde o snapshot. Retorna a lista do que foi revertido."""
    mudancas = mudancas_desde(repo, snapshot, pasta_tmp)
    restaurar = [c for s, c in mudancas if s in ("M", "D", "T")]
    for s, c in mudancas:
        if s == "A":
            alvo = repo / c
            if alvo.is_file():
                alvo.unlink()
    if restaurar:
        lista = pasta_tmp / "restaurar.txt"
        lista.write_text("\n".join(restaurar) + "\n", encoding="utf-8")
        _git(repo, "restore", f"--source={snapshot}", "--worktree", f"--pathspec-from-file={lista}")
        lista.unlink(missing_ok=True)
    return [c for _, c in mudancas]


def commit_dos_arquivos(repo: Path, arquivos: list[str], mensagem: str) -> str:
    """Commit SOMENTE dos caminhos informados (nunca git add .). Não faz push."""
    existentes = [a for a in arquivos if (repo / a).exists()]
    removidos = [a for a in arquivos if not (repo / a).exists()]
    if existentes:
        _git(repo, "add", "--", *existentes)
    if removidos:
        _git(repo, "rm", "--cached", "--ignore-unmatch", "-q", "--", *removidos)
    _git(repo, "commit", "-m", mensagem, "--", *arquivos)
    return _git(repo, "rev-parse", "--short", "HEAD")


def head_curto(repo: Path) -> str:
    try:
        return _git(repo, "rev-parse", "--short", "HEAD")
    except ErroGit:
        return "sem-commit"
