# Sistema de patches de dados

O Paradise RPG agora tem uma base para atualizar dados do jogo sem gerar um APK novo toda vez.

## O que pode ser atualizado por patch

- Itens
- Monstros
- Mapas em JSON
- Quests
- Skills
- Receitas
- Sets de armadura
- Pets, montarias, profissões, dungeons, conquistas e temporadas

Arquivos grandes de sprite, scripts GDScript, cenas `.tscn` e mudanças de engine ainda precisam de APK completo.

## Como funciona

1. O servidor publica o manifesto em:
   `https://paradise-rpg-server.onrender.com/patch/manifest`
2. Os arquivos ficam em:
   `https://paradise-rpg-server.onrender.com/patch/files/NOME.json`
3. O app baixa os arquivos para:
   `user://patches/data/`
4. Quando o jogo lê `res://data/NOME.json`, ele usa primeiro o arquivo em `user://patches/data/NOME.json`, se existir.

## Como gerar um novo patch

Depois de editar arquivos em `data/`, rode:

```bash
cd server
npm run build-patch
```

Depois faça commit e push dos arquivos gerados em:

- `server/public/patches/manifest.json`
- `server/public/patches/data/*.json`

Quando o Render redeployar, os jogadores receberão os dados novos ao abrir o app.

## Quando ainda precisa APK completo

Use APK completo quando mudar:

- Sprites, imagens, sons ou fontes
- Scripts `.gd`
- Cenas `.tscn`
- Configuração do Godot
- Ícone/nome do app
- Sistemas novos que exigem código no client
