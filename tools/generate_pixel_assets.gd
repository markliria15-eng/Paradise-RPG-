extends SceneTree

const OUT_DIR := "res://assets/sprites/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_make_players()
	_make_enemies()
	_make_npcs()
	_make_drops()
	_make_decor()
	_make_tiles()
	_make_action_icons()
	_make_ui_icons()
	_make_app_icons()
	quit()

func _new_image(w: int, h: int) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image

func _save(image: Image, file_name: String) -> void:
	image.save_png(OUT_DIR + file_name)

func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)

func _circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for py in range(cy - radius, cy + radius + 1):
		for px in range(cx - radius, cx + radius + 1):
			var dx: int = px - cx
			var dy: int = py - cy
			if dx * dx + dy * dy <= radius * radius:
				if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
					image.set_pixel(px, py, color)

func _line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var dx: int = abs(to.x - from.x)
	var sx: int = 1 if from.x < to.x else -1
	var dy: int = -abs(to.y - from.y)
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx + dy
	var x: int = from.x
	var y: int = from.y
	while true:
		_rect(image, x, y, 1, 1, color)
		if x == to.x and y == to.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

func _line_thick(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int = 2) -> void:
	var half := int(width / 2)
	for ox in range(-half, half + 1):
		for oy in range(-half, half + 1):
			_line(image, from + Vector2i(ox, oy), to + Vector2i(ox, oy), color)

func _shadow(image: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	for py in range(cy - ry, cy + ry + 1):
		for px in range(cx - rx, cx + rx + 1):
			var nx := float(px - cx) / float(rx)
			var ny := float(py - cy) / float(ry)
			if nx * nx + ny * ny <= 1.0:
				image.set_pixel(px, py, Color(0, 0, 0, 0.28))

func _make_humanoid(file_name: String, cloth: Color, accent: Color, hat: Color, weapon: String = "") -> void:
	var image := _new_image(32, 40)
	var outline := Color("#242018")
	var skin := Color("#f1c58f")
	_shadow(image, 16, 34, 10, 4)
	_rect(image, 12, 12, 8, 8, outline)
	_rect(image, 13, 13, 6, 6, skin)
	_rect(image, 11, 20, 10, 12, outline)
	_rect(image, 12, 21, 8, 10, cloth)
	_rect(image, 13, 22, 6, 2, accent)
	_rect(image, 9, 22, 3, 8, outline)
	_rect(image, 20, 22, 3, 8, outline)
	_rect(image, 12, 31, 4, 5, outline)
	_rect(image, 17, 31, 4, 5, outline)
	_rect(image, 11, 9, 10, 4, outline)
	_rect(image, 12, 8, 8, 4, hat)
	if weapon == "sword":
		_rect(image, 23, 14, 2, 18, Color("#d7dce2"))
		_rect(image, 22, 28, 4, 2, Color("#8a5a34"))
	elif weapon == "staff":
		_rect(image, 23, 12, 2, 20, Color("#7b4d2c"))
		_circle(image, 24, 10, 3, accent)
	elif weapon == "bow":
		_line(image, Vector2i(24, 13), Vector2i(29, 24), Color("#8a5a34"))
		_line(image, Vector2i(29, 24), Vector2i(24, 34), Color("#8a5a34"))
		_line(image, Vector2i(25, 14), Vector2i(25, 33), Color("#e7ddbe"))
	_save(image, file_name)

func _make_players() -> void:
	_make_humanoid("player_guerreiro.png", Color("#9f3d31"), Color("#e6b34f"), Color("#7d8389"), "sword")
	_make_humanoid("player_mago.png", Color("#4f55bf"), Color("#8be6ff"), Color("#303a89"), "staff")
	_make_humanoid("player_arqueiro.png", Color("#3f8f57"), Color("#d8c46d"), Color("#2d5f3f"), "bow")

func _make_enemies() -> void:
	_make_boar()
	_make_wolf()
	_make_spirit()
	_make_apprentice()
	_make_bat()
	_make_spider()

func _make_boar() -> void:
	var i := _new_image(32, 32)
	_shadow(i, 16, 25, 11, 4)
	_rect(i, 8, 15, 16, 9, Color("#5d382a"))
	_rect(i, 10, 13, 12, 5, Color("#8a5a3b"))
	_rect(i, 5, 17, 5, 5, Color("#6d4332"))
	_rect(i, 3, 19, 3, 2, Color("#e8d5b0"))
	_rect(i, 7, 14, 3, 3, Color("#2a1d18"))
	_rect(i, 11, 23, 3, 4, Color("#2a1d18"))
	_rect(i, 20, 23, 3, 4, Color("#2a1d18"))
	_save(i, "enemy_javali.png")

func _make_wolf() -> void:
	var i := _new_image(32, 32)
	_shadow(i, 16, 25, 11, 4)
	_rect(i, 8, 15, 16, 8, Color("#737b82"))
	_rect(i, 5, 13, 8, 7, Color("#8f989f"))
	_rect(i, 6, 10, 3, 4, Color("#545c63"))
	_rect(i, 11, 10, 3, 4, Color("#545c63"))
	_rect(i, 2, 17, 4, 2, Color("#d8d8d8"))
	_rect(i, 24, 14, 4, 3, Color("#545c63"))
	_rect(i, 9, 23, 3, 4, Color("#33383d"))
	_rect(i, 21, 23, 3, 4, Color("#33383d"))
	_save(i, "enemy_lobo.png")

func _make_spirit() -> void:
	var i := _new_image(32, 32)
	_shadow(i, 16, 26, 9, 4)
	_circle(i, 16, 14, 9, Color("#a7ddff"))
	_circle(i, 16, 15, 6, Color("#e0f6ff"))
	_rect(i, 9, 21, 14, 5, Color("#7ab8ff"))
	_rect(i, 11, 13, 2, 2, Color("#314f7d"))
	_rect(i, 19, 13, 2, 2, Color("#314f7d"))
	_save(i, "enemy_espirito.png")

func _make_apprentice() -> void:
	_make_humanoid("enemy_aprendiz.png", Color("#563091"), Color("#d46cff"), Color("#211444"), "staff")

func _make_bat() -> void:
	var i := _new_image(32, 32)
	_shadow(i, 16, 25, 10, 3)
	_circle(i, 16, 16, 5, Color("#353346"))
	_line(i, Vector2i(12, 16), Vector2i(3, 10), Color("#4c4a61"))
	_line(i, Vector2i(12, 17), Vector2i(3, 22), Color("#4c4a61"))
	_line(i, Vector2i(20, 16), Vector2i(29, 10), Color("#4c4a61"))
	_line(i, Vector2i(20, 17), Vector2i(29, 22), Color("#4c4a61"))
	_rect(i, 14, 14, 1, 1, Color("#d74b4b"))
	_rect(i, 18, 14, 1, 1, Color("#d74b4b"))
	_save(i, "enemy_morcego.png")

func _make_spider() -> void:
	var i := _new_image(32, 32)
	_shadow(i, 16, 25, 11, 4)
	_circle(i, 16, 17, 8, Color("#294d35"))
	_circle(i, 16, 12, 5, Color("#396b46"))
	for y in [15, 18, 21]:
		_line(i, Vector2i(10, y), Vector2i(3, y - 5), Color("#1f3326"))
		_line(i, Vector2i(22, y), Vector2i(29, y - 5), Color("#1f3326"))
	_rect(i, 14, 11, 1, 1, Color("#ebdc71"))
	_rect(i, 18, 11, 1, 1, Color("#ebdc71"))
	_save(i, "enemy_aranha.png")

func _make_npcs() -> void:
	_make_humanoid("npc_healer.png", Color("#e9dfc8"), Color("#76d5a8"), Color("#c49b67"), "")
	_make_humanoid("npc_shop.png", Color("#a87438"), Color("#ffd46d"), Color("#55402a"), "")
	_make_humanoid("npc_master.png", Color("#2e567c"), Color("#d9e6ff"), Color("#1d2c44"), "staff")
	_make_humanoid("npc_quest.png", Color("#6d5b3d"), Color("#f4d35e"), Color("#3d3427"), "sword")
	_make_humanoid("npc_forge.png", Color("#5f6470"), Color("#ffbc5c"), Color("#2d2520"), "sword")

func _make_drops() -> void:
	var potion := _new_image(24, 24)
	_shadow(potion, 12, 20, 7, 2)
	_rect(potion, 9, 5, 6, 3, Color("#dedede"))
	_rect(potion, 7, 8, 10, 10, Color("#70334b"))
	_rect(potion, 9, 10, 6, 6, Color("#e84774"))
	_save(potion, "drop_potion.png")
	var gem := _new_image(24, 24)
	_shadow(gem, 12, 20, 8, 2)
	_rect(gem, 8, 7, 8, 3, Color("#a8f5ff"))
	_rect(gem, 6, 10, 12, 5, Color("#34b7ff"))
	_rect(gem, 9, 15, 6, 3, Color("#207cd5"))
	_save(gem, "drop_gem.png")
	var bag := _new_image(24, 24)
	_shadow(bag, 12, 20, 8, 2)
	_rect(bag, 7, 8, 10, 10, Color("#8a5b32"))
	_rect(bag, 8, 6, 8, 3, Color("#b6854a"))
	_rect(bag, 8, 11, 8, 2, Color("#e0b368"))
	_save(bag, "drop_bag.png")
	var material := _new_image(24, 24)
	_shadow(material, 12, 20, 7, 2)
	_rect(material, 7, 10, 11, 7, Color("#c9b07d"))
	_rect(material, 9, 8, 8, 4, Color("#e2d09a"))
	_rect(material, 12, 6, 3, 4, Color("#f2e3b2"))
	_save(material, "drop_material.png")
	var coin := _new_image(24, 24)
	_shadow(coin, 12, 20, 8, 2)
	_circle(coin, 12, 12, 8, Color("#8a5f16"))
	_circle(coin, 12, 11, 7, Color("#ffd25a"))
	_circle(coin, 12, 11, 4, Color("#f1a824"))
	_rect(coin, 11, 6, 2, 10, Color("#fff1a3"))
	_save(coin, "drop_coin.png")
	var ore := _new_image(24, 24)
	_shadow(ore, 12, 20, 8, 2)
	_rect(ore, 6, 12, 12, 6, Color("#4f5961"))
	_rect(ore, 9, 8, 10, 7, Color("#737f89"))
	_rect(ore, 12, 10, 4, 3, Color("#c8d3dc"))
	_save(ore, "drop_ore.png")
	var wood := _new_image(24, 24)
	_shadow(wood, 12, 20, 8, 2)
	_rect(wood, 5, 12, 15, 6, Color("#7a4b26"))
	_rect(wood, 7, 9, 14, 6, Color("#a66732"))
	_rect(wood, 8, 11, 10, 1, Color("#e0a65e"))
	_save(wood, "drop_wood.png")

func _make_decor() -> void:
	var portal := _new_image(48, 48)
	_shadow(portal, 24, 39, 14, 4)
	_circle(portal, 24, 22, 16, Color("#512e8a"))
	_circle(portal, 24, 22, 11, Color("#965cff"))
	_circle(portal, 24, 22, 6, Color("#d3b6ff"))
	_rect(portal, 11, 37, 26, 5, Color("#5b4d66"))
	_save(portal, "decor_portal.png")
	var fountain := _new_image(64, 48)
	_shadow(fountain, 32, 40, 24, 5)
	_rect(fountain, 14, 28, 36, 10, Color("#738496"))
	_rect(fountain, 18, 24, 28, 6, Color("#9caaba"))
	_rect(fountain, 24, 16, 16, 10, Color("#6fc7ff"))
	_rect(fountain, 30, 5, 4, 16, Color("#d7f5ff"))
	_rect(fountain, 25, 12, 14, 3, Color("#9ee4ff"))
	_save(fountain, "decor_fountain.png")
	var tree := _new_image(40, 48)
	_shadow(tree, 20, 42, 13, 4)
	_rect(tree, 17, 27, 6, 13, Color("#7a4d2b"))
	_circle(tree, 20, 18, 14, Color("#2f7a3c"))
	_circle(tree, 13, 24, 10, Color("#3f9649"))
	_circle(tree, 27, 24, 10, Color("#246b34"))
	_save(tree, "decor_tree.png")
	var rock := _new_image(32, 28)
	_shadow(rock, 16, 23, 11, 3)
	_rect(rock, 8, 12, 15, 8, Color("#71747d"))
	_rect(rock, 11, 8, 11, 5, Color("#8e929b"))
	_rect(rock, 18, 14, 5, 4, Color("#585b63"))
	_save(rock, "decor_rock.png")
	var crystal := _new_image(32, 40)
	_shadow(crystal, 16, 34, 10, 3)
	_rect(crystal, 14, 6, 5, 23, Color("#8bddff"))
	_rect(crystal, 11, 14, 5, 16, Color("#4ba7e9"))
	_rect(crystal, 18, 15, 4, 15, Color("#b9f5ff"))
	_save(crystal, "decor_crystal.png")
	var stalagmite := _new_image(32, 40)
	_shadow(stalagmite, 16, 34, 9, 3)
	for y in range(10, 32):
		var half := int((32 - y) / 3)
		_rect(stalagmite, 16 - half, y, max(1, half * 2), 1, Color("#60616e"))
	_save(stalagmite, "decor_stalagmite.png")
	var house := _new_image(72, 64)
	_shadow(house, 36, 56, 28, 5)
	_rect(house, 12, 28, 48, 25, Color("#8b6744"))
	_rect(house, 16, 32, 40, 17, Color("#b88455"))
	_line_thick(house, Vector2i(9, 29), Vector2i(36, 10), Color("#4d2f28"), 8)
	_line_thick(house, Vector2i(63, 29), Vector2i(36, 10), Color("#4d2f28"), 8)
	_rect(house, 31, 39, 10, 14, Color("#3c2b20"))
	_rect(house, 18, 35, 9, 8, Color("#d5e8f4"))
	_rect(house, 45, 35, 9, 8, Color("#d5e8f4"))
	_save(house, "decor_house.png")
	var forge := _new_image(72, 64)
	_shadow(forge, 36, 56, 28, 5)
	_rect(forge, 10, 30, 50, 24, Color("#555a60"))
	_rect(forge, 16, 34, 38, 16, Color("#777d84"))
	_rect(forge, 22, 38, 14, 12, Color("#241915"))
	_circle(forge, 29, 43, 7, Color("#ff8b2e"))
	_line_thick(forge, Vector2i(8, 30), Vector2i(36, 11), Color("#322828"), 8)
	_line_thick(forge, Vector2i(64, 30), Vector2i(36, 11), Color("#322828"), 8)
	_rect(forge, 49, 12, 8, 18, Color("#3a3030"))
	_rect(forge, 47, 8, 12, 5, Color("#242020"))
	_save(forge, "decor_forge.png")

func _make_tile(file_name: String, base: Color, speckles: Array[Color]) -> void:
	var tile := _new_image(32, 32)
	tile.fill(base)
	for y in range(0, 32, 4):
		for x in range(0, 32, 4):
			var color: Color = speckles[int((x + y) / 4) % speckles.size()]
			if randf() > 0.35:
				_rect(tile, x, y, 3, 2, color)
	_save(tile, file_name)

func _make_tiles() -> void:
	_make_tile("tile_grass.png", Color("#4d8a43"), [Color("#5fa64f"), Color("#3f793a"), Color("#6dbb58")])
	_make_tile("tile_water.png", Color("#178ca3"), [Color("#20b1c5"), Color("#0f6f8e"), Color("#5bd6e8")])
	_make_tile("tile_stone.png", Color("#707b80"), [Color("#889297"), Color("#5c656b"), Color("#9aa2a7")])
	_make_tile("tile_path.png", Color("#c3a879"), [Color("#d7be8a"), Color("#a88d63"), Color("#ead49d")])
	_make_tile("tile_sand.png", Color("#d9c08b"), [Color("#ecd9a4"), Color("#bea170"), Color("#f4e5bb")])
	_make_tile("tile_bridge.png", Color("#8b5730"), [Color("#a96c3d"), Color("#6f4226"), Color("#c2824d")])
	_make_tile("tile_arcane.png", Color("#303154"), [Color("#454574"), Color("#232542"), Color("#5f5792")])
	_make_tile("tile_ruin.png", Color("#505274"), [Color("#686a91"), Color("#393b5f"), Color("#777aa0")])
	_make_tile("tile_cave.png", Color("#181b22"), [Color("#262a35"), Color("#11141a"), Color("#333845")])
	_make_tile("tile_cave_floor.png", Color("#2b3039"), [Color("#383e49"), Color("#20252d"), Color("#4b5260")])

func _icon_base(accent: Color) -> Image:
	var image := _new_image(48, 48)
	_circle(image, 24, 24, 23, Color(0.02, 0.025, 0.035, 0.96))
	_circle(image, 24, 24, 20, Color(0.10, 0.11, 0.14, 0.96))
	_circle(image, 24, 24, 17, Color(accent.r, accent.g, accent.b, 0.20))
	_rect(image, 11, 39, 26, 2, Color(1, 1, 1, 0.10))
	return image

func _save_icon(image: Image, file_name: String) -> void:
	_save(image, file_name)

func _make_app_icon(size: int, transparent: bool = false) -> Image:
	var image := _new_image(size, size)
	if not transparent:
		image.fill(Color("#182130"))
	var scale := float(size) / 192.0
	_circle(image, int(size * 0.5), int(size * 0.5), int(78 * scale), Color("#273448"))
	_circle(image, int(size * 0.5), int(size * 0.5), int(68 * scale), Color("#3b4d67"))
	_rect(image, int(88 * scale), int(44 * scale), int(16 * scale), int(90 * scale), Color("#dfe7ee"))
	_rect(image, int(75 * scale), int(122 * scale), int(42 * scale), int(12 * scale), Color("#a46a31"))
	_rect(image, int(83 * scale), int(134 * scale), int(26 * scale), int(18 * scale), Color("#72461f"))
	_line_thick(image, Vector2i(int(48 * scale), int(62 * scale)), Vector2i(int(143 * scale), int(157 * scale)), Color("#f3c95e"), max(2, int(7 * scale)))
	_line_thick(image, Vector2i(int(143 * scale), int(62 * scale)), Vector2i(int(48 * scale), int(157 * scale)), Color("#f3c95e"), max(2, int(7 * scale)))
	_rect(image, int(84 * scale), int(38 * scale), int(24 * scale), int(14 * scale), Color("#f4f8ff"))
	return image

func _make_app_icons() -> void:
	_save(_make_app_icon(192), "app_icon_192.png")
	var background := _new_image(432, 432)
	background.fill(Color("#182130"))
	_save(background, "app_icon_background_432.png")
	_save(_make_app_icon(432, true), "app_icon_foreground_432.png")

func _draw_sword_icon(image: Image, from: Vector2i, to: Vector2i) -> void:
	_line_thick(image, from + Vector2i(2, 2), to + Vector2i(2, 2), Color(0, 0, 0, 0.36), 4)
	_line_thick(image, from, to, Color("#dce7ef"), 4)
	_line_thick(image, from + Vector2i(2, 0), to + Vector2i(2, 0), Color("#8ea8bd"), 1)
	_rect(image, from.x - 3, from.y - 2, 10, 4, Color("#8a5a34"))
	_rect(image, from.x - 1, from.y + 1, 5, 7, Color("#513322"))
	_rect(image, to.x - 2, to.y - 3, 5, 5, Color("#fff6ca"))

func _draw_bow_icon(image: Image) -> void:
	_line_thick(image, Vector2i(17, 10), Vector2i(32, 23), Color("#9a5f31"), 3)
	_line_thick(image, Vector2i(32, 23), Vector2i(17, 38), Color("#9a5f31"), 3)
	_line(image, Vector2i(18, 11), Vector2i(18, 38), Color("#f3e7c0"))
	_line_thick(image, Vector2i(13, 24), Vector2i(34, 24), Color("#d9ecff"), 2)
	_rect(image, 31, 21, 5, 6, Color("#eef7ff"))
	_rect(image, 10, 22, 5, 4, Color("#7dd66e"))

func _draw_book_icon(image: Image) -> void:
	_rect(image, 13, 12, 23, 26, Color("#241f54"))
	_rect(image, 15, 10, 21, 26, Color("#5d63da"))
	_rect(image, 18, 13, 15, 20, Color("#32399c"))
	_rect(image, 15, 10, 4, 26, Color("#1e214f"))
	_rect(image, 21, 18, 8, 2, Color("#b8f2ff"))
	_rect(image, 23, 23, 8, 2, Color("#b8f2ff"))
	_circle(image, 33, 13, 4, Color("#8be6ff"))

func _draw_fire(image: Image, cx: int, cy: int) -> void:
	_circle(image, cx, cy + 4, 10, Color("#e84d2f"))
	_circle(image, cx + 2, cy + 3, 8, Color("#ff8d2e"))
	_circle(image, cx + 2, cy + 4, 5, Color("#ffe15a"))
	_line_thick(image, Vector2i(cx - 4, cy - 2), Vector2i(cx + 1, cy - 13), Color("#ff6b2f"), 4)
	_line_thick(image, Vector2i(cx + 3, cy - 2), Vector2i(cx + 8, cy - 10), Color("#ffb02e"), 3)

func _draw_starburst(image: Image, color: Color) -> void:
	_circle(image, 24, 24, 7, color)
	_circle(image, 24, 24, 4, Color("#f2dbff"))
	for target in [Vector2i(24, 8), Vector2i(24, 40), Vector2i(8, 24), Vector2i(40, 24), Vector2i(12, 12), Vector2i(36, 12), Vector2i(12, 36), Vector2i(36, 36)]:
		_line_thick(image, Vector2i(24, 24), target, color, 2)

func _draw_potion_icon(file_name: String, liquid: Color, glow: Color, medium: bool) -> void:
	var image := _icon_base(glow)
	var width := 17 if medium else 13
	var left := 24 - int(width / 2)
	_rect(image, 21, 9, 7, 4, Color("#dedede"))
	_rect(image, 20, 13, 9, 3, Color("#9aa0a8"))
	_rect(image, left - 2, 16, width + 4, 20, Color("#1c1a22"))
	_rect(image, left, 17, width, 17, Color("#e6e7ef"))
	_rect(image, left + 1, 23, width - 2, 10, liquid)
	_rect(image, left + 3, 19, 4, 4, Color(1, 1, 1, 0.56))
	_circle(image, 30, 30, 6 if medium else 4, glow)
	_save_icon(image, file_name)

func _make_action_icons() -> void:
	var sword := _icon_base(Color("#c94f3d"))
	_draw_sword_icon(sword, Vector2i(14, 34), Vector2i(34, 12))
	_save_icon(sword, "icon_attack_sword.png")

	var book := _icon_base(Color("#6a76e8"))
	_draw_book_icon(book)
	_save_icon(book, "icon_attack_book.png")

	var bow := _icon_base(Color("#58b878"))
	_draw_bow_icon(bow)
	_save_icon(bow, "icon_attack_bow.png")

	var heavy_slash := _icon_base(Color("#e6b34f"))
	_draw_sword_icon(heavy_slash, Vector2i(14, 35), Vector2i(34, 12))
	_line_thick(heavy_slash, Vector2i(9, 14), Vector2i(37, 34), Color("#ffe4a3"), 3)
	_save_icon(heavy_slash, "icon_skill_heavy_slash.png")

	var war_cry := _icon_base(Color("#e6b34f"))
	_circle(war_cry, 24, 26, 8, Color("#f1c58f"))
	_rect(war_cry, 18, 16, 12, 8, Color("#7d8389"))
	_rect(war_cry, 18, 28, 12, 5, Color("#9f3d31"))
	for target in [Vector2i(8, 15), Vector2i(40, 15), Vector2i(7, 27), Vector2i(41, 27)]:
		_line_thick(war_cry, Vector2i(24, 24), target, Color("#ffd96b"), 2)
	_save_icon(war_cry, "icon_skill_war_cry.png")

	var blade_spin := _icon_base(Color("#dce7ef"))
	_line_thick(blade_spin, Vector2i(11, 23), Vector2i(22, 11), Color("#dce7ef"), 3)
	_line_thick(blade_spin, Vector2i(25, 37), Vector2i(37, 25), Color("#dce7ef"), 3)
	_line_thick(blade_spin, Vector2i(14, 34), Vector2i(34, 14), Color("#8ea8bd"), 2)
	_rect(blade_spin, 35, 22, 5, 5, Color("#fff6ca"))
	_save_icon(blade_spin, "icon_skill_blade_spin.png")

	var fireball := _icon_base(Color("#ff7a2c"))
	_draw_fire(fireball, 25, 23)
	_line_thick(fireball, Vector2i(10, 32), Vector2i(18, 28), Color("#ffb02e"), 2)
	_save_icon(fireball, "icon_skill_fireball.png")

	var arcane_blast := _icon_base(Color("#9a63ff"))
	_draw_starburst(arcane_blast, Color("#a666ff"))
	_save_icon(arcane_blast, "icon_skill_arcane_blast.png")

	var mystic_shield := _icon_base(Color("#6fd6ff"))
	_rect(mystic_shield, 16, 12, 16, 20, Color("#5ac7ff"))
	_rect(mystic_shield, 18, 14, 12, 17, Color("#254b9a"))
	_rect(mystic_shield, 20, 16, 8, 12, Color("#8be6ff"))
	_line_thick(mystic_shield, Vector2i(16, 31), Vector2i(24, 39), Color("#5ac7ff"), 3)
	_line_thick(mystic_shield, Vector2i(32, 31), Vector2i(24, 39), Color("#5ac7ff"), 3)
	_save_icon(mystic_shield, "icon_skill_mystic_shield.png")

	var precise_shot := _icon_base(Color("#58b878"))
	_line_thick(precise_shot, Vector2i(9, 24), Vector2i(38, 24), Color("#d9ecff"), 3)
	_rect(precise_shot, 35, 20, 6, 8, Color("#eef7ff"))
	_rect(precise_shot, 8, 21, 6, 6, Color("#7dd66e"))
	_line(precise_shot, Vector2i(24, 9), Vector2i(24, 39), Color("#89ff7f"))
	_line(precise_shot, Vector2i(9, 24), Vector2i(39, 24), Color("#89ff7f"))
	_save_icon(precise_shot, "icon_skill_precise_shot.png")

	var arrow_rain := _icon_base(Color("#58b878"))
	for x in [15, 24, 33]:
		_line_thick(arrow_rain, Vector2i(x - 4, 10), Vector2i(x + 3, 34), Color("#d9ecff"), 2)
		_rect(arrow_rain, x + 1, 31, 5, 5, Color("#eef7ff"))
		_rect(arrow_rain, x - 6, 9, 5, 4, Color("#7dd66e"))
	_save_icon(arrow_rain, "icon_skill_arrow_rain.png")

	var quick_jump := _icon_base(Color("#7dd66e"))
	_rect(quick_jump, 18, 26, 13, 8, Color("#5b3d28"))
	_rect(quick_jump, 15, 31, 21, 4, Color("#2e2018"))
	_rect(quick_jump, 22, 19, 7, 9, Color("#3f8f57"))
	_line_thick(quick_jump, Vector2i(34, 16), Vector2i(14, 16), Color("#d8ff92"), 3)
	_line_thick(quick_jump, Vector2i(14, 16), Vector2i(20, 10), Color("#d8ff92"), 3)
	_line_thick(quick_jump, Vector2i(14, 16), Vector2i(20, 22), Color("#d8ff92"), 3)
	_save_icon(quick_jump, "icon_skill_quick_jump.png")

func _make_ui_icons() -> void:
	_draw_potion_icon("icon_potion_health_small.png", Color("#e84774"), Color("#ff758d"), false)
	_draw_potion_icon("icon_potion_health_medium.png", Color("#d8344a"), Color("#ff9d6b"), true)
	_draw_potion_icon("icon_potion_mana_small.png", Color("#39a8ff"), Color("#7bdcff"), false)
	_draw_potion_icon("icon_potion_mana_medium.png", Color("#5268ff"), Color("#a18cff"), true)

	var base := _new_image(96, 96)
	_circle(base, 48, 48, 44, Color(0.03, 0.035, 0.045, 0.52))
	_circle(base, 48, 48, 37, Color(0.16, 0.18, 0.20, 0.38))
	_circle(base, 48, 48, 8, Color(1, 1, 1, 0.10))
	_line_thick(base, Vector2i(48, 11), Vector2i(48, 27), Color(1, 1, 1, 0.16), 3)
	_line_thick(base, Vector2i(48, 69), Vector2i(48, 85), Color(1, 1, 1, 0.16), 3)
	_line_thick(base, Vector2i(11, 48), Vector2i(27, 48), Color(1, 1, 1, 0.16), 3)
	_line_thick(base, Vector2i(69, 48), Vector2i(85, 48), Color(1, 1, 1, 0.16), 3)
	_save(base, "ui_joystick_base.png")

	var knob := _new_image(64, 64)
	_circle(knob, 32, 32, 29, Color(0.02, 0.025, 0.032, 0.82))
	_circle(knob, 32, 32, 23, Color(0.34, 0.40, 0.45, 0.88))
	_circle(knob, 29, 27, 8, Color(1, 1, 1, 0.18))
	_save(knob, "ui_joystick_knob.png")
	var close := _icon_base(Color("#e64949"))
	_line_thick(close, Vector2i(14, 14), Vector2i(34, 34), Color("#ff655d"), 6)
	_line_thick(close, Vector2i(34, 14), Vector2i(14, 34), Color("#ff655d"), 6)
	_save(close, "icon_menu_close.png")

	_make_slot_icons()

func _slot_base() -> Image:
	var image := _new_image(48, 48)
	_circle(image, 24, 24, 22, Color(0.03, 0.035, 0.045, 0.88))
	_circle(image, 24, 24, 18, Color(0.28, 0.30, 0.34, 0.28))
	return image

func _make_slot_icons() -> void:
	var amulet := _slot_base()
	_line_thick(amulet, Vector2i(15, 13), Vector2i(24, 28), Color(0.7, 0.75, 0.78, 0.42), 2)
	_line_thick(amulet, Vector2i(33, 13), Vector2i(24, 28), Color(0.7, 0.75, 0.78, 0.42), 2)
	_circle(amulet, 24, 30, 5, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(amulet, "icon_slot_amulet.png")

	var helmet := _slot_base()
	_rect(helmet, 15, 17, 18, 12, Color(0.7, 0.75, 0.78, 0.42))
	_rect(helmet, 18, 12, 12, 6, Color(0.7, 0.75, 0.78, 0.42))
	_rect(helmet, 14, 28, 20, 4, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(helmet, "icon_slot_helmet.png")

	var backpack := _slot_base()
	_rect(backpack, 15, 17, 18, 20, Color(0.7, 0.75, 0.78, 0.42))
	_rect(backpack, 18, 12, 12, 6, Color(0.7, 0.75, 0.78, 0.42))
	_rect(backpack, 18, 24, 12, 3, Color(0.03, 0.035, 0.045, 0.50))
	_save_icon(backpack, "icon_slot_backpack.png")

	var shield := _slot_base()
	_rect(shield, 16, 13, 16, 18, Color(0.7, 0.75, 0.78, 0.42))
	_line_thick(shield, Vector2i(16, 30), Vector2i(24, 39), Color(0.7, 0.75, 0.78, 0.42), 3)
	_line_thick(shield, Vector2i(32, 30), Vector2i(24, 39), Color(0.7, 0.75, 0.78, 0.42), 3)
	_save_icon(shield, "icon_slot_shield.png")

	var armor := _slot_base()
	_rect(armor, 16, 15, 16, 21, Color(0.7, 0.75, 0.78, 0.42))
	_rect(armor, 12, 18, 5, 8, Color(0.7, 0.75, 0.78, 0.42))
	_rect(armor, 31, 18, 5, 8, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(armor, "icon_slot_armor.png")

	var weapon := _slot_base()
	_draw_sword_icon(weapon, Vector2i(16, 35), Vector2i(33, 14))
	_save_icon(weapon, "icon_slot_weapon.png")

	var ring := _slot_base()
	_circle(ring, 24, 25, 10, Color(0.7, 0.75, 0.78, 0.42))
	_circle(ring, 24, 25, 5, Color(0.03, 0.035, 0.045, 0.88))
	_save_icon(ring, "icon_slot_ring.png")

	var pants := _slot_base()
	_rect(pants, 17, 14, 14, 8, Color(0.7, 0.75, 0.78, 0.42))
	_rect(pants, 16, 22, 6, 16, Color(0.7, 0.75, 0.78, 0.42))
	_rect(pants, 26, 22, 6, 16, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(pants, "icon_slot_pants.png")

	var jewel := _slot_base()
	_rect(jewel, 18, 16, 12, 5, Color(0.7, 0.75, 0.78, 0.42))
	_rect(jewel, 15, 21, 18, 8, Color(0.7, 0.75, 0.78, 0.42))
	_rect(jewel, 20, 29, 8, 6, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(jewel, "icon_slot_jewel.png")

	var boots := _slot_base()
	_rect(boots, 15, 17, 8, 18, Color(0.7, 0.75, 0.78, 0.42))
	_rect(boots, 25, 17, 8, 18, Color(0.7, 0.75, 0.78, 0.42))
	_rect(boots, 13, 32, 12, 5, Color(0.7, 0.75, 0.78, 0.42))
	_rect(boots, 25, 32, 12, 5, Color(0.7, 0.75, 0.78, 0.42))
	_save_icon(boots, "icon_slot_boots.png")
