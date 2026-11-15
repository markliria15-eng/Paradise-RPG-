extends Node2D

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Estado do jogo: constantes, nos da cena e todas as variaveis que o resto do main usa.
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.


# Orquestra o MVP: carrega dados, troca mapas, conecta combate, UI, drops,
# missoes e save sem esconder numeros de balanceamento dentro do codigo.
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const DROP_SCENE := preload("res://scenes/item_drop.tscn")
const POTION_SLOTS := [
	{"item": "Pocao pequena de vida", "label": "HP P", "shortcut": "F1", "icon": "res://assets/ui/buttons/btn_potion_hp.png"},
	{"item": "Pocao media de vida", "label": "HP M", "shortcut": "F2", "icon": "res://assets/ui/buttons/btn_potion_hp.png"},
	{"item": "Pocao pequena de mana", "label": "MP P", "shortcut": "F3", "icon": "res://assets/ui/buttons/btn_potion_mp.png"},
	{"item": "Pocao media de mana", "label": "MP M", "shortcut": "F4", "icon": "res://assets/ui/buttons/btn_potion_mp.png"}
]
const POTION_BUTTON_POSITIONS := [
	Vector2(862, 522),
	Vector2(936, 464),
	Vector2(1010, 406),
	Vector2(1084, 348)
]
const POTION_BUTTON_SIZE := Vector2(66, 62)
const SKILL_BUTTON_POSITIONS := [
	Vector2(896, 590),
	Vector2(972, 532),
	Vector2(1048, 474)
]
const SKILL_BUTTON_SIZE := Vector2(74, 68)
const QUICK_TOP_BUTTON_POSITIONS := [
	Vector2(1000, 78),
	Vector2(1068, 78),
	Vector2(1136, 78),
	Vector2(1204, 78)
]
const QUICK_TOP_BUTTON_SIZE := Vector2(68, 62)
const CHAT_PANEL_POS := Vector2(18, 166)
const CHAT_PANEL_SIZE := Vector2(420, 238)
const CHAT_MAX_LINES := 60
const INTERACT_BUTTON_POS := Vector2(1166, 456)
const INTERACT_BUTTON_SIZE := Vector2(64, 58)
const DEFAULT_MAP_SIZE := Vector2(2200, 1400)
const DROP_PICKUP_RADIUS := 128.0
const DROP_COLLECT_RADIUS := 24.0
const DROP_MAGNET_SPEED := 460.0
const ENEMY_RESPAWN_MULTIPLIER := 3.5
const SAFE_ZONE_REGEN := 5
# Portais de chao (assets/portals_v2/<tema>/): base, magia, aura de tras e aura da
# frente, 512x512 com os pes do personagem em (256, 320).
const PORTAL_V2_ROOT := "res://assets/portals_v2"
const PORTAL_V2_ANCHOR := Vector2(256, 320)
const PORTAL_V2_SCALE := 0.8
# Teste dos mapas: portais sem exigir chefe derrotado. Voltar para false depois.
const PORTALS_FREE_ACCESS := true
const BEGINNER_QUESTS := []
const ATTACK_ICON_BY_CLASS := {
	"Guerreiro": "res://assets/ui/buttons/btn_attack.png",
	"Mago": "res://assets/ui/buttons/btn_attack.png",
	"Arqueiro": "res://assets/ui/buttons/btn_attack.png"
}
const SKILL_ICON_BY_ID := {
	"heavy_slash": "res://assets/ui/skills/skill_area_da_morte.png",
	"war_cry": "res://assets/ui/skills/skill_hora_do_heroi.png",
	"blade_spin": "res://assets/ui/skills/skill_area_da_morte.png",
	"fireball": "res://assets/ui/skills/skill_bola_de_fogo.png",
	"arcane_blast": "res://assets/ui/skills/skill_mana_viva.png",
	"mystic_shield": "res://assets/ui/skills/skill_protecao.png",
	"precise_shot": "res://assets/ui/skills/skill_tiro_atordoante.png",
	"arrow_rain": "res://assets/ui/skills/skill_chuva_de_flechas.png",
	"quick_jump": "res://assets/ui/skills/skill_agilidade.png",
	"death_area": "res://assets/ui/skills/skill_area_da_morte.png",
	"hero_hour": "res://assets/ui/skills/skill_hora_do_heroi.png",
	"soul_reaper": "res://assets/ui/skills/skill_ceifador_de_almas.png",
	"blue_meteor": "res://assets/ui/skills/skill_meteoro_azul.png",
	"burning_fireball": "res://assets/ui/skills/skill_bola_de_fogo.png",
	"fire_hurricane": "res://assets/ui/skills/skill_furacao_de_fogo.png",
	"agility": "res://assets/ui/skills/skill_agilidade.png",
	"stun_shot": "res://assets/ui/skills/skill_tiro_atordoante.png"
}
const RANK_KEYS := {
	"Level": "top_level",
	"Ouro": "top_gold",
	"Lutando": "top_fighting",
	"Magica": "top_magic",
	"Distancia": "top_distance",
	"Protecao": "top_protection"
}
const PET_ASSET_BY_CODE := {
	"mini_wolf": "mini_lobo",
	"baby_boar": "javali_bebe",
	"forest_sprite": "espirito_da_floresta",
	"arcane_fairy": "fada_arcana",
	"shadow_bat": "morcego_sombrio",
	"ember_imp": "diabrete_de_brasa",
	"frost_wisp": "fagulha_gelida",
	"stone_turtle": "tartaruga_de_pedra",
	"venom_spider": "aranha_venenosa_filhote",
	"golden_drake": "draco_dourado"
}
const PET_MOVE_ANIMATION_BY_ASSET := {
	"espirito_da_floresta": "move_float",
	"fada_arcana": "move_float",
	"fagulha_gelida": "move_float",
	"morcego_sombrio": "fly"
}
const ELDORIA_BACKGROUND_PATH := "res://assets/maps/eldoria/Eldoria_Complete_Background_4x_sharp.png"
const ELDORIA_MINIMAP_PATH := "res://assets/maps/eldoria/Eldoria_Minimap.png"
const ELDORIA_CHUNKED_MINIMAP_PATH := "res://assets/maps/eldoria/eldoria_9x9_minimap.png"
const ELDORIA_CHUNKS_DIR := "res://assets/maps/eldoria/chunks_9x9"
const ELDORIA_WATER_FRAMES_DIR := "res://assets/maps/eldoria/water_frames"
const ELDORIA_WATER_FRAME_COUNT := 4
const ELDORIA_HOUSE_KIT_DATA_PATH := "res://data/eldoria_house_kit.json"
const ELDORIA_REBUILD_BASE_ONLY := true
const ELDORIA_COLLISION_DATA_PATH := "res://data/eldoria_colisoes_coordenadas_refeito.json"
# Eldoria v2 (tools/eldoria_v2): chao em chunks, agua animada, props e colisoes num JSON.
const ELDORIA_V2_KIT_DATA_PATH := "res://data/eldoria_kit.json"
const RUINS_KIT_DATA_PATH := "res://data/ruins_kit.json"
const ARCANE_RUINS_COLLISION_DATA_PATH := "res://data/arcane_ruins_colisoes_revisado.json"
const ELDORIA_SOURCE_SIZE := Vector2(1800, 1440)
const ELDORIA_CHUNK_GRID := Vector2i(9, 9)
const ELDORIA_CHUNK_SIZE := Vector2(200, 160)
const ELDORIA_WORLD_SCALE := 4.0
const ELDORIA_WORLD_SIZE := ELDORIA_SOURCE_SIZE * ELDORIA_WORLD_SCALE
const ELDORIA_WALL_THICKNESS := 48.0
const ELDORIA_CITY_OFFSET := Vector2(200, 160)
const ELDORIA_CITY_SOURCE_SIZE := Vector2(1400, 1120)
const ELDORIA_BOTTOM_GATE_LEFT := 810.0
const ELDORIA_BOTTOM_GATE_RIGHT := 990.0
const ELDORIA_BOTTOM_DECK_LEFT := 820.0
const ELDORIA_BOTTOM_DECK_RIGHT := 980.0
const ELDORIA_FUTURE_NPC_LOCATIONS := {
	"arion_mestre_classes": {
		"name": "Marcos o mestre",
		"profession": "class_master",
		"house": "Casa dos Mestres",
		"source_pos": Vector2(445, 550)
	},
	"bakka_ferreiro": {
		"name": "Manoel ferrugem o ferreiro",
		"profession": "blacksmith",
		"house": "Ferraria do Manoel",
		"source_pos": Vector2(1340, 505)
	},
	"sarah_curandeira": {
		"name": "Sarah, Curandeira",
		"profession": "healer",
		"house": "Casa da Curandeira",
		"source_pos": Vector2(445, 1048)
	},
	"borin_mercador": {
		"name": "Carlos el mercador",
		"profession": "merchant",
		"house": "Armazem do Mercador",
		"source_pos": Vector2(1350, 1048)
	}
}
# NPCs de Eldoria ja ativos (reconstrucao um a um). Posicao vem de ELDORIA_FUTURE_NPC_LOCATIONS.
const ELDORIA_ACTIVE_NPCS := {
	"sarah_curandeira": {
		"role": "healer",
		"sprite": "res://assets/characters/npcs/npc_sarah_curandeira_idle_4f_128.png",
		"world_offset": Vector2(80, -130),
		"greeting": "Bem-vindo a Eldoria! Posso curar suas feridas e tenho pocoes frescas."
	},
	"arion_mestre_classes": {
		"role": "class_master",
		"sprite": "res://assets/characters/npcs/npc_arion_mestre_classes_idle_4f_128.png",
		"world_offset": Vector2(80, -11),
		"greeting": "Sou Marcos. Treine em combate real para dominar sua classe."
	},
	"bakka_ferreiro": {
		"role": "forge",
		"sprite": "res://assets/characters/npcs/npc_bakka_ferreiro_idle_4f_128.png",
		"world_offset": Vector2(220, -22),
		"greeting": "A forja esta quente! Traga materiais e eu melhoro seu equipamento."
	},
	"borin_mercador": {
		"role": "shop",
		"sprite": "res://assets/characters/npcs/npc_borin_mercador_idle_4f_128.png",
		"world_offset": Vector2(-140, -138),
		"greeting": "Ola, aventureiro! Tenho pocoes e suprimentos para sua jornada."
	}
}
const ELDORIA_BUILDING_COLLISION_RECTS := []
const ELDORIA_COLLISIONS := {
	"Water": [
		{"name": "Water_Top", "type": "rect", "x": 0, "y": 0, "w": 5016, "h": 320},
		{"name": "Water_Left", "type": "rect", "x": 0, "y": 320, "w": 192, "h": 4000},
		{"name": "Water_Right", "type": "rect", "x": 4840, "y": 320, "w": 176, "h": 4000},
		{"name": "Water_Bottom_Left", "type": "rect", "x": 0, "y": 4220, "w": 2260, "h": 796},
		{"name": "Water_Bottom_Right", "type": "rect", "x": 2740, "y": 4220, "w": 2276, "h": 796}
	],
	"Walls": [
		{"name": "Wall_North_Main", "type": "rect", "x": 232, "y": 352, "w": 4552, "h": 248},
		{"name": "Wall_West_Main", "type": "rect", "x": 192, "y": 400, "w": 176, "h": 3800},
		{"name": "Wall_East_Main", "type": "rect", "x": 4664, "y": 400, "w": 176, "h": 3800},
		{"name": "Wall_South_Left", "type": "rect", "x": 240, "y": 3904, "w": 1880, "h": 312},
		{"name": "Wall_South_Right", "type": "rect", "x": 2896, "y": 3904, "w": 1896, "h": 312},
		{"name": "North_Gate_Block", "type": "rect", "x": 2300, "y": 340, "w": 420, "h": 460},
		{"name": "Tower_North_West", "type": "rect", "x": 88, "y": 140, "w": 380, "h": 568},
		{"name": "Tower_North_East", "type": "rect", "x": 4536, "y": 140, "w": 380, "h": 568},
		{"name": "Tower_South_West", "type": "rect", "x": 80, "y": 3560, "w": 460, "h": 680},
		{"name": "Tower_South_East", "type": "rect", "x": 4472, "y": 3560, "w": 460, "h": 680},
		{"name": "South_Gate_Tower_Left", "type": "rect", "x": 1960, "y": 3720, "w": 380, "h": 640},
		{"name": "South_Gate_Tower_Right", "type": "rect", "x": 2680, "y": 3720, "w": 380, "h": 640},
		{"name": "South_Gate_Stone_Left_Block", "type": "rect", "x": 2120, "y": 3920, "w": 220, "h": 260},
		{"name": "South_Gate_Stone_Right_Block", "type": "rect", "x": 2680, "y": 3920, "w": 220, "h": 260}
	],
	"Buildings": [
		{"name": "Building_ClassMaster_Fortress_Main", "type": "rect", "x": 768, "y": 680, "w": 1020, "h": 1000},
		{"name": "Building_ClassMaster_Towers_Top", "type": "rect", "x": 780, "y": 560, "w": 960, "h": 440},
		{"name": "Building_ClassMaster_Left_Tower", "type": "rect", "x": 800, "y": 760, "w": 340, "h": 620},
		{"name": "Building_ClassMaster_Right_Tower", "type": "rect", "x": 1340, "y": 760, "w": 360, "h": 620},
		{"name": "Building_Merchant_Main", "type": "rect", "x": 3060, "y": 940, "w": 960, "h": 760},
		{"name": "Building_Merchant_Awning_Props", "type": "rect", "x": 3000, "y": 1500, "w": 460, "h": 280},
		{"name": "Building_Merchant_Crates_Right", "type": "rect", "x": 3900, "y": 1280, "w": 260, "h": 420},
		{"name": "Building_Healer_Main", "type": "rect", "x": 720, "y": 2020, "w": 980, "h": 640},
		{"name": "Building_Healer_Roof_Block", "type": "rect", "x": 760, "y": 1940, "w": 860, "h": 420},
		{"name": "Building_Blacksmith_Main", "type": "rect", "x": 2940, "y": 1968, "w": 1200, "h": 720},
		{"name": "Building_Blacksmith_Forge_Yard", "type": "rect", "x": 3480, "y": 2080, "w": 720, "h": 600},
		{"name": "Building_Blacksmith_Tools_Right", "type": "rect", "x": 3860, "y": 2320, "w": 500, "h": 420},
		{"name": "Building_Market_Lower_Left_Stall", "type": "rect", "x": 820, "y": 2880, "w": 480, "h": 280},
		{"name": "Building_SW_House_01", "type": "rect", "x": 740, "y": 3500, "w": 620, "h": 420},
		{"name": "Building_SW_House_02", "type": "rect", "x": 1360, "y": 3120, "w": 480, "h": 460},
		{"name": "Building_SW_House_03", "type": "rect", "x": 1420, "y": 3360, "w": 380, "h": 280},
		{"name": "Building_SE_Market", "type": "rect", "x": 2840, "y": 3060, "w": 640, "h": 500},
		{"name": "Building_SE_House_01", "type": "rect", "x": 3500, "y": 3300, "w": 680, "h": 520},
		{"name": "Building_SE_House_02", "type": "rect", "x": 3700, "y": 2880, "w": 640, "h": 680},
		{"name": "Building_SE_House_03", "type": "rect", "x": 3100, "y": 3560, "w": 680, "h": 320}
	],
	"Fountain": [
		{"name": "Fountain_Central_Block", "type": "circle", "cx": 2500, "cy": 2200, "r": 220}
	],
	"Trees": [
		{"name": "Tree_Block_NW_Left_Garden", "type": "rect", "x": 300, "y": 700, "w": 440, "h": 1200},
		{"name": "Tree_Block_West_Lower_Garden", "type": "rect", "x": 300, "y": 2600, "w": 440, "h": 1040},
		{"name": "Tree_Block_NE_Right_Garden", "type": "rect", "x": 4300, "y": 640, "w": 380, "h": 1260},
		{"name": "Tree_Block_East_Lower_Garden", "type": "rect", "x": 4220, "y": 2000, "w": 460, "h": 1700},
		{"name": "Tree_Block_Center_Left", "type": "rect", "x": 1628, "y": 1980, "w": 380, "h": 540},
		{"name": "Tree_Block_Center_Right", "type": "rect", "x": 4100, "y": 2080, "w": 340, "h": 480},
		{"name": "Tree_Block_Lower_Left_Park", "type": "rect", "x": 280, "y": 2900, "w": 440, "h": 680},
		{"name": "Tree_Block_Lower_Right_Garden", "type": "rect", "x": 4160, "y": 2880, "w": 420, "h": 840}
	],
	"Props": [
		{"name": "Props_Left_Crates_North", "type": "rect", "x": 560, "y": 1720, "w": 260, "h": 240},
		{"name": "Props_Central_Left_Planter", "type": "rect", "x": 1720, "y": 2700, "w": 300, "h": 180},
		{"name": "Props_Central_Right_Planter", "type": "rect", "x": 2680, "y": 2700, "w": 300, "h": 180},
		{"name": "Props_Forge_Logs", "type": "rect", "x": 3360, "y": 2520, "w": 280, "h": 260},
		{"name": "Props_Forge_Target", "type": "rect", "x": 3940, "y": 2600, "w": 260, "h": 260},
		{"name": "Props_Market_Lower_Left_Crates", "type": "rect", "x": 720, "y": 3140, "w": 260, "h": 280},
		{"name": "Props_SE_Market_Crates", "type": "rect", "x": 2780, "y": 3420, "w": 260, "h": 280},
		{"name": "Props_Right_Side_Crates", "type": "rect", "x": 4380, "y": 2560, "w": 220, "h": 400}
	]
}
const VALDORIA_BACKGROUND_PATH := "res://assets/maps/valdoria/Valdoria_Complete_Background.png"
const VALDORIA_MINIMAP_PATH := "res://assets/maps/valdoria/Valdoria_Minimap.png"
const VALDORIA_SOURCE_SIZE := Vector2(1254, 1254)
const VALDORIA_WORLD_SIZE := VALDORIA_SOURCE_SIZE
# Floresta v2 (tools/forest_kit/generate_forest_kit.py): chao em chunks 10x10,
# arvores/pedras em data/forest_kit.json e mascara de area andavel.
const FOREST_MINIMAP_PATH := "res://assets/maps/floresta_v2/floresta_v2_minimap.png"
const FOREST_BASE_BACKGROUND_PATH := "res://assets/maps/floresta/floresta_base_background.png"
const FOREST_CHUNKS_DIR := "res://assets/maps/floresta_v2/chunks"
const FOREST_KIT_DATA_PATH := "res://data/forest_kit.json"
const FOREST_SOURCE_SIZE := Vector2(2000, 1600)
const FOREST_CHUNK_GRID := Vector2i(10, 10)
const FOREST_CHUNK_SIZE := Vector2(200, 160)
const FOREST_GROUND_SCALE := 2.0
const FOREST_WORLD_SCALE := 4.0
const FOREST_WORLD_SIZE := FOREST_SOURCE_SIZE * FOREST_WORLD_SCALE
const FOREST_PRIMARY_MAP_ID := "forest_boars"
const FOREST_COMPAT_MAP_ID := "world_reset"
const CAVE_BACKGROUND_PATH := "res://assets/maps/caverna/caverna_full_map.png"
const CAVE_MINIMAP_PATH := "res://assets/maps/caverna/caverna_full_map.png"
const CAVE_COLLISION_DATA_PATH := "res://data/caverna_colisoes_coordenadas.json"
const CAVE_CHUNKS_DIR := "res://assets/maps/caverna/chunks_5x4"
const CAVE_SOURCE_SIZE := Vector2(1400, 1120)
const CAVE_CHUNK_SIZE := Vector2(280, 280)
# Caverna v2 (tools/cave_v2/generate_cave_v2.py): chunks + mascara + lago + props.
const CAVE_KIT_DATA_PATH := "res://data/cave_kit.json"
# Valdoria v2 (tools/valdoria_v2/generate_valdoria_v2.py): cidade portuaria em kit (chunks + mascara + mar + predios).
const VALDORIA_KIT_DATA_PATH := "res://data/valdoria_kit.json"
const MAPS_REBUILD_BASE_ONLY := {
	"arcane_ruins": true,
	"bat_cave": true,
	"city_valdoria": true,
	"highland_pass": true,
	"crystal_mines": true,
	"ember_fortress": true
}
const HUD_LAYOUT_PATH := "user://hud_layout.json"
const HUD_LAYOUT_VERSION := 6
const MINIMAP_SIZE := Vector2(124, 106)
const SIDE_MENU_TAB_SIZE := Vector2(222, 68)
const SIDE_MENU_PANEL_SIZE := Vector2(470, 618)
const MINIMAP_CANVAS_POS := Vector2(19, 206)
const MINIMAP_FRAME_POS := Vector2(10, 182)
const MINIMAP_FRAME_SIZE := Vector2(150, 146)
const MINIMAP_WORLD_RADIUS := 720.0
const EXPLORATION_CELL := 48
const HUD_PANEL_POS := Vector2(8, 8)
const HUD_PANEL_SIZE := Vector2(326, 162)
const HUD_BAR_SIZE := Vector2(244, 16)
const HUD_HP_BAR_POS := Vector2(70, 42)
const HUD_MP_BAR_POS := Vector2(70, 84)
const HUD_XP_BAR_POS := Vector2(70, 125)
const HUD_LABEL_POS := Vector2(64, 5)
const HUD_LABEL_SIZE := Vector2(252, 20)
const HUD_JOYSTICK_DEFAULT_CENTER := Vector2(168, 592)
const HUD_JOYSTICK_SAFE_MARGIN := Vector2(20, 20)
const HUD_JOYSTICK_BASE_SIZE := Vector2(180, 180)
const HUD_JOYSTICK_KNOB_SIZE := Vector2(70, 70)
const CAMERA_ZOOMS := [0.84, 1.0, 1.16, 1.32]

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI
@onready var item_db: ItemDatabase = $ItemDatabase
@onready var class_db: ClassDatabase = $ClassDatabase
@onready var drop_system: DropSystem = $DropSystem

var maps: Dictionary = {}
var enemies_db: Dictionary = {}
var quest_system := QuestSystem.new()
var player: Player
var current_map := FOREST_PRIMARY_MAP_ID
var hud_label: Label
var xp_label: Label
var xp_bar: TextureProgressBar
var hp_bar: TextureProgressBar
var mana_bar: TextureProgressBar
var mana_label: Label
var hp_label: Label
var xp_value_label: Label
var hud_frame: Panel
var hud_skin_rect: TextureRect
var message_label: Label
var panel: PanelContainer
var panel_blocker: ColorRect
var input_guard: ColorRect
var side_menu_panel: PanelContainer
var side_menu_toggle_button: Button
var side_menu_visible := false
var last_ui_tap_ms := -1000
var last_ui_tap_pos := Vector2(-999, -999)
var last_ui_tap_was_touch := false
var selected_npc: Npc
var selected_portal: Area2D
var portal_nodes: Array[Area2D] = []
var current_target: Enemy
var regen_timer := 0.0
var current_map_size := DEFAULT_MAP_SIZE
var touch_buttons: Array[Button] = []
var touch_button_callbacks: Dictionary = {}
var attack_button: Button
var skill_buttons: Array[Button] = []
var interact_button: Button
var inventory_button: Button
var character_button: Button
var quests_button: Button
var chat_button: Button
var potion_buttons: Dictionary = {}
var side_menu_buttons: Array[Button] = []
var touch_move_index := -1
var touch_move_center := Vector2(160, 596)
var touch_move_radius := 72.0
var joystick_base: TextureRect
var joystick_knob: TextureRect
var current_panel := ""
var safe_zone_nodes: Array[Dictionary] = []
var player_camera: Camera2D
var mmo_client: Node
var online_mode := false
var remote_players: Dictionary = {}
var remote_texture_cache: Dictionary = {}
var remote_walk_frame_cache: Dictionary = {}
var net_move_accumulator := 0.0
var online_save_accumulator := 0.0
const WALK_CLASS_ASSET_ROOT := "res://assets/sprites/player_frames_caminhada_classes"
var mmo_cache: Dictionary = {}
var ui_input_lock_until := 0.0
var ui_controls_enabled := true
var minimap_panel: PanelContainer
var minimap_canvas: Control
var minimap_frame_rect: TextureRect
var exploration_by_map: Dictionary = {}
var exploration_last_pos_by_map: Dictionary = {}
var pet_definitions: Array = []
var mount_definitions: Array = []
var pet_follower: Sprite2D
var mount_follower: Sprite2D
# Montaria de verdade: a montaria inteira atras (filha do player) e, na frente dela, o heroi
# MONTADO desenhado sentado com uma perna de cada lado (assets/sprites/mounts/riders/<classe>).
# Enquanto montado o sprite normal do heroi fica escondido; nome e vida sobem com a cabeca.
var mount_back_sprite: Sprite2D
var mount_rider_sprite: Sprite2D
var mount_view := "side"           # side / front / back: de lado, descendo (de frente) ou subindo (de costas)
var mount_riders_cache: Dictionary = {}
const HERO_HEAD_Y := -85.0        # topo da cabeca do heroi em pe no espaco local do player
var mount_anim_time := 0.0
var mount_facing_right := false
var mount_rig_cache: Dictionary = {}
var mount_frames_cache: Dictionary = {}
const MOUNT_GROUND_Y := 22.0      # pes do heroi no espaco local do player
const HERO_HIP_TO_FEET := 50.0    # quadril do heroi ate os pes (sprite HD de 119 px)
const PetCombatVisuals = preload("res://scripts/combat_visuals.gd")
var pet_special_visual_index := 0
var pet_attack_timer := 0.0
var pet_allowed_target: Enemy
var companion_anim_time := 0.0
var pet_animation_cache: Dictionary = {}
var pet_animation_key := ""
var chat_panel: PanelContainer
var chat_history_scroll: ScrollContainer
var chat_history_box: VBoxContainer
var chat_input: LineEdit
var chat_channel_buttons: Dictionary = {}
var chat_lines: Array = []
var chat_panel_visible := false
var chat_selected_channel := "global"
var chat_last_sent_channel := ""
var chat_last_sent_text := ""
var chat_last_sent_at := 0.0
var pet_animation_frame := 0
var pet_animation_timer := 0.0
var pet_animation_actual_direction := "front"
var pet_last_direction := "front"
# Pet passeando em volta do heroi (posicao propria, alvo de passeio e se esta andando)
var pet_pos := Vector2.ZERO
var pet_wander_offset := Vector2(-70, 30)
var pet_wander_timer := 0.0
var pet_moving := false
# Vantagem de cada montaria (alem da velocidade de data/mmo_mounts.json).
# remount: segundos depois da luta para poder montar de novo (padrao MOUNT_REMOUNT_DELAY)
# armor: aguenta 1 golpe sem derrubar o heroi (recarrega em MOUNT_ARMOR_RECHARGE)
# regen: fracao da vida maxima recuperada por segundo montado e fora de luta
const MOUNT_REMOUNT_DELAY := 3.0
const MOUNT_ARMOR_RECHARGE := 12.0
const MOUNT_PERKS := {
	"brown_horse": {"remount": 1.5, "text": "Remonta rapida: monta de novo 1,5 s depois da luta."},
	"gray_wolf": {"remount": 1.5, "text": "Faro de cacador: monta de novo 1,5 s depois da luta."},
	"war_boar": {"armor": true, "text": "Couraca: aguenta 1 golpe sem te derrubar (recarrega em 12 s)."},
	"shadow_panther": {"armor": true, "remount": 1.5, "text": "Sombra: aguenta 1 golpe e monta de novo em 1,5 s."},
	"crystal_stag": {"regen": 0.01, "remount": 1.5, "text": "Cristal vivo: cura 1% da vida por segundo montado."},
}
const MOUNT_BUTTON_POS := Vector2(1166, 388)
const MOUNT_BUTTON_SIZE := Vector2(64, 58)
var mount_last_code := ""           # ultima montaria usada: o botao rapido monta nela de novo
var mount_combat_until := 0.0       # ate quando nao pode montar (acabou de lutar/apanhar)
var mount_armor_ready_at := 0.0
var mount_regen_acc := 0.0
var mount_button: Button
# Regras e numeros desenhados pelo ChatGPT (data/game_rules.json): afinidade, pedidos do pet,
# montarias, estabulo, diarias, eventos e NPCs. Sem o arquivo valem os padroes do codigo.
var game_rules: Dictionary = {}
var game_extras: GameExtras  # missoes diarias, eventos, colecao, modo foto... (scripts/game_extras.gd)
# Personalidade do pet: balaozinho de emocao em cima dele (assets/sprites/pets/emotes)
const PET_EMOTE_GAP := 2.5          # segundos minimos entre dois baloes
var pet_emote_ready_at := 0.0
var pet_last_level := -1
var pet_low_hp_next := 0.0
var pet_idle_time := 0.0
var pet_last_code_seen := ""
var pet_shadow: Sprite2D
# Afinidade com o pet (0-100, salva em mmo_cache["pet_affinity"][codigo]). Sobe atendendo os
# pedidos dele (fome, brincar, lutar, carinho) e jogando junto; cai quando o pedido e ignorado
# e quando voce fica dias sem jogar. Afinidade alta da bonus de dano ou de defesa.
const PET_NEEDS := ["maca", "bola", "espadas", "carinho"]
const PET_NEED_TEXT := {
	"maca": "esta com fome: de Carne Crua (cai dos javalis)",
	"bola": "quer brincar",
	"espadas": "quer lutar: derrote um monstro com ele por perto",
	"carinho": "quer carinho",
}
const PET_NEED_TIMEOUT := 45.0
const PET_AFFINITY_DECAY_PER_DAY := 10.0
const PET_FOOD := "Carne Crua"
var pet_need := ""
var pet_need_until := 0.0
var pet_next_need_at := 0.0
var pet_need_bubble: Sprite2D
var pet_play_until := 0.0
var pet_together_time := 0.0
var pet_pet_cooldown_until := 0.0
var pet_affinity_checked := false
var pet_button: Button
var pet_button_label: Label
const PET_BUTTON_POS := Vector2(1166, 322)
const PET_TARGET_HEIGHT := 125.0  # altura do quadro 192 px na tela (corpo do pet ~75 px, perto de 2/3 do heroi)
# Pets de chao nao passam por cima do heroi/montaria: atras da linha dos pes ficam atras,
# do lado ficam do lado, e na frente so longe o bastante para nao cobrir o desenho.
# Os voadores continuam livres.
const PET_FLYING_ASSETS := ["fada_arcana", "morcego_sombrio", "espirito_da_floresta", "fagulha_gelida"]
const PET_HALF_WIDTH := 38.0      # meia largura do corpo do pet na tela
const PET_FRONT_DEPTH := 72.0     # altura do corpo do pet: abaixo disso dos pes do heroi ele cobriria o desenho
var pet_was_behind := false
var pet_stuck_time := 0.0
var pet_attack_visual_timer := 0.0
var dialog_bubble: PanelContainer
var solid_obstacles: Array[Dictionary] = []
var portal_passage_rects: Array[Rect2] = []
var eldoria_collision_data: Dictionary = {}
var eldoria_house_kit_data: Dictionary = {}
var eldoria_kit_data: Dictionary = {}
var ruins_kit_data: Dictionary = {}
var arcane_ruins_collision_data: Dictionary = {}
var cave_collision_data: Dictionary = {}
var forest_kit_data: Dictionary = {}
var cave_kit_data: Dictionary = {}
var valdoria_kit_data: Dictionary = {}
# Veiculos/animais que andam por rotas no mapa atual (kit "vehicles"); refeito a cada _load_map.
var kit_vehicles: Array = []
var hero_bump_actor: Dictionary = {}
var forest_walk_image: Image
var forest_walk_cell := 16.0
var last_valid_player_position := Vector2.ZERO
var hud_status_pos := HUD_PANEL_POS
var hud_status_scale := 1.0
var hud_minimap_frame_pos := MINIMAP_FRAME_POS
var hud_minimap_scale := 1.0
var hud_joystick_center := Vector2(132, 586)
var hud_joystick_scale := 1.0
var hud_attack_pos := Vector2(1110, 586)
var hud_attack_scale := 1.0
var hud_skills_offset := Vector2.ZERO
var hud_skills_scale := 1.0
var hud_potions_offset := Vector2.ZERO
var hud_potions_scale := 1.0
var hud_zoom_index := 1
var launcher_boot_started := false
