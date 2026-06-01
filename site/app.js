async function loadVersionInfo() {
	const size = document.querySelector("#apkSize");
	const version = document.querySelector("#versionName");
	try {
		const response = await fetch("app-version.json", { cache: "no-store" });
		if (!response.ok) throw new Error("missing metadata");
		const data = await response.json();
		version.textContent = data.version || "Release Android";
		size.textContent = data.size_mb ? `${data.size_mb} MB` : "APK pronto";
	} catch (_error) {
		size.textContent = "APK pronto";
	}
}

function setupCopyLink() {
	const button = document.querySelector("#copyLink");
	button.addEventListener("click", async () => {
		const apkUrl = new URL("downloads/ArcadiaRealms2D-release.apk", window.location.href).href;
		try {
			await navigator.clipboard.writeText(apkUrl);
			button.textContent = "Link copiado";
		} catch (_error) {
			button.textContent = apkUrl;
		}
		setTimeout(() => {
			button.textContent = "Copiar link";
		}, 2200);
	});
}

loadVersionInfo();
setupCopyLink();
