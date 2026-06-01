# Site de Download - Arcadia Realms 2D

Esta pasta e um site estatico pronto para hospedar o APK do jogo.

## Arquivos importantes

- `index.html`: pagina publica de download.
- `styles.css`: visual da pagina.
- `app.js`: copia link e mostra metadados.
- `downloads/ArcadiaRealms2D-release.apk`: APK que o jogador baixa.
- `app-version.json`: tamanho/data da versao publicada.

## Atualizar APK do site

Na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\package_download_site.ps1
```

## Publicar na internet

Opcoes simples:

1. Netlify Drop: arraste a pasta `site/` para o painel do Netlify.
2. Cloudflare Pages: publique a pasta `site/`.
3. GitHub Pages: envie a pasta `site/` para um repositorio e ative Pages.

Depois disso, qualquer pessoa com o link podera baixar o APK de longe.

## Importante no Android

Como o app nao vem da Play Store, o celular pode pedir permissao para instalar
apps desconhecidos pelo navegador. Isso e normal para APK hospedado fora da loja.
