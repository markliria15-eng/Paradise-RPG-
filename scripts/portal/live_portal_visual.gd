extends Node2D

@export_range(0.05, 0.4, 0.01) var display_scale := 0.20
@export_range(1.0, 12.0, 0.5) var animation_speed := 6.0

const PORTAL_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/portal_live/portal_live_frame_01.png"),
	preload("res://assets/sprites/portal_live/portal_live_frame_02.png"),
	preload("res://assets/sprites/portal_live/portal_live_frame_03.png"),
	preload("res://assets/sprites/portal_live/portal_live_frame_04.png")
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = 6
	if animated_sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", animation_speed)
	for texture in PORTAL_FRAMES:
		if texture != null:
			frames.add_frame("idle", texture)
	animated_sprite.sprite_frames = frames
	animated_sprite.animation = "idle"
	animated_sprite.play("idle")
	animated_sprite.centered = true
	animated_sprite.scale = Vector2.ONE * display_scale
	animated_sprite.z_index = 6
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
