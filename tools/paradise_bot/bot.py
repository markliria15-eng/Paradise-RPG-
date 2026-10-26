"""Paradise Bot — melhorias contínuas de jogabilidade do Paradise RPG.

  ChatGPT (API OpenAI) -> desenha assets e chunks
  Claude Code          -> pesquisa ideias, programa e corrige
  Bot de vídeos        -> cada atualização aceita já começa a virar episódio

Uso (na raiz do jogo):  python tools/paradise_bot/bot.py
Depois é só digitar CONTINUAR.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from claude_code import ClaudeCode  # noqa: E402
from git_snapshot import (ErroGit, commit_dos_arquivos, criar_snapshot, desfazer, eh_repo_git,  # noqa: E402
                          head_curto, mudancas_desde)
from openai_assets import ErroOpenAI, GeradorAssets  # noqa: E402
from prompts import prompt_ajuste, prompt_corrigir, prompt_ideias, prompt_implementar  # noqa: E402
from util import (BOT_DIR, Cor, achar_executavel, agora, comando_jogo, carregar_env_local, carregar_json,  # noqa: E402
                  configurar_console, extrair_json, perguntar, salvar_json, say, titulo)
from validacao import validar  # noqa: E402
from video import BotVideos  # noqa: E402

AJUDA = f"""{Cor.NEGRITO}Comandos{Cor.RESET}
  {Cor.VERDE}CONTINUAR{Cor.RESET}        busca ideias novas (ou mostra as pendentes) para você aprovar
  {Cor.VERDE}1, 2, 3…{Cor.RESET}         aceita e implementa a ideia com esse número
  {Cor.VERDE}N{Cor.RESET}                nenhuma serve: descarta e busca outras
  {Cor.VERDE}IDEIA <texto>{Cor.RESET}    implementa uma ideia sua
  {Cor.VERDE}FOCO <texto>{Cor.RESET}     muda o foco das próximas ideias (ex.: FOCO combate e chefões)
  {Cor.VERDE}DESFAZER{Cor.RESET}         reverte a última atualização aplicada
  {Cor.VERDE}VIDEOS{Cor.RESET}           status dos episódios      {Cor.VERDE}VIDEO <n>{Cor.RESET}  remonta o episódio n
  {Cor.VERDE}STATUS{Cor.RESET}           histórico e custos        {Cor.VERDE}SAIR{Cor.RESET}       encerra"""


class ParadiseBot:
    def __init__(self, repo: Path, cfg: dict):
        self.repo = repo
        self.cfg = cfg
        self.dir = repo / ".paradise_bot"
        self.dir.mkdir(exist_ok=True)
        (self.dir / ".gitignore").write_text("*\n", encoding="utf-8")  # nada do bot entra no Git
        self.tmp = self.dir / "tmp"
        self.estado_arq = self.dir / "estado.json"
        self.estado = carregar_json(self.estado_arq, {"historico": [], "pendentes": [], "contador": 0,
                                                       "foco": cfg.get("foco", "")})
        self.claude = ClaudeCode(repo, cfg.get("claude_cmd", "claude"), cfg.get("claude_model", ""),
                                 self.dir / "logs")
        self.assets = GeradorAssets(cfg, repo, self.dir / "assets")
        self.videos = BotVideos(cfg, repo, self.dir / "videos", self.claude, self.assets)

    # ------------------------------------------------------------------ infra
    def salvar(self) -> None:
        salvar_json(self.estado_arq, self.estado)

    def checar_ambiente(self) -> bool:
        ok = True
        if not eh_repo_git(self.repo):
            say(f"✖ {self.repo} não é um repositório Git. Rode o bot dentro da pasta do jogo.", Cor.VERMELHO)
            ok = False
        if not self.claude.disponivel():
            say("✖ Claude Code não encontrado no PATH (comando 'claude').", Cor.VERMELHO)
            ok = False
        import os
        if not os.environ.get(self.cfg.get("openai_api_key_env", "OPENAI_API_KEY")):
            say("! OPENAI_API_KEY não definida: assets do ChatGPT e voz dos vídeos ficam desligados.", Cor.AMARELO)
        if not achar_executavel(self.cfg.get("ffmpeg", "ffmpeg"), self.repo):
            say("! ffmpeg não encontrado: os vídeos sairão só com roteiro/post.", Cor.AMARELO)
        if not achar_executavel(self.cfg.get("godot_exe", ""), self.repo):
            say("! godot_exe não encontrado: sem validação no Godot e sem gravação de gameplay.", Cor.AMARELO)
        return ok

    # ------------------------------------------------------------------ ideias
    def buscar_ideias(self) -> list[dict]:
        titulo("🔎 Claude Code analisando o jogo e buscando ideias")
        foco = self.estado.get("foco") or self.cfg.get("foco", "")
        for tentativa in range(2):
            resp = self.claude.rodar(prompt_ideias(foco, self.estado["historico"], int(self.cfg.get("ideias_por_rodada", 3))),
                                     modo="leitura", nome_log="ideias", mostrar=self.cfg.get("mostrar_raciocinio", False))
            try:
                ideias = extrair_json(resp.texto).get("ideias", [])
                if ideias:
                    return ideias
            except (ValueError, AttributeError):
                pass
            say("Resposta sem JSON válido, tentando de novo…", Cor.AMARELO)
        return []

    def mostrar_ideias(self, ideias: list[dict]) -> None:
        titulo("💡 Ideias para o Paradise RPG")
        for i, idd in enumerate(ideias, 1):
            say(f"\n[{i}] {idd.get('titulo', 'sem título')}", Cor.NEGRITO + Cor.VERDE)
            say(f"    {idd.get('resumo', '')}")
            say(f"    Por que melhora: {idd.get('por_que_melhora', '')}", Cor.CINZA)
            say(f"    O jogador percebe: {idd.get('como_jogador_percebe', '')}", Cor.CINZA)
            n_assets = len(idd.get("assets") or [])
            say(f"    Arte nova (ChatGPT): {n_assets} asset(s) · Risco: {idd.get('risco', '?')} · "
                f"Tamanho: {idd.get('tamanho', '?')}", Cor.CINZA)
            for a in (idd.get("assets") or [])[:5]:
                say(f"      - {a.get('caminho')} ({a.get('largura')}x{a.get('altura')}) {a.get('descricao', '')[:80]}",
                    Cor.CINZA)
            if idd.get("gancho_video"):
                say(f"    🎬 Gancho do vídeo: “{idd['gancho_video']}”", Cor.CINZA)
        say(f"\nDigite o número para ACEITAR, N para pedir outras, ou CONTINUAR depois.", Cor.AMARELO)

    def continuar(self) -> None:
        if not self.estado["pendentes"]:
            ideias = self.buscar_ideias()
            if not ideias:
                say("Não consegui gerar ideias agora. Veja .paradise_bot/logs/ideias.jsonl", Cor.VERMELHO)
                return
            for idd in ideias:
                self.estado["historico"].append({"titulo": idd.get("titulo"), "status": "proposta", "data": agora()})
            self.estado["pendentes"] = ideias
            self.salvar()
        self.mostrar_ideias(self.estado["pendentes"])

    def recusar_pendentes(self) -> None:
        nomes = {i.get("titulo") for i in self.estado["pendentes"]}
        for h in self.estado["historico"]:
            if h.get("titulo") in nomes and h.get("status") == "proposta":
                h["status"] = "recusada"
        self.estado["pendentes"] = []
        self.salvar()

    def _marcar(self, titulo_ideia: str, status: str, **extra) -> None:
        for h in reversed(self.estado["historico"]):
            if h.get("titulo") == titulo_ideia:
                h.update(status=status, **extra)
                break
        else:
            self.estado["historico"].append({"titulo": titulo_ideia, "status": status, "data": agora(), **extra})
        self.salvar()

    # ------------------------------------------------------------------ atualização
    def aplicar(self, ideia: dict) -> None:
        self.estado["contador"] += 1
        n = self.estado["contador"]
        nome = f"atualizacao-{n:03d}"
        self.estado["pendentes"] = [i for i in self.estado["pendentes"] if i is not ideia]
        self.recusar_pendentes()  # as outras da rodada ficam como recusadas
        self._marcar(ideia.get("titulo"), "aceita", numero=n)
        titulo(f"🚀 Atualização {n:03d}: {ideia.get('titulo')}")

        say("📸 Guardando snapshot do jogo (não mexe nos seus arquivos)…", Cor.CINZA)
        try:
            snap = criar_snapshot(self.repo, f"{nome}-antes", self.tmp)
        except ErroGit as e:
            say(f"✖ Não consegui criar o snapshot de segurança, atualização cancelada:\n{e}", Cor.VERMELHO)
            return
        self.estado["ultima"] = {"numero": n, "snapshot": snap, "titulo": ideia.get("titulo")}
        self.salvar()

        episodio = self.videos.iniciar_episodio(ideia, head_curto(self.repo))

        # Arte com o ChatGPT
        gerados, falhas = [], []
        for asset in ideia.get("assets") or []:
            try:
                gerados.append(self.assets.gerar(asset, n))
            except (ErroOpenAI, Exception) as e:  # noqa: BLE001
                falhas.append(f"{asset.get('caminho')}: {e}")
                say(f"   ✖ {asset.get('caminho')}: {str(e)[:200]}", Cor.VERMELHO)

        # Código com o Claude Code
        titulo("🛠  Claude Code implementando")
        resp = self.claude.rodar(prompt_implementar(ideia, gerados, falhas), modo="implementar",
                                 nome_log=nome, mostrar=True)
        sessao, resumo = resp.sessao, resp.texto

        resumo = self._validar_e_corrigir(snap, sessao, resumo, nome)

        # Revisão do dono do jogo
        while True:
            mudancas = mudancas_desde(self.repo, snap, self.tmp)
            titulo("✅ Atualização pronta para você revisar")
            say(resumo.strip()[:3500])
            say(f"\nArquivos alterados ({len(mudancas)}):", Cor.NEGRITO)
            for s, c in mudancas[:40]:
                say(f"  {s} {c}", Cor.CINZA)
            if len(mudancas) > 40:
                say(f"  … e mais {len(mudancas) - 40}", Cor.CINZA)
            resp_user = perguntar("\n[A]ceitar · [T]estar no Godot · [D]esfazer · ou escreva um AJUSTE:")
            cmd = resp_user.upper()
            if cmd in ("A", "ACEITAR", "S", "SIM"):
                break
            if cmd in ("T", "TESTAR"):
                self._abrir_jogo()
                continue
            if cmd in ("D", "DESFAZER", "N", "NAO", "NÃO"):
                revertidos = desfazer(self.repo, snap, self.tmp)
                self.videos.cancelar(episodio)
                self._marcar(ideia.get("titulo"), "desfeita")
                say(f"↩ Atualização desfeita ({len(revertidos)} arquivo(s) restaurados).", Cor.AMARELO)
                return
            if cmd in ("SAIR", ""):
                say("A atualização continua aplicada. Use DESFAZER se quiser reverter.", Cor.AMARELO)
                return
            resp = self.claude.rodar(prompt_ajuste(resp_user), modo="implementar", sessao=sessao, nome_log=nome)
            sessao = resp.sessao or sessao
            resumo = self._validar_e_corrigir(snap, sessao, resp.texto, nome)

        arquivos = [c for _, c in mudancas_desde(self.repo, snap, self.tmp)]
        self._marcar(ideia.get("titulo"), "implementada", arquivos=len(arquivos))
        say("✔ Atualização aceita!", Cor.VERDE)

        commit = head_curto(self.repo)
        if self.cfg.get("commit_ao_aceitar", "perguntar") == "perguntar" and arquivos:
            if perguntar("Fazer commit SÓ dos arquivos desta atualização? (s/N)").lower().startswith("s"):
                try:
                    commit = commit_dos_arquivos(self.repo, arquivos,
                                                 f"feat(bot): {ideia.get('titulo')}\n\n{ideia.get('resumo', '')}")
                    say(f"✔ Commit {commit} criado (sem push).", Cor.VERDE)
                except ErroGit as e:
                    say(f"✖ Commit falhou: {e}", Cor.VERMELHO)

        self.videos.gravar_depois(episodio, ideia)
        self.videos.montar_em_segundo_plano(episodio, ideia, resumo, commit)
        say("\nDigite CONTINUAR para a próxima melhoria.", Cor.AMARELO)

    def _validar_e_corrigir(self, snap: str, sessao: str | None, resumo: str, nome: str) -> str:
        for tentativa in range(int(self.cfg.get("max_tentativas_correcao", 2)) + 1):
            arquivos = [c for _, c in mudancas_desde(self.repo, snap, self.tmp)]
            say("\n🔬 Validando (JSON, JS, Godot headless)…", Cor.CINZA)
            ok, msgs = validar(self.repo, arquivos, self.cfg)
            for m in msgs:
                say(f"   {m[:500]}", Cor.AMARELO if m.startswith("AVISO") else Cor.VERMELHO)
            if ok:
                say("   ✔ Validação automática aprovada.", Cor.VERDE)
                return resumo
            if tentativa >= int(self.cfg.get("max_tentativas_correcao", 2)):
                say("   ✖ Ainda há problemas; revise antes de aceitar.", Cor.VERMELHO)
                return resumo + "\n\n⚠ Problemas não resolvidos:\n" + "\n".join(msgs)
            say(f"   → pedindo correção ao Claude Code ({tentativa + 1})…", Cor.AMARELO)
            erros = [m for m in msgs if not m.startswith("AVISO")]
            resp = self.claude.rodar(prompt_corrigir(erros), modo="implementar", sessao=sessao, nome_log=nome)
            sessao = resp.sessao or sessao
            resumo = resumo + "\n\nCorreção: " + resp.texto
        return resumo

    def _abrir_jogo(self) -> None:
        args, env = comando_jogo(self.cfg, self.repo)
        if not args:
            say("Configure godot_exe em config.json para testar por aqui.", Cor.AMARELO)
            return
        say("Abrindo o jogo (offline, direto no gameplay)… feche a janela quando terminar de testar.", Cor.CINZA)
        subprocess.run(args, cwd=self.repo, env=env)

    # ------------------------------------------------------------------ outros comandos
    def desfazer_ultima(self) -> None:
        ultima = self.estado.get("ultima")
        if not ultima:
            say("Nenhuma atualização para desfazer.", Cor.AMARELO)
            return
        if not perguntar(f"Desfazer a atualização {ultima['numero']:03d} “{ultima['titulo']}”? "
                         "Alterações feitas depois dela nesses arquivos também voltam. (s/N)").lower().startswith("s"):
            return
        revertidos = desfazer(self.repo, ultima["snapshot"], self.tmp)
        self._marcar(ultima["titulo"], "desfeita")
        self.estado["ultima"] = None
        self.salvar()
        say(f"↩ {len(revertidos)} arquivo(s) restaurados.", Cor.AMARELO)

    def mostrar_status(self) -> None:
        titulo("📋 Histórico")
        for h in self.estado["historico"][-25:]:
            cor = {"implementada": Cor.VERDE, "desfeita": Cor.VERMELHO, "recusada": Cor.CINZA}.get(h.get("status"), "")
            say(f"  {h.get('data', '')}  {h.get('status', ''):<13} {h.get('titulo')}", cor)
        say(f"\nFoco atual: {self.estado.get('foco') or self.cfg.get('foco')}")
        say(f"Custo Claude nesta sessão: US$ {self.claude.custo_total:.2f}")

    def mostrar_videos(self) -> None:
        titulo("🎬 Episódios")
        eps = self.videos.status()
        if not eps:
            say("Nenhum episódio ainda.")
        for ep in eps:
            say(f"  {ep['numero']:02d}  {ep.get('status', ''):<24} {ep.get('titulo')}  {ep.get('video', '')}")

    def remontar_video(self, numero: int) -> None:
        pasta = self.videos.pasta / f"episodio-{numero:02d}"
        plano = carregar_json(pasta / "plano.json", None)
        if not plano:
            say("Episódio não encontrado.", Cor.VERMELHO)
            return
        arq = pasta / "resumo.txt"
        resumo = arq.read_text(encoding="utf-8") if arq.exists() else plano["ideia"].get("resumo", "")
        self.videos.montar_em_segundo_plano(numero, plano["ideia"], resumo, "")

    # ------------------------------------------------------------------ loop
    def loop(self) -> None:
        titulo("🌴 Paradise Bot — melhorias contínuas do Paradise RPG")
        say(AJUDA)
        if self.estado["pendentes"]:
            say("\nHá ideias aguardando sua decisão — digite CONTINUAR para vê-las.", Cor.AMARELO)
        while True:
            entrada = perguntar("\n›")
            cmd = entrada.upper()
            try:
                if cmd in ("CONTINUAR", "C", "CONTINUE"):
                    self.continuar()
                elif cmd.isdigit():
                    i = int(cmd) - 1
                    if 0 <= i < len(self.estado["pendentes"]):
                        self.aplicar(self.estado["pendentes"][i])
                    else:
                        say("Número inválido. Digite CONTINUAR para ver as ideias.", Cor.AMARELO)
                elif cmd in ("N", "NENHUMA", "OUTRAS"):
                    self.recusar_pendentes()
                    self.continuar()
                elif cmd.startswith("IDEIA "):
                    texto = entrada[6:].strip()
                    self.aplicar({"id": "ideia-do-dono", "titulo": texto[:80], "resumo": texto,
                                  "assets": [], "cena_video": "mostrar a novidade em ação", "gancho_video": ""})
                elif cmd.startswith("FOCO "):
                    self.estado["foco"] = entrada[5:].strip()
                    self.recusar_pendentes()
                    say(f"Foco atualizado: {self.estado['foco']}", Cor.VERDE)
                elif cmd == "DESFAZER":
                    self.desfazer_ultima()
                elif cmd == "VIDEOS":
                    self.mostrar_videos()
                elif re.fullmatch(r"VIDEO \d+", cmd):
                    self.remontar_video(int(cmd.split()[1]))
                elif cmd == "STATUS":
                    self.mostrar_status()
                elif cmd in ("AJUDA", "HELP", "?"):
                    say(AJUDA)
                elif cmd in ("SAIR", "EXIT", "Q"):
                    break
                elif cmd:
                    say("Comando não reconhecido. Digite AJUDA.", Cor.AMARELO)
            except KeyboardInterrupt:
                say("\nInterrompido. A atualização em andamento pode ter ficado pela metade; "
                    "use DESFAZER se precisar.", Cor.AMARELO)
            except Exception as e:  # noqa: BLE001
                say(f"Erro: {e}", Cor.VERMELHO)
        self.videos.aguardar()
        say("Até a próxima! 🌴", Cor.CIANO)


def carregar_config() -> dict:
    padrao = carregar_json(BOT_DIR / "config.example.json", {})
    padrao.update(carregar_json(BOT_DIR / "config.json", {}))
    return padrao


def main() -> None:
    configurar_console()
    carregar_env_local()
    ap = argparse.ArgumentParser(description="Paradise Bot")
    ap.add_argument("--repo", default=None, help="pasta do jogo (padrão: dois níveis acima do bot)")
    args = ap.parse_args()
    cfg = carregar_config()
    repo = Path(args.repo or cfg.get("repo") or BOT_DIR.parent.parent).resolve()
    bot = ParadiseBot(repo, cfg)
    if not bot.checar_ambiente():
        sys.exit(1)
    bot.loop()


if __name__ == "__main__":
    main()
