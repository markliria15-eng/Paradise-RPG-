"""Bot de vídeos: cada atualização vira um episódio vertical (Reels/TikTok).

Fluxo ligado ao bot de melhorias:
  1. iniciar_episodio()  -> chamado assim que uma atualização é aceita: cria a pasta do
     episódio, salva o plano e grava o clipe ANTES (estado atual do jogo).
  2. gravar_depois()     -> depois da implementação: grava o clipe DEPOIS.
  3. montar_em_segundo_plano() -> roteiro (Claude), voz (OpenAI TTS), legendas, montagem
     (ffmpeg) e capa — roda em segundo plano enquanto você segue com CONTINUAR.
"""
from __future__ import annotations

import json
import os
import subprocess
import threading
import time
import traceback
from pathlib import Path

from util import Cor, achar_executavel, agora, carregar_json, extrair_json, perguntar, rodar, salvar_json, say

LARG, ALT = 1080, 1920


class BotVideos:
    def __init__(self, cfg: dict, repo: Path, pasta: Path, claude, gerador_assets):
        self.cfg = cfg
        self.repo = repo
        self.pasta = pasta  # .paradise_bot/videos
        self.claude = claude
        self.gerador = gerador_assets
        self.ffmpeg = achar_executavel(cfg.get("ffmpeg", "ffmpeg"), repo)
        self.ffprobe = achar_executavel(cfg.get("ffprobe", "ffprobe"), repo)
        self.godot = achar_executavel(cfg.get("godot_exe", ""), repo)
        self.registro = pasta / "episodios.json"
        self.threads: list[threading.Thread] = []

    # ------------------------------------------------------------ util
    def ativo(self) -> bool:
        return self.cfg.get("videos_ativos", True)

    def _dados(self) -> dict:
        return carregar_json(self.registro, {"episodios": []})

    def _salvar(self, dados: dict) -> None:
        salvar_json(self.registro, dados)

    def _pasta_ep(self, numero: int) -> Path:
        return self.pasta / f"episodio-{numero:02d}"

    def status(self) -> list[dict]:
        return self._dados()["episodios"]

    # ------------------------------------------------------------ fase 1
    def iniciar_episodio(self, ideia: dict, commit_antes: str) -> int | None:
        if not self.ativo():
            return None
        dados = self._dados()
        numero = len(dados["episodios"]) + 1
        pasta = self._pasta_ep(numero)
        pasta.mkdir(parents=True, exist_ok=True)
        salvar_json(pasta / "plano.json", {"ideia": ideia, "commit_antes": commit_antes, "inicio": agora()})
        dados["episodios"].append({"numero": numero, "titulo": ideia.get("titulo"), "status": "gravando_antes",
                                   "inicio": agora(), "commit_antes": commit_antes, "pasta": str(pasta)})
        self._salvar(dados)
        say(f"🎬 Episódio {numero:02d} iniciado — o bot de vídeos já está acompanhando esta atualização.", Cor.VERDE)
        self._gravar(pasta / "antes.mp4", ideia, "ANTES")
        self._atualizar(numero, status="aguardando_implementacao")
        return numero

    def gravar_depois(self, numero: int, ideia: dict) -> None:
        if not self.ativo() or numero is None:
            return
        self._gravar(self._pasta_ep(numero) / "depois.mp4", ideia, "DEPOIS")

    def cancelar(self, numero: int | None) -> None:
        if numero is not None:
            self._atualizar(numero, status="cancelado")

    def _atualizar(self, numero: int, **campos) -> None:
        dados = self._dados()
        for ep in dados["episodios"]:
            if ep["numero"] == numero:
                ep.update(campos)
        self._salvar(dados)

    # ------------------------------------------------------------ gravação
    def _titulo_janela(self) -> str | None:
        if os.name != "nt":
            return None
        r = rodar(["powershell", "-NoProfile", "-Command",
                   "Get-Process | Where-Object { $_.MainWindowTitle -like '*Paradise*' } | "
                   "Select-Object -First 1 -ExpandProperty MainWindowTitle"], timeout=20)
        titulo = (r.stdout or "").strip()
        return titulo or None

    def _gravar(self, saida: Path, ideia: dict, rotulo: str) -> None:
        modo = self.cfg.get("gravacao", "manual")
        if modo == "desligada":
            return
        if not (self.ffmpeg and self.godot):
            say(f"   (vídeo) Sem ffmpeg ou godot_exe configurado — pulei a gravação {rotulo}.", Cor.AMARELO)
            return
        segundos = int(self.cfg.get("segundos_gravacao", 20))
        say(f"\n🎥 Gravação {rotulo}: vou abrir o jogo.", Cor.CIANO)
        jogo = subprocess.Popen([self.godot, "--path", str(self.repo)], cwd=self.repo,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            time.sleep(6)
            if modo == "manual":
                say(f"   Mostre no jogo: {ideia.get('cena_video', 'a novidade desta atualização')}", Cor.AMARELO)
                resp = perguntar(f"   Posicione-se e aperte ENTER para gravar {segundos}s (ou P para pular):")
                if resp.upper().startswith("P"):
                    return
            titulo = None
            for _ in range(10):
                titulo = self._titulo_janela()
                if titulo:
                    break
                time.sleep(1)
            entrada = ["-f", "gdigrab", "-framerate", "30"]
            entrada += ["-i", f"title={titulo}"] if titulo else ["-i", "desktop"]
            say(f"   ● Gravando {segundos}s{'' if titulo else ' (tela inteira)'}… jogue agora!", Cor.VERMELHO)
            r = rodar([self.ffmpeg, "-y", *entrada, "-t", str(segundos), "-c:v", "libx264", "-preset", "veryfast",
                       "-crf", "20", "-pix_fmt", "yuv420p", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", str(saida)],
                      timeout=segundos + 60)
            if r.returncode == 0 and saida.exists():
                say(f"   ✔ Clipe {rotulo} salvo.", Cor.VERDE)
            else:
                say(f"   ✖ Falha ao gravar {rotulo}: {(r.stderr or '')[-400:]}", Cor.VERMELHO)
        finally:
            jogo.terminate()
            try:
                jogo.wait(timeout=10)
            except subprocess.TimeoutExpired:
                jogo.kill()

    # ------------------------------------------------------------ fase 3
    def montar_em_segundo_plano(self, numero: int, ideia: dict, resumo_impl: str, commit_depois: str) -> None:
        if not self.ativo() or numero is None:
            return
        self._atualizar(numero, status="montando", commit_depois=commit_depois)
        if resumo_impl:
            (self._pasta_ep(numero) / "resumo.txt").write_text(resumo_impl, encoding="utf-8")
        t = threading.Thread(target=self._montar_seguro, args=(numero, ideia, resumo_impl), daemon=False)
        t.start()
        self.threads.append(t)
        say(f"🎬 Episódio {numero:02d}: roteiro, voz e montagem rodando em segundo plano.", Cor.VERDE)

    def _montar_seguro(self, numero: int, ideia: dict, resumo_impl: str) -> None:
        pasta = self._pasta_ep(numero)
        try:
            (pasta / "erro.txt").unlink(missing_ok=True)
            final = self.montar(numero, ideia, resumo_impl)
            self._atualizar(numero, status="pronto", video=str(final), concluido=agora())
            print(f"\n{Cor.VERDE}🎬 Episódio {numero:02d} pronto: {final}{Cor.RESET}", flush=True)
        except Exception as e:  # noqa: BLE001
            (pasta / "erro.txt").write_text(traceback.format_exc(), encoding="utf-8")
            self._atualizar(numero, status="erro", erro=str(e)[:300])
            print(f"\n{Cor.VERMELHO}🎬 Episódio {numero:02d} falhou: {e} (detalhes em {pasta / 'erro.txt'}){Cor.RESET}",
                  flush=True)

    def montar(self, numero: int, ideia: dict, resumo_impl: str) -> Path:
        from prompts import prompt_roteiro

        pasta = self._pasta_ep(numero)
        antes, depois = pasta / "antes.mp4", pasta / "depois.mp4"
        tem_antes, tem_depois = antes.exists(), depois.exists()

        # 1) roteiro
        resp = self.claude.rodar(prompt_roteiro(ideia, resumo_impl, numero, tem_antes), modo="leitura",
                                 nome_log=f"roteiro-{numero:02d}", mostrar=False, timeout_s=900)
        roteiro = extrair_json(resp.texto)
        salvar_json(pasta / "roteiro.json", roteiro)
        (pasta / "post.txt").write_text(
            f"{roteiro.get('titulo', '')}\n\n{roteiro.get('legenda_post', '')}\n\n{' '.join(roteiro.get('hashtags', []))}\n",
            encoding="utf-8")

        if not self.ffmpeg:
            raise RuntimeError("ffmpeg não encontrado — roteiro salvo, mas o vídeo não pôde ser montado.")
        if not (tem_antes or tem_depois):
            raise RuntimeError("Nenhum clipe gravado — roteiro e post salvos; grave e rode VIDEO "
                               f"{numero} para montar.")

        # 2) voz (OpenAI TTS); sem voz o vídeo sai só com legendas
        audio = pasta / "narracao.mp3"
        try:
            self.gerador.narrar(roteiro["narracao"], audio)
            duracao = self._duracao(audio) + 0.8
        except Exception as e:  # noqa: BLE001
            (pasta / "aviso_voz.txt").write_text(str(e), encoding="utf-8")
            audio = None
            duracao = max(25.0, len(roteiro.get("narracao", "").split()) / 2.6)
        duracao = min(max(duracao, 20.0), 58.0)

        # 3) partes verticais (fundo desfocado + jogo centralizado)
        partes = []
        if tem_antes and tem_depois:
            t_antes = round(duracao * 0.35, 2)
            partes = [(antes, t_antes), (depois, round(duracao - t_antes, 2))]
        else:
            partes = [((depois if tem_depois else antes), duracao)]
        arquivos_partes = []
        for i, (clipe, dur) in enumerate(partes):
            destino = pasta / f"parte{i}.mp4"
            filtro = (f"[0:v]split[a][b];[a]scale={LARG}:{ALT}:force_original_aspect_ratio=increase,"
                      f"crop={LARG}:{ALT},boxblur=25:2,eq=brightness=-0.08[bg];"
                      f"[b]scale={int(LARG*1.15)}:-2,crop={LARG}:ih[fg];"
                      f"[bg][fg]overlay=(W-w)/2:(H-h)/2-120,fps=30,format=yuv420p[v]")
            r = rodar([self.ffmpeg, "-y", "-stream_loop", "-1", "-i", str(clipe), "-t", str(dur),
                       "-filter_complex", filtro, "-map", "[v]", "-an", "-c:v", "libx264", "-preset", "veryfast",
                       "-crf", "20", str(destino)], timeout=900)
            if r.returncode != 0:
                raise RuntimeError(f"ffmpeg (parte {i}) falhou: {r.stderr[-800:]}")
            arquivos_partes.append(destino)
        lista = pasta / "partes.txt"
        lista.write_text("".join(f"file '{p.name}'\n" for p in arquivos_partes), encoding="utf-8")

        # 4) legendas + rótulos ANTES/DEPOIS + gancho
        rotulos = []
        if len(partes) == 2:
            rotulos = [(0, partes[0][1], "ANTES"), (partes[0][1], duracao, "DEPOIS")]
        self._legendas(pasta / "legendas.ass", roteiro, duracao, rotulos)

        # 5) montagem final
        final = pasta / f"episodio-{numero:02d}.mp4"
        args = [self.ffmpeg, "-y", "-f", "concat", "-safe", "0", "-i", lista.name]
        if audio:
            args += ["-i", audio.name]
        args += ["-vf", "subtitles=legendas.ass", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                 "-pix_fmt", "yuv420p", "-r", "30"]
        args += (["-c:a", "aac", "-b:a", "128k", "-map", "0:v", "-map", "1:a"] if audio else ["-an"])
        args += ["-t", f"{duracao:.2f}", "-movflags", "+faststart", final.name]
        r = rodar(args, cwd=pasta, timeout=1200)
        if r.returncode != 0:
            raise RuntimeError(f"ffmpeg (montagem) falhou: {r.stderr[-800:]}")

        # 6) capa
        self._capa(arquivos_partes[-1], pasta / "capa.jpg", roteiro.get("texto_capa") or roteiro.get("titulo", ""),
                   partes[-1][1])
        for p in arquivos_partes:
            p.unlink(missing_ok=True)
        lista.unlink(missing_ok=True)
        return final

    # ------------------------------------------------------------ helpers de mídia
    def _duracao(self, arquivo: Path) -> float:
        if self.ffprobe:
            r = rodar([self.ffprobe, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                       str(arquivo)], timeout=60)
            try:
                return float(r.stdout.strip())
            except ValueError:
                pass
        return 30.0

    @staticmethod
    def _tempo_ass(seg: float) -> str:
        h, resto = divmod(max(0.0, seg), 3600)
        m, s = divmod(resto, 60)
        return f"{int(h)}:{int(m):02d}:{s:05.2f}"

    def _legendas(self, destino: Path, roteiro: dict, duracao: float, rotulos: list) -> None:
        palavras = roteiro.get("narracao", "").split()
        destaques = {d.lower().strip(".,!?") for d in roteiro.get("palavras_destaque", [])}
        cab = (
            "[Script Info]\nScriptType: v4.00+\nPlayResX: 1080\nPlayResY: 1920\nWrapStyle: 0\n\n"
            "[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
            "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
            "Alignment, MarginL, MarginR, MarginV, Encoding\n"
            "Style: Leg,Arial Black,78,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,7,2,2,60,60,420,1\n"
            "Style: Topo,Arial Black,92,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,8,3,8,60,60,170,1\n"
            "Style: Rot,Arial Black,70,&H0000D7FF,&H00FFFFFF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,6,2,8,60,60,360,1\n\n"
            "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n")
        linhas = []
        fala_ini, fala_fim = 0.3, max(1.0, duracao - 0.6)
        blocos = [palavras[i:i + 3] for i in range(0, len(palavras), 3)]
        total = max(1, len(palavras))
        t = fala_ini
        for bloco in blocos:
            dur = (fala_fim - fala_ini) * len(bloco) / total
            texto = " ".join(
                ("{\\c&H0000E5FF&}" + w.upper() + "{\\c&H00FFFFFF&}") if w.lower().strip(".,!?") in destaques else w.upper()
                for w in bloco)
            linhas.append(f"Dialogue: 0,{self._tempo_ass(t)},{self._tempo_ass(t + dur)},Leg,,0,0,0,,{texto}")
            t += dur
        gancho = roteiro.get("gancho_tela", "")
        if gancho:
            linhas.append(f"Dialogue: 1,{self._tempo_ass(0)},{self._tempo_ass(3.0)},Topo,,0,0,0,,"
                          "{\\fad(0,250)}" + gancho.upper())
        for ini, fim, texto in rotulos:
            linhas.append(f"Dialogue: 1,{self._tempo_ass(ini)},{self._tempo_ass(fim)},Rot,,0,0,0,,{texto}")
        destino.write_text(cab + "\n".join(linhas) + "\n", encoding="utf-8")

    def _capa(self, video: Path, destino: Path, texto: str, duracao: float) -> None:
        quadro = destino.with_name("quadro_capa.png")
        rodar([self.ffmpeg, "-y", "-ss", f"{duracao * 0.6:.2f}", "-i", str(video), "-frames:v", "1", str(quadro)],
              timeout=120)
        try:
            from PIL import Image, ImageDraw, ImageFont
            img = Image.open(quadro).convert("RGB")
            d = ImageDraw.Draw(img)
            fonte = None
            for f in ("C:/Windows/Fonts/ariblk.ttf", "C:/Windows/Fonts/arialbd.ttf",
                      "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
                if Path(f).exists():
                    fonte = ImageFont.truetype(f, 120)
                    break
            fonte = fonte or ImageFont.load_default()
            palavras, linhas, atual = texto.upper().split(), [], ""
            for p in palavras:
                teste = (atual + " " + p).strip()
                if d.textlength(teste, font=fonte) > img.width - 120 and atual:
                    linhas.append(atual)
                    atual = p
                else:
                    atual = teste
            if atual:
                linhas.append(atual)
            y = 260
            for linha in linhas:
                w = d.textlength(linha, font=fonte)
                d.text(((img.width - w) / 2, y), linha, font=fonte, fill=(255, 229, 0),
                       stroke_width=10, stroke_fill=(0, 0, 0))
                y += 140
            img.save(destino, quality=92)
        finally:
            quadro.unlink(missing_ok=True)

    def aguardar(self) -> None:
        vivos = [t for t in self.threads if t.is_alive()]
        if vivos:
            say(f"Aguardando {len(vivos)} vídeo(s) terminar de montar…", Cor.AMARELO)
            for t in vivos:
                t.join()
