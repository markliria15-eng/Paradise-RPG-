// Topo fica solido depois da abertura.
const topo = document.querySelector(".topo");
const abertura = document.querySelector(".abertura");
if (topo && abertura && "IntersectionObserver" in window) {
  new IntersectionObserver(([entrada]) => {
    topo.classList.toggle("solido", !entrada.isIntersecting);
  }, { rootMargin: "-80px 0px 0px 0px" }).observe(abertura);
}

// Movimento reduzido: o video da abertura nao toca (fica a imagem).
const video = document.querySelector(".abertura-video");
if (video && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  video.removeAttribute("autoplay");
  video.pause();
}

// Status do servidor online: so muda o texto se o servidor responder.
const servidor = document.querySelector(".servidor");
const statusTexto = document.querySelector("#servidor-status");
if (servidor && statusTexto) {
  const controle = new AbortController();
  setTimeout(() => controle.abort(), 6000);
  fetch(`${servidor.dataset.serverUrl}/world/status`, { cache: "no-store", signal: controle.signal })
    .then((resposta) => {
      if (!resposta.ok) throw new Error(`HTTP ${resposta.status}`);
      return resposta.json();
    })
    .then((status) => {
      servidor.classList.add("online");
      const n = Number(status.onlinePlayers || 0);
      statusTexto.textContent = `Servidor online: ${n} ${n === 1 ? "jogador conectado" : "jogadores conectados"}.`;
    })
    .catch(() => {
      // fica a mensagem padrao: o jogo funciona offline
    });
}
