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

O botao Android principal do site aponta para o APK completo publicado na ultima GitHub Release:

```text
https://github.com/markliria15-eng/Paradise-RPG-/releases/latest/download/Paradise-RPG.apk
```

O site tambem oferece um fallback online via Render:

```text
https://paradise-rpg-server.onrender.com/download/android
```

Esse endpoint do Render redireciona para a URL configurada em `ANDROID_APK_URL`.
Para trocar o APK sem editar o site, altere essa variavel no Render.

O link Windows leva para a pagina da ultima Release:

Exemplo:

```html
<a class="button secondary" href="https://github.com/usuario/paradise-rpg/releases/latest">
  Baixar para Windows
</a>
```

## Como publicar nova versao

1. Gere os builds novos.
2. Crie uma nova Release no GitHub, por exemplo `v0.1.1`.
3. Envie APK, ZIP Windows e outros arquivos.
4. Copie os links dos arquivos.
5. Para Android, envie o asset como `Paradise-RPG.apk` na Release mais nova.
6. Para Windows, atualize `website/index.html` com o link da ultima Release.
7. Faca commit e push se editar o site.

## Como conectar aos arquivos do GitHub Releases

O site usa o APK principal da ultima GitHub Release.
O workflow `.github/workflows/release-android.yml` exporta o APK completo do Godot e publica no GitHub Releases quando uma tag `v*` e enviada.
O Render ainda pode ser usado como fallback online via `ANDROID_APK_URL`.

Para Windows, o site aponta para a pagina da ultima Release no GitHub.

Formato comum de link:

```text
https://github.com/USUARIO/REPOSITORIO/releases/latest/download/Paradise-RPG.apk
```

GitHub Pages hospeda o site estatico e, se existir, a versao web do client em `website/game`. O APK completo fica no GitHub Releases.
