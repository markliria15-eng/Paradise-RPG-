# Publicar downloads do Paradise RPG

Use este passo a passo para publicar APK, Windows ZIP e links publicos.

## 1. Gerar APK Android

No Godot, use o preset Android Release, ou rode o comando configurado no projeto para exportacao.

Arquivo sugerido:

```text
releases/paradise-rpg-android-v0.1.0.apk
```

## 2. Gerar versao Windows

Exporte o executavel Windows pelo Godot e coloque os arquivos em uma pasta local temporaria.

## 3. Compactar versao Windows em ZIP

Nome sugerido:

```text
releases/paradise-rpg-windows-v0.1.0.zip
```

## 4. Entrar no GitHub

Abra o repositorio do projeto no GitHub.

## 5. Ir em Releases

Clique em `Releases` na pagina principal do repositorio.

## 6. Clicar em Draft a new release

Crie uma nova release.

## 7. Criar tag v0.1.0

Use:

```text
v0.1.0
```

## 8. Nome da release

Use:

```text
Paradise RPG Beta v0.1.0
```

## 9. Enviar arquivos

Envie:

```text
paradise-rpg-android-v0.1.0.apk
paradise-rpg-windows-v0.1.0.zip
```

## 10. Copiar o link de download

Depois de publicar a release, clique com o botao direito em cada arquivo e copie o link.

## 11. Colar os links no site

Abra:

```text
website/index.html
```

Substitua:

```html
href="#android-download"
href="#windows-download"
```

pelos links reais do GitHub Releases.

## 12. Fazer commit e push

```bash
git add .
git commit -m "Atualiza links de download"
git push
```

O GitHub Pages publicara a pagina automaticamente.
