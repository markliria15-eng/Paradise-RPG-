"""Validações automáticas depois de cada implementação."""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from util import achar_executavel, comando_jogo, rodar

PADROES_ERRO_GODOT = re.compile(
    r"(SCRIPT ERROR|Parse Error|Failed to load script|Failed loading resource|"
    r"Invalid call|Cannot open file|ERROR: .*\.gd)", re.I)


def validar(repo: Path, arquivos_alterados: list[str], cfg: dict) -> tuple[bool, list[str]]:
    problemas: list[str] = []
    avisos: list[str] = []

    # 1) JSON
    for rel in arquivos_alterados:
        if rel.endswith(".json") and (repo / rel).is_file():
            try:
                json.loads((repo / rel).read_text(encoding="utf-8-sig"))
            except Exception as e:  # noqa: BLE001
                problemas.append(f"JSON inválido em {rel}: {e}")

    # 2) JS do backend
    node = achar_executavel("node")
    for rel in arquivos_alterados:
        if rel.endswith(".js") and rel.startswith("server/") and (repo / rel).is_file():
            if not node:
                avisos.append("node não encontrado; sintaxe JS não verificada.")
                break
            r = rodar([node, "--check", rel], cwd=repo, timeout=60)
            if r.returncode != 0:
                problemas.append(f"Erro de sintaxe JS em {rel}:\n{r.stderr.strip()[:800]}")

    # 3) Patches: dados que estão no manifesto precisam de cópia/manifesto coerentes
    manifesto = repo / "server/public/patches/manifest.json"
    if manifesto.exists():
        try:
            dados = json.loads(manifesto.read_text(encoding="utf-8"))
            texto_manifesto = json.dumps(dados)
        except Exception:  # noqa: BLE001
            texto_manifesto = ""
        for rel in arquivos_alterados:
            if rel.startswith("data/") and rel.endswith(".json"):
                nome = Path(rel).name
                if nome in texto_manifesto:
                    copia = repo / "server/public/patches/data" / nome
                    if copia.exists() and copia.read_bytes() != (repo / rel).read_bytes():
                        avisos.append(f"{rel} está no manifesto de patches e a cópia em server/public/patches/data "
                                      f"ficou diferente. Rode 'npm run build-patch' (na pasta server) quando for publicar.")

    # 4) Godot headless (boot curto)
    godot = achar_executavel(cfg.get("godot_exe", ""), repo)
    alterou_godot = any(a.endswith((".gd", ".tscn", ".tres", ".godot")) for a in arquivos_alterados)
    if godot and alterou_godot:
        try:
            args, env = comando_jogo(cfg, repo, headless=True)
            r = subprocess.run(args, cwd=repo, env=env, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=int(cfg.get("godot_timeout_s", 240)))
            saida = (r.stdout or "") + "\n" + (r.stderr or "")
            erros = [l for l in saida.splitlines() if PADROES_ERRO_GODOT.search(l)]
            if erros:
                problemas.append("Godot headless reportou erros:\n" + "\n".join(erros[:25]))
        except subprocess.TimeoutExpired:
            avisos.append("Godot headless passou do tempo limite (não conclusivo).")
    elif alterou_godot:
        avisos.append("godot_exe não configurado; scripts/cenas não foram abertos no Godot.")

    return (not problemas), problemas + [f"AVISO: {a}" for a in dict.fromkeys(avisos)]
