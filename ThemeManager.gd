# ThemeManager.gd
extends Node

signal theme_changed(theme_id: String)

const THEME_SAVE_PATH = "user://theme_data.save"

# Preload ALL resources at compile time
const BG_DEFAULT = preload("res://Background/default.png")
const BG_GRASS = preload("res://Background/grass.png")
const BG_CLOUD = preload("res://Background/cloud.png")
const BG_SAKURA = preload("res://Background/sakura.png")
const BG_AUTUMN = preload("res://Background/autumn.png")
const BG_SNOWY = preload("res://Background/snowy.png")
const SPRITE_SHEET = preload("res://Background/woodenbtn.png")
var current_theme: String = "default"

# Background paths - using preloaded resources
var theme_backgrounds = {
	"default": BG_DEFAULT,
	"theme_valley": BG_GRASS,
	"theme_horizon": BG_CLOUD,
	"theme_blossom": BG_SAKURA,
	"theme_snowy": BG_SNOWY,
	"theme_autumn": BG_AUTUMN
}

# Decoration sprite sheet data - NOW USES PRELOADED RESOURCE INSTEAD OF STRING PATH
var theme_decoration_atlas = {
	"default": {
		"sprite_sheet": SPRITE_SHEET,  # Changed from string to preloaded resource
		"items": [
			{"name": "coffee", "region": Rect2(1395, 416, 82, 95), "scale": 1.38},
			{"name": "plant", "region": Rect2(1144, 568, 166, 197), "scale": 0.58},
			{"name": "ballpen", "region": Rect2(1011, 568, 65, 150), "scale": 1.43},
			{"name": "notebook", "region": Rect2(1313, 568, 144, 126), "scale": 1.465}
		]
	},
	"theme_valley": {
		"sprite_sheet": SPRITE_SHEET,  # Changed from string to preloaded resource
		"items": [
			{"name": "lush1", "region": Rect2(1467, 518, 46, 43), "scale": 2.445},
			{"name": "lush2", "region": Rect2(1515, 518, 56, 55), "scale": 2.065},
			{"name": "wildflower", "region": Rect2(1573, 518, 57, 35), "scale": 2.87},
			{"name": "butterfly", "region": Rect2(1631, 518, 64, 31), "scale": 1.485}
		]
	},
	"theme_horizon": {
		"sprite_sheet": SPRITE_SHEET,  # Changed from string to preloaded resource
		"items": [
			{"name": "feather", "region": Rect2(1539, 656, 43, 47), "scale": 2.445},
			{"name": "cloud", "region": Rect2(1465, 656, 66, 46), "scale": 2.71},
			{"name": "paper_plane", "region": Rect2(1589, 656, 48, 35), "scale": 2.92}
		]
	},
	"theme_blossom": {
		"sprite_sheet": SPRITE_SHEET,  # Changed from string to preloaded resource
		"items": [
			{"name": "tea", "region": Rect2(1467, 580, 49, 49), "scale": 2.445},
			{"name": "bamboo", "region": Rect2(1519, 580, 33, 60), "scale": 2.71},
			{"name": "sakura_branch1", "region": Rect2(1561, 580, 57, 19), "scale": 2.87},
			{"name": "sakura_branch2", "region": Rect2(1561, 604, 51, 45), "scale": 2.92}
		]
	},
	"theme_snowy": {
		"sprite_sheet": SPRITE_SHEET,
		"items": [
			{"name": "Cinnamon", "region": Rect2(0, 0, 64, 64), "scale": 1.0},
			{"name": "Gloves", "region": Rect2(64, 0, 64, 64), "scale": 1.0},
			{"name": "Berries", "region": Rect2(128, 0, 64, 64), "scale": 1.0}
		]
	},
	"theme_autumn": {
		"spirte_sheet": SPRITE_SHEET,
		"items": [
			{"name": "Aster", "region": Rect2(0, 0, 64, 64), "scale": 1.0},
			{"name": "Pine", "region": Rect2(64, 0, 64, 64), "scale": 1.0},
			{"name": "Acorn", "region": Rect2(128, 0, 64, 64), "scale": 1.0}
		]
	}
}

func _ready():
	load_theme()
	print("✓ ThemeManager initialized with theme: %s" % current_theme)

func set_theme(theme_id: String) -> void:
	"""Change the current theme"""
	if theme_backgrounds.has(theme_id):
		current_theme = theme_id
		save_theme()
		theme_changed.emit(theme_id)
		print("✓ Theme changed to: %s" % theme_id)
	else:
		print("⚠️ Theme not found: %s" % theme_id)

func get_current_background() -> Texture2D:
	"""Get the current background texture (already preloaded)"""
	return theme_backgrounds.get(current_theme, BG_DEFAULT)

func get_theme_name(theme_id: String) -> String:
	"""Get a display name for the theme"""
	var names = {
		"default": "Default",
		"theme_valley": "Grass Field",
		"theme_horizon": "Cloud Sky",
		"theme_blossom": "Cherry Blossom",
		"theme_autumn": "Autumn",
		"theme_snowy": "Snowy"
	}
	return names.get(theme_id, "Unknown")

func get_current_decorations() -> Dictionary:
	"""Get sprite sheet and items for current theme"""
	return theme_decoration_atlas.get(current_theme, theme_decoration_atlas["default"])

func get_decorations_for_theme(theme_id: String) -> Dictionary:
	"""Get sprite sheet and items for specified theme"""
	return theme_decoration_atlas.get(theme_id, {})

func save_theme() -> void:
	"""Save current theme to file"""
	var file = FileAccess.open(THEME_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"theme": current_theme})
		file.close()
		print("💾 Theme saved: %s" % current_theme)

func load_theme() -> void:
	"""Load saved theme from file"""
	if FileAccess.file_exists(THEME_SAVE_PATH):
		var file = FileAccess.open(THEME_SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			current_theme = data.get("theme", "default")
			file.close()
			print("📂 Theme loaded: %s" % current_theme)
