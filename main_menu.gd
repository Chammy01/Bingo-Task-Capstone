extends "res://base_scene.gd"

# ============================================
# NODE REFERENCES
# ============================================

@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var start_button: TextureButton = $START/START
@onready var settings_button: TextureButton = $Settings

# Auto-collected decoration nodes (Deco1, Deco2, Deco3, Deco4, etc.)
var deco_nodes: Array = []

# ============================================
# PRELOADS
# ============================================

const SETTINGS_POPUP = preload("res://SettingsPopup.tscn")
const BUTTON_SOUND_DURATION = 0.25

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	super._ready()  # Call base _ready() for background
	
	_auto_collect_decorations()
	
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	
	_apply_audio_settings()
	_update_decorations()
	
	if not ThemeManager.theme_changed.is_connected(_on_theme_changed_custom):
		ThemeManager.theme_changed.connect(_on_theme_changed_custom)
	
	print("✓ Main Menu initialized with %d decoration slots" % deco_nodes.size())

# ============================================
# DECORATION AUTO-DETECTION
# ============================================

func _auto_collect_decorations():
	deco_nodes.clear()
	# Collect all possible decoration nodes (Deco1-Deco21)
	for i in range(1, 22):
		var deco_name = "Deco%d" % i
		var deco = get_node_or_null(deco_name)
		if deco != null:
			deco_nodes.append({"name": deco_name, "node": deco})
	
	if deco_nodes.size() == 0:
		print("  ⚠️ No decoration nodes found (add Sprite2D nodes named 'Deco1', 'Deco2', etc.)")

# ============================================
# DECORATION MANAGEMENT
# ============================================

func _on_theme_changed_custom(_theme_id: String):
	print("\n🎨 Theme changed, updating decorations...")
	_update_decorations()

func _update_decorations():
	var all_decos = ThemeManager.get_all_decorations()
	var visible_nodes = ThemeManager.get_visible_decoration_nodes(ThemeManager.current_theme)
	var sprite_sheet = ThemeManager.get_sprite_sheet()
	
	if not sprite_sheet or not sprite_sheet is Texture2D:
		_hide_all_decorations()
		print("  ⚠️ Sprite sheet is not a valid Texture2D")
		return
	
	# Apply textures and visibility to all decoration nodes
	for deco_entry in deco_nodes:
		var deco_name = deco_entry["name"]
		var deco = deco_entry["node"]
		
		if not deco:
			continue
		
		# Check if this node should be visible for current theme
		if deco_name in visible_nodes and all_decos.has(deco_name):
			var item = all_decos[deco_name]
			
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = sprite_sheet
			atlas_texture.region = item.region
			
			deco.texture = atlas_texture
			deco.scale = Vector2(item.scale, item.scale)
			deco.visible = true
		else:
			deco.visible = false

func _hide_all_decorations():
	for deco_entry in deco_nodes:
		if deco_entry["node"]:
			deco_entry["node"].visible = false
	print("  ⚪ All decorations hidden")

# ============================================
# BUTTON HANDLERS
# ============================================

func _on_shop_pressed() -> void:
	button_sound.play()
	await get_tree().create_timer(BUTTON_SOUND_DURATION).timeout
	get_tree().change_scene_to_file("res://ShopScene.tscn")
	print("→ Loading shop scene")

func _on_badges_pressed() -> void:
	button_sound.play()
	await get_tree().create_timer(BUTTON_SOUND_DURATION).timeout
	get_tree().change_scene_to_file("res://StampsScene.tscn")
	print("→ Loading stamps scene")

func _on_start_pressed() -> void:
	button_sound.play()
	await get_tree().create_timer(BUTTON_SOUND_DURATION).timeout
	get_tree().change_scene_to_file("res://bingo_board.tscn")
	print("→ Loading bingo board")

func _on_settings_pressed() -> void:
	button_sound.play()
	await get_tree().create_timer(BUTTON_SOUND_DURATION).timeout
	var popup = SETTINGS_POPUP.instantiate()
	get_tree().root.add_child(popup)
	popup.settings_closed.connect(_on_settings_closed)
	print("⚙️ Settings popup opened")

func _on_settings_closed():
	_apply_audio_settings()
	print("⚙️ Settings closed")

# ============================================
# AUDIO SETTINGS
# ============================================

func _apply_audio_settings():
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		print("⚠️ 'Music' bus not found in AudioServer, using Master bus")
		music_bus_index = AudioServer.get_bus_index("Master")
	
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index == -1:
		print("⚠️ 'SFX' bus not found in AudioServer, using Master bus")
		sfx_bus_index = AudioServer.get_bus_index("Master")
	
	if music_bus_index != -1:
		AudioServer.set_bus_volume_db(music_bus_index, 0.0 if music_on else -80.0)
	if sfx_bus_index != -1:
		AudioServer.set_bus_volume_db(sfx_bus_index, 0.0 if sfx_on else -80.0)
	
	print("✓ Audio settings applied: Music=%s, SFX=%s" % [music_on, sfx_on])
	
	# ======================
	# NOTIFICATIONS
	# ======================
	
	# Call this when your app starts (e.g., in _ready of main_menu.gd)
func _request_notification_permissions():
	if OS.get_name() == "Android":
		# Check if we're on Android 13+ (API 33)
		var os_version = OS.get_version()
		print("Android version: %s" % os_version)
		
		# Request POST_NOTIFICATIONS permission (Android 13+)
		if Engine.has_singleton("NotificationScheduler"):
			var scheduler = Engine.get_singleton("NotificationScheduler")
			
			# The plugin should handle permission requests
			# Check plugin documentation for exact method name
			if scheduler.has_method("request_permission"):
				scheduler.request_permission()
				print("📱 Requested notification permission")
