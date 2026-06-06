# Site publico do Paradise RPG

Esta pasta e publicada no GitHub Pages pelo workflow `.github/workflows/deploy-pages.yml`.

## Como publicar no GitHub Pages

1. Envie o projeto para um repositorio no GitHub.
2. Abra o repositorio no navegador.
3. Va em `Settings > Pages`.
4. Em `Build and deployment`, selecione `GitHub Actions`.
5. Faca push na branch `main`.
6. A action `Deploy Website to GitHub Pages` publicara a pasta `website/`.

O endereco final sera parecido com:

```text
https://SEU_USUARIO.github.io/NOME_DO_REPOSITORIO/
```

## Como trocar links dos botoes

O botao Android do site aponta para:

```text
https://paradise-rpg-server.onrender.com/download/android
```

Esse endpoint do Render redireciona para a URL configurada em `ANDROID_APK_URL`.
Para trocar o APK sem editar o site, altere essa variavel no Render.

O link Windows ainda pode ser trocado no HTML pelo link da Release:

Exemplo:

```html
<a class="button secondary" href="https://github.com/usuario/paradise-rpg/releases/download/v0.1.0/paradise-rpg-windows-v0.1.0.zip">
  Baixar para Windows
</a>
```

## Como publicar nova versao

1. Gere os builds novos.
2. Crie uma nova Release no GitHub, por exemplo `v0.1.1`.
3. Envie APK, ZIP Windows e outros arquivos.
4. Copie os links dos arquivos.
5. Para Android, cole o link do APK em `ANDROID_APK_URL` no Render.
6. Para Windows, atualize `website/index.html`.
7. Faca commit e push se editar o site.

## Como conectar aos arquivos do GitHub Releases

O site tambem possui um APK temporario em `website/downloads/Paradise-RPG.apk`.
O workflow `.github/workflows/release-android.yml` publica esse APK no GitHub Releases quando uma tag `v*` e enviada.
O Render usa o asset do GitHub Releases como `ANDROID_APK_URL` padrao.

Para versoes oficiais, os arquivos de download devem ficar no GitHub Releases, nao dentro do GitHub Pages.

Formato comum de link:

```text
https://github.com/USUARIO/REPOSITORIO/releases/download/v0.1.0/NOME_DO_ARQUIVO.apk
```

GitHub Pages hospeda somente o site estatico e, se existir, a versao web do client em `website/game`.
