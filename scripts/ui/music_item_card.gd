extends TextureRect

signal card_clicked(track_data: Dictionary)

var track_id: String = ""
var track_data: Dictionary = {}

func _ready():
	"""
	Initialize the music item card.
	Set mouse filter to stop propagation.
	Scale the card for display.
	"""
	mouse_filter = Control.MOUSE_FILTER_STOP
	scale = Vector2(0.71, 0.71)
	print("✓ MusicItemCard ready")

func setup(data: Dictionary):
	"""
	Load card texture from atlas using provided data dictionary.
	Stores track_id and data for future reference.
	"""
	track_data = data
	track_id = data.id
	
	if data.has("atlas") and data.has("region"):
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = load(data.atlas)
		atlas_texture.region = data.region
		texture = atlas_texture
		print("✓ Card loaded: %s" % data.name)

func _gui_input(event: InputEvent):
	"""
	Detect mouse clicks or screen touches on the card.
	Emit a click signal and play an animation if clicked.
	"""
	var is_click = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
	
	if is_click:
		_on_card_clicked()

func _on_card_clicked():
	"""
	Handle card click event.
	Print info, emit signal, and animate the card.
	"""
	print("🎵 Card clicked: %s" % track_data.get("name", "unknown"))
	emit_signal("card_clicked", track_data)
	_animate_click()

func _animate_click():
	"""
	Play a click animation that slightly scales down and then back to original.
	Uses easing for smooth effect.
	"""
	var original_scale = scale
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", original_scale * 0.95, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)
