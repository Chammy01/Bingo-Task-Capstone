extends "res://scripts/scenes/base_scene.gd"

# ============================================
# NODE REFERENCES
# ============================================

@onready var postmail_board = $PostmailBoard
@onready var back_button = $BackButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound

@onready var stamps = [
	$PostmailBoard/StampsContainer/Stamp1,
	$PostmailBoard/StampsContainer/Stamp2,
	$PostmailBoard/StampsContainer/Stamp3,
	$PostmailBoard2/StampsContainer/Stamp4,
	$PostmailBoard2/StampsContainer/Stamp5,
	$PostmailBoard2/StampsContainer/Stamp6
]

# ============================================
# ATLAS CONFIGURATION
# ============================================

const ATLAS_PATH = "res://assets/backgrounds/woodenbtn.png"
const SETTINGS_POPUP = preload("res://scenes/SettingsPopup.tscn")

const STAMP_REGIONS = {
	"locked":  Rect2(206, 127, 100, 124),
	"starter": Rect2(310, 0.0, 100, 124),
	"badge2":  Rect2(0.0, 127, 100, 124),
	"badge3":  Rect2(103, 127, 100, 124),
	"badge4":  Rect2(103, 0.0, 100, 124),
	"badge5":  Rect2(0.0, 0.0, 100, 124),
	"badge6":  Rect2(206, 0.0, 100, 124)
}

const STAMP_IDS = [
	"starter",
	"badge2",
	"badge3",
	"badge4",
	"badge5",
	"badge6"
]

const BADGE_INFO = {
	"starter": {
		"name": "First Steps",
		"description": "Complete your first task! ",
		"hint": "Complete 1 task to unlock"
	},
	"badge2": {
		"name": "BINGO Expert",
		"description": "You're a BINGO master!",
		"hint": "Get 3 BINGOs to unlock"
	},
	"badge3": {
		"name": "First BINGO",
		"description": "Your first BINGO! ",
		"hint": "Complete any row or column to unlock"
	},
	"badge4": {
		"name": "Rich",
		"description": "You're loaded with coins!",
		"hint": "Earn 500 coins total to unlock"
	},
	"badge5": {
		"name": "Legend",
		"description": "Unlocked everything!",
		"hint": "Unlock all other 5 badges"
	},
	"badge6": {
		"name": "Grinder",
		"description": "Completed 20 tasks total! ",
		"hint": "Complete 20 tasks to unlock"
	}
}

# ============================================
# STATE
# ============================================

var unlocked_badges: Array = []
var first_time_opened: bool = true
var deco_nodes: Array = []

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	super._ready()
	print("\n🎮 StampsScene initialized")
	print("  BadgeManager badges: ", BadgeManager.unlocked_badges)
	
	# Setup decorations
	_auto_collect_decorations()
	_update_decorations()
	
	_setup_back_button()
	_setup_stamps()
	_make_stamps_clickable()
	_test_coordinates()
	
	print("Decorations found: %d" % deco_nodes.size())
	
	if first_time_opened:
		_play_bounce_for_unlocked()
		first_time_opened = false

# ============================================
# DECORATION SYSTEM
# ============================================

func _auto_collect_decorations():
	"""Find all Deco1-Deco21 nodes in the scene"""
	deco_nodes. clear()
	for i in range(1, 22):  # Deco1 to Deco21
		var node_name = "Deco%d" % i
		var node = get_node_or_null(node_name)
		if node:
			deco_nodes. append({"name": node_name, "node": node})
			print("✓ Found decoration: %s" % node_name)

func _update_decorations():
	"""Apply textures and control visibility based on current theme"""
	if deco_nodes.is_empty():
		return
	
	var all_decos = ThemeManager.get_all_decorations()
	var visible_nodes = ThemeManager.get_visible_decoration_nodes(ThemeManager.current_theme)
	var sprite_sheet = ThemeManager. get_sprite_sheet()
	
	# Setup textures and hide all decorations first
	for deco in deco_nodes:
		var node_name = deco["name"]
		var node = deco["node"]
		
		if all_decos.has(node_name):
			var data = all_decos[node_name]
			node.texture = sprite_sheet
			node.region_enabled = true
			node.region_rect = data["region"]
			node.scale = Vector2(data["scale"], data["scale"])
		
		node.visible = false  # Hide all by default
	
	# Show only decorations for current theme
	for deco in deco_nodes:
		if deco["name"] in visible_nodes:
			deco["node"].visible = true

func _on_theme_changed(_theme_id: String):
	super._on_theme_changed(_theme_id)  # Call base class (applies background)
	_update_decorations()  # Then update decorations
	print("🎨 Stamps decorations updated for theme: %s" % _theme_id)

# ============================================
# SETTINGS
# ============================================

func _on_settings_pressed() -> void:
	"""Settings button clicked - show popup"""
	button_sound.play()
	await get_tree().create_timer(0.2).timeout
	
	var popup = SETTINGS_POPUP.instantiate()
	get_tree().root.add_child(popup)
	
	popup.settings_closed.connect(_on_settings_closed)
	
	print("⚙️ Settings popup opened")

func _on_settings_closed():
	"""Settings popup closed"""
	_apply_audio_settings()
	print("⚙️ Settings closed")

func _apply_audio_settings():
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"), 
		0.0 if music_on else -80.0
	)
	AudioServer. set_bus_volume_db(
		AudioServer.get_bus_index("SFX"), 
		0.0 if sfx_on else -80.0
	)
	
	print("✓ Audio settings applied: Music=%s, SFX=%s" % [music_on, sfx_on])

func _setup_back_button():
	if not back_button.pressed. is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	print("✅ Back button connected")

func _setup_stamps():
	unlocked_badges.clear()
	print("\n📮 Setting up stamps from BadgeManager...")
	
	for i in stamps.size():
		var badge_id = STAMP_IDS[i]
		if BadgeManager.is_unlocked(badge_id):
			stamps[i].texture = _create_atlas_texture(badge_id)
			unlocked_badges.append(badge_id)
			print("  ✅ Stamp %d (%s) is UNLOCKED" % [i + 1, badge_id])
		else:
			stamps[i].texture = _create_atlas_texture("locked")
			print("  🔒 Stamp %d (%s) is LOCKED" % [i + 1, badge_id])
	
	print("\n✓ Stamps loaded: %d of 6 unlocked\n" % unlocked_badges.size())

func _make_stamps_clickable():
	for i in stamps.size():
		stamps[i].mouse_filter = Control. MOUSE_FILTER_STOP
		stamps[i].gui_input. connect(_on_stamp_input. bind(i))
	print("✅ Stamps are clickable")

func _test_coordinates():
	print("\n📐 Testing atlas coordinates...")
	var all_good = true
	
	if not STAMP_REGIONS. has("locked"):
		print("❌ ERROR: 'locked' region not found!")
		all_good = false
	
	for id in STAMP_IDS:
		if not STAMP_REGIONS.has(id):
			print("❌ ERROR: Badge ID '%s' not found!" % id)
			all_good = false
	
	if all_good:
		print("✅ All coordinates configured correctly!\n")
	else:
		print("❌ Fix the errors above!\n")

# ============================================
# BOUNCE ANIMATION ON FIRST OPEN
# ============================================

func _play_bounce_for_unlocked():
	for i in range(unlocked_badges.size()):
		var badge_id = unlocked_badges[i]
		var index = STAMP_IDS.find(badge_id)
		if index >= 0:
			var delay = i * 0.15
			_call_bounce_with_delay(index, delay)

func _call_bounce_with_delay(index: int, delay: float) -> void:
	# If delay is 0 or less, animate immediately without a timer
	if delay <= 0:
		_animate_unlock(index)
		return
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = delay
	timer.one_shot = true
	timer.start()
	timer. timeout.connect(
		func():
			_animate_unlock(index)
			timer.queue_free()
	)

# ============================================
# ATLAS HELPER
# ============================================

func _create_atlas_texture(stamp_name: String) -> AtlasTexture:
	"""Create an AtlasTexture from a defined region"""
	var atlas = AtlasTexture.new()
	atlas.atlas = load(ATLAS_PATH)
	atlas. region = STAMP_REGIONS[stamp_name]
	return atlas

# ============================================
# UNLOCKING STAMPS (DEBUG - Uses BadgeManager)
# ============================================

func unlock_stamp(index: int):
	"""Unlock a specific stamp via BadgeManager and update visuals"""
	if index < 0 or index >= stamps.size():
		print("⚠️ Invalid stamp index: %d" % index)
		return
	
	var badge_id = STAMP_IDS[index]
	
	print("\n🧪 DEBUG: Unlocking stamp %d (%s)" % [index + 1, badge_id])
	
	var was_unlocked = BadgeManager.unlock_badge(badge_id)
	
	if was_unlocked:
		stamps[index].texture = _create_atlas_texture(badge_id)
		if badge_id not in unlocked_badges:
			unlocked_badges.append(badge_id)
		
		_animate_unlock(index)
		print("  ✅ Stamp unlocked and saved!")
	else:
		print("  ℹ️ Already unlocked")

func _animate_unlock(index: int):
	"""Play bounce and fade animation when stamp unlocks"""
	var stamp = stamps[index]
	var original_scale = stamp.scale
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	tween.tween_property(stamp, "modulate:a", 0.0, 0.2)
	tween.tween_property(stamp, "modulate:a", 1.0, 0.2)
	tween.tween_property(stamp, "scale", original_scale * 1.2, 0.2)
	tween.tween_property(stamp, "scale", original_scale, 0.3)

# ============================================
# STAMP INTERACTION
# ============================================

func _on_stamp_input(event: InputEvent, index: int):
	"""Handle stamp clicks and touch inputs"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_stamp_clicked(index)
	elif event is InputEventScreenTouch and event. pressed:
		_on_stamp_clicked(index)

func _on_stamp_clicked(index: int):
	"""Handle stamp click to show detail or hint"""
	var badge_id = STAMP_IDS[index]
	
	if badge_id in unlocked_badges:
		_show_stamp_detail(index)
	else:
		_show_locked_hint(index)
	
	_animate_click(index)

func _animate_click(index: int):
	"""Small bounce animation on click"""
	var stamp = stamps[index]
	var original_scale = stamp.scale
	
	var tween = create_tween()
	tween.tween_property(stamp, "scale", original_scale * 1.05, 0.1)
	tween. tween_property(stamp, "scale", original_scale, 0.1)

func _show_stamp_detail(index: int):
	"""Display toast with stamp details for unlocked stamp"""
	var badge_id = STAMP_IDS[index]
	var info = BADGE_INFO[badge_id]
	
	var message = "📮 %s\n\n%s" % [info.name, info.description]
	
	if has_node("/root/Toast"):
		Toast.show_toast(message, 2.5)
	
	print("📮 Showing detail: %s" % info.name)

func _show_locked_hint(index: int):
	"""Display toast with unlock hint for locked stamp"""
	var badge_id = STAMP_IDS[index]
	var info = BADGE_INFO[badge_id]
	
	var message = "🔒 %s\n\n%s" % [info.name, info.hint]
	
	if has_node("/root/Toast"):
		Toast. show_toast(message, 2.0)
	
	print("🔒 %s is locked" % info.name)

# ============================================
# NAVIGATION
# ============================================

func _on_back_pressed():
	"""Return to main menu"""
	print("⬅️ Back button pressed")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ============================================
# DEBUG CONTROLS
# ============================================

func _input(event):
	"""Debug keyboard shortcuts for testing"""
	if event is InputEventKey and event.pressed:
		if event. keycode >= KEY_1 and event.keycode <= KEY_6:
			var index = event.keycode - KEY_1
			unlock_stamp(index)
		elif event. keycode == KEY_U:
			print("\n🎯 DEBUG: Unlocking all stamps...")
			for i in stamps.size():
				unlock_stamp(i)
		elif event.keycode == KEY_R:
			print("\n🔄 DEBUG: Resetting all stamps...")
			BadgeManager. unlocked_badges.clear()
			BadgeManager.save_badges()
			unlocked_badges.clear()
			for i in stamps.size():
				stamps[i]. texture = _create_atlas_texture("locked")
			print("✅ All stamps reset!")
		elif event.keycode == KEY_D:
			print("\n🔍 DEBUG INFO:")
			print("  BadgeManager badges: ", BadgeManager.unlocked_badges)
			print("  Local unlocked_badges: ", unlocked_badges)
			print("\nStamp by stamp:")
			for i in stamps.size():
				var badge_id = STAMP_IDS[i]
				var bm = BadgeManager.is_unlocked(badge_id)
				var local = badge_id in unlocked_badges
				print("  %d.  %s - BM:%s Local:%s" % [i+1, badge_id, bm, local])
