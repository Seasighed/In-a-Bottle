class_name SpriteIconHost
extends Control

var _sprite: Sprite2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	_refresh_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _sprite != null:
		_refresh_layout()

func set_icon(texture: Texture2D, tint: Color = Color.WHITE, icon_size: float = 20.0) -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.modulate = tint
	if texture == null:
		_sprite.scale = Vector2.ONE
		return
	var texture_size: Vector2 = texture.get_size()
	var scale_factor: float = 1.0
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		scale_factor = minf(icon_size / texture_size.x, icon_size / texture_size.y)
	_sprite.scale = Vector2.ONE * scale_factor
	_refresh_layout()

func _refresh_layout() -> void:
	if _sprite == null:
		return
	_sprite.position = size * 0.5
