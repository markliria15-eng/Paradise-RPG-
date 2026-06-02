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

Abra `website/index.html` e procure pelos comentarios:

```html
<!-- Trocar este link pelo link real do APK no GitHub Releases. -->
<!-- Trocar este link pelo link real do ZIP Windows no GitHub Releases. -->
```

Troque os valores de `href` pelos links copiados na pagina da Release.

Exemplo:

```html
<a class="button primary" href="https://github.com/usuario/paradise-rpg/releases/download/v0.1.0/paradise-rpg-android-v0.1.0.apk">
  Baixar para Android
</a>
```

## Como publicar nova versao

1. Gere os builds novos.
2. Crie uma nova Release no GitHub, por exemplo `v0.1.1`.
3. Envie APK, ZIP Windows e outros arquivos.
4. Copie os links dos arquivos.
5. Atualize `website/index.html`.
6. Faca commit e push.

## Como conectar aos arquivos do GitHub Releases

O site tambem possui um APK temporario em `website/downloads/Paradise-RPG.apk` para o botao funcionar imediatamente.

Para versoes oficiais, os arquivos de download devem ficar no GitHub Releases, nao dentro do GitHub Pages.

Formato comum de link:

```text
https://github.com/USUARIO/REPOSITORIO/releases/download/v0.1.0/NOME_DO_ARQUIVO.apk
```

GitHub Pages hospeda somente o site estatico e, se existir, a versao web do client em `website/game`.
