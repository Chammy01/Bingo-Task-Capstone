extends CanvasLayer

signal purchase_confirmed(track_id: String)
signal purchase_failed(track_id: String)
signal preview_playing(track_name: String)
signal popup_closed()

@onready var overlay: ColorRect = $Overlay
@onready var popup_panel: PanelContainer = $Overlay/PopupPanel
@onready var card_preview: TextureRect = $Overlay/PopupPanel/MarginContainer/Control/CardPreview
@onready var play_button: TextureButton = $Overlay/PopupPanel/MarginContainer/Control/HBoxContainer/PlayButton
@onready var buy_button: TextureButton = $Overlay/PopupPanel/MarginContainer/Control/HBoxContainer/BuyButton
@onready var cancel_button: TextureButton = $Overlay/PopupPanel/MarginContainer/Control/HBoxContainer/CancelButton
@onready var price_label: Label = $Overlay/PopupPanel/MarginContainer/Control/CardPreview/PriceTag/PriceLabel
@onready var music_player: AudioStreamPlayer = $MusicPlayer 

var track_id: String = ""
var is_music_playing: bool = false
var popup_open_time: float = 0.0
var bg_music_was_playing: bool = false
var bg_music_position: float = 0.0  # Store playback position

var music_files = {
	"Blossom": "res://music/Blossom.mp3",
	"Valley": "res://music/Nature.mp3",
	"Horizon": "res://music/Horizon.mp3",
	"EveningGlow": "res://music/DefaultTrack.mp3",
	"Autumn": "res://music/autumn.mp3",
	"Snowy": "res://music/snowy.mp3"
}

var button_spritesheet = preload("res://Background/woodenbtn.png")

var buy_atlas := AtlasTexture.new()
var select_atlas := AtlasTexture.new()
var selected_atlas := AtlasTexture.new()

const FADE_TIME := 0.3
const FADE_DB := -40
const NORMAL_DB := 0

func _ready():
	buy_atlas.atlas = button_spritesheet
	buy_atlas.region = Rect2(587, 64, 168, 62)

	select_atlas.atlas = button_spritesheet
	select_atlas.region = Rect2(416, 192, 168, 62)

	selected_atlas.atlas = button_spritesheet
	selected_atlas.region = Rect2(586, 192, 168, 62)

	visible = false
	play_button.toggle_mode = true

	if not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	if not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not overlay.gui_input.is_connected(_on_overlay_input):
		overlay.gui_input.connect(_on_overlay_input)

	print("✓ MusicPreviewPopup ready")

func show_preview(data: Dictionary):
	track_id = data.get("id", "")
	is_music_playing = false

	_stop_preview()
	play_button.button_pressed = false

	if data.has("atlas") and data.has("region"):
		if ResourceLoader.exists(data.atlas):
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = load(data.atlas)
			atlas_texture.region = data.region
			card_preview.texture = atlas_texture

	if price_label and price_label.get_parent():
		if track_id == "DefaultTrack" or MusicManager.is_owned(track_id):
			price_label.get_parent().visible = false
		else:
			price_label.get_parent().visible = true
			var price = data.get("price", 100)
			price_label.text = str(price)
	
	_load_music(track_id)
	_update_buy_select_button()

	visible = true
	popup_open_time = Time.get_ticks_msec() / 1000.0
	_animate_popup_in()

func hide_popup():
	print("Hiding popup...")
	_stop_preview()
	_animate_popup_out()
	await get_tree().create_timer(0.3).timeout
	visible = false
	emit_signal("popup_closed")

func _animate_popup_in():
	overlay.modulate.a = 0
	popup_panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(popup_panel, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_popup_out():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tween.tween_property(popup_panel, "scale", Vector2(0.8, 0.8), 0.2)

func _load_music(id: String):
	var music_path = music_files.get(id, "")
	if music_path == "":
		print("⚠️ No path for track id %s" % id)
		return
	if not ResourceLoader.exists(music_path):
		print("⚠️ Music file missing: %s" % music_path)
		return
	music_player.stream = load(music_path)
	print("✓ Loaded preview music: %s" % music_path)

func _update_buy_select_button():
	if track_id == "DefaultTrack":
		var is_current = MusicManager.current_track == "DefaultTrack"
		if is_current:
			buy_button.texture_normal = selected_atlas
			buy_button.texture_pressed = selected_atlas
			buy_button.disabled = true
		else:
			buy_button.texture_normal = select_atlas
			buy_button.texture_pressed = selected_atlas
			buy_button.disabled = false
		return

	var owned = MusicManager.is_owned(track_id)
	var is_current_track = MusicManager.current_track == track_id

	if owned:
		if is_current_track:
			buy_button.texture_normal = selected_atlas
			buy_button.texture_pressed = selected_atlas
			buy_button.disabled = true
		else:
			buy_button.texture_normal = select_atlas
			buy_button.texture_pressed = selected_atlas
			buy_button.disabled = false
	else:
		buy_button.texture_normal = buy_atlas
		buy_button.texture_pressed = buy_atlas
		buy_button.disabled = false

func _play_preview():
	print("🎮 _play_preview called")
	
	# Pause the MusicManager's music player and save position
	if MusicManager and MusicManager.music_player:
		bg_music_was_playing = MusicManager.music_player.playing
		print("MusicManager.music_player.playing = %s" % MusicManager.music_player.playing)
		
		if MusicManager.music_player.playing:
			print("🎵 Pausing MusicManager music player...")
			# Save current playback position
			bg_music_position = MusicManager.music_player.get_playback_position()
			print("Saved position: %.2f seconds" % bg_music_position)
			# Pause instead of stop
			MusicManager.music_player.stream_paused = true
			print("MusicManager music paused")
	else:
		print("⚠️ MusicManager or music_player not found")
	
	# Then play preview music from a random position
	if music_player and music_player.stream:
		print("▶️ Starting preview: %s" % track_id)
		music_player.play()
		
		# Wait a frame for the stream to start, then seek to random position
		await get_tree().process_frame
		
		# Get stream length and pick random position (skip first and last 10%)
		var stream_length = music_player.stream.get_length()
		if stream_length > 0:
			var start_offset = stream_length * 0.1  # Skip first 10%
			var end_offset = stream_length * 0.9     # Skip last 10%
			var random_position = randf_range(start_offset, end_offset)
			music_player.seek(random_position)
			print("🎲 Random preview position: %.2f / %.2f seconds" % [random_position, stream_length])
		
		is_music_playing = true
		play_button.button_pressed = true
		emit_signal("preview_playing", track_id)
		print("Preview music playing = %s" % music_player.playing)
	else:
		print("⚠️ music_player or stream is null")

func _stop_preview():
	if music_player:
		music_player.stop()
		is_music_playing = false
		play_button.button_pressed = false
		print("⏹️ Stopped preview")
	
	# Resume background music from saved position
	if bg_music_was_playing and MusicManager and MusicManager.music_player:
		print("🎵 Resuming background music from position %.2f" % bg_music_position)
		# Unpause the music
		MusicManager.music_player.stream_paused = false
		# Seek to saved position
		MusicManager.music_player.seek(bg_music_position)
		bg_music_was_playing = false
		bg_music_position = 0.0

func _fade_bg_music_to(target_db: float, duration: float):
	if MusicManager and MusicManager.music_player:
		var tween = get_tree().create_tween()
		tween.tween_property(MusicManager.music_player, "volume_db", target_db, duration)

func _on_play_pressed():
	print("🎮 Play button pressed")
	if is_music_playing:
		_stop_preview()
	else:
		_play_preview()

func _on_buy_pressed():
	if MusicManager.is_owned(track_id):
		MusicManager.play_music(track_id)
		_update_buy_select_button()
		hide_popup()
		emit_signal("purchase_confirmed", track_id)
		Toast.show_toast("🎵 Selected: %s" % track_id, 2.0)
	else:
		if MusicManager.purchase_music(track_id):
			MusicManager.play_music(track_id)
			_update_buy_select_button()
			hide_popup()
			emit_signal("purchase_confirmed", track_id)
			Toast.show_toast("✅ Purchased & selected: %s" % track_id, 2.0)
		else:
			emit_signal("purchase_failed", track_id)

func _on_cancel_pressed():
	print("❌ Cancel pressed")
	hide_popup()

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var elapsed = (Time.get_ticks_msec() / 1000.0) - popup_open_time
		if elapsed < 0.2:
			return
		hide_popup()

func _exit_tree():
	_stop_preview()
