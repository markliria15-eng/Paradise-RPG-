document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener("click", (event) => {
    const target = document.querySelector(link.getAttribute("href"));
    if (!target) {
      return;
    }

    event.preventDefault();
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  });
});

const serverPanel = document.querySelector(".server-panel");
const statusText = document.querySelector("#server-status");

if (serverPanel && statusText) {
  const serverUrl = serverPanel.dataset.serverUrl;
  fetch(`${serverUrl}/world/status`, { cache: "no-store" })
    .then((response) => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.json();
    })
    .then((status) => {
      serverPanel.classList.add("online");
      statusText.textContent = `Online - ${status.onlinePlayers || 0} jogadores conectados`;
    })
    .catch(() => {
      serverPanel.classList.add("offline");
      statusText.textContent = "Servidor reiniciando ou aguardando deploy do Render";
    });
}
