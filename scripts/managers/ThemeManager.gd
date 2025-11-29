# ThemeManager.gd
extends Node

signal theme_changed(theme_id: String)

const THEME_SAVE_PATH = "user://theme_data.save"

# Preload ALL resources at compile time
const BG_DEFAULT = preload("res://assets/backgrounds/default.png")
const BG_GRASS = preload("res://assets/backgrounds/grass.png")
const BG_CLOUD = preload("res://assets/backgrounds/cloud.png")
const BG_SAKURA = preload("res://assets/backgrounds/sakura.png")
const BG_AUTUMN = preload("res://assets/backgrounds/autumn.png")
const BG_SNOWY = preload("res://assets/backgrounds/snowy.png")
const SPRITE_SHEET = preload("res://assets/backgrounds/woodenbtn.png")
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

# Master decoration registry - each decoration has a permanent node assignment
# This allows themes to share decorations and maintain consistent positions
var all_decorations = {
	"Deco1":  {"name": "coffee", "region": Rect2(1395, 416, 82, 95),   "scale": 1.323},
	"Deco2":  {"name": "plant", "region": Rect2(1144, 568, 166, 197), "scale": 0.825},
	"Deco3":  {"name": "ballpen", "region": Rect2(1011, 568, 65, 150),  "scale": 1.592},
	"Deco4":  {"name": "notebook", "region": Rect2(1313, 568, 144, 126), "scale": 1.349},
	"Deco5":  {"name": "lush1", "region": Rect2(1467, 518, 46, 43),   "scale": 2.5},
	"Deco6":  {"name": "lush2", "region": Rect2(1515, 518, 56, 55),   "scale": 2.216},
	"Deco7":  {"name": "wildflower", "region": Rect2(1573, 518, 57, 35),   "scale": 2.32},
	"Deco8":  {"name": "butterfly", "region": Rect2(1631, 518, 64, 31),   "scale": 0.922},
	"Deco9":  {"name": "feather", "region": Rect2(1539, 656, 43, 47),   "scale": 2.453},
	"Deco10": {"name": "cloud", "region": Rect2(1465, 656, 66, 46),   "scale": 2.283},
	"Deco11": {"name": "paper_plane", "region": Rect2(1589, 656, 48, 35),   "scale": 3.864},
	"Deco12": {"name": "tea", "region": Rect2(1467, 580, 49, 49),   "scale": 3.056},
	"Deco13": {"name": "bamboo", "region": Rect2(1519, 580, 33, 60),   "scale": 2.532},
	"Deco14": {"name": "sakura_branch1", "region": Rect2(1561, 580, 57, 19),   "scale": 2.711},
	"Deco15": {"name": "sakura_branch2", "region": Rect2(1561, 604, 51, 45),   "scale": 3.414},
	"Deco16": {"name": "Cinnamon", "region": Rect2(1312, 775, 112, 138), "scale": 1.165},
	"Deco17": {"name": "Gloves", "region": Rect2(1519, 816, 71, 72),   "scale": 1.713},
	"Deco18": {"name": "Berries", "region": Rect2(1444, 816, 55, 49),   "scale": 1.913},
	"Deco19": {"name": "Aster", "region": Rect2(1621, 729, 67, 66),   "scale": 1.682},
	"Deco20": {"name": "Pine", "region": Rect2(1520, 717, 83, 81),   "scale": 1.773},
	"Deco21": {"name": "Acorn", "region": Rect2(1448, 718, 60, 70),   "scale": 1.6}
}

# Theme visibility configuration - which decoration nodes are visible for each theme
var theme_visible_decorations = {
	"default": ["Deco1", "Deco2", "Deco3", "Deco4"],
	"theme_valley": ["Deco5", "Deco6", "Deco7", "Deco8"],
	"theme_horizon": ["Deco9", "Deco10", "Deco11"],
	"theme_blossom": ["Deco12", "Deco13", "Deco14", "Deco15"],
	"theme_snowy": ["Deco16", "Deco17", "Deco18"],
	"theme_autumn": ["Deco19", "Deco20", "Deco21"]
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

func get_all_decorations() -> Dictionary:
	"""Returns the master decoration registry with all decorations"""
	return all_decorations

func get_visible_decoration_nodes(theme_id: String) -> Array:
	"""Returns array of node names to show for a theme"""
	return theme_visible_decorations.get(theme_id, theme_visible_decorations.get("default", []))

func get_sprite_sheet() -> Texture2D:
	"""Get the sprite sheet resource"""
	return SPRITE_SHEET

func get_current_decorations() -> Dictionary:
	"""Get decoration data for current theme (backward compatible)
	Returns dictionary with 'sprite_sheet', 'items', and 'visible_nodes'"""
	var visible_nodes = get_visible_decoration_nodes(current_theme)
	var items = []
	for node_name in visible_nodes:
		if all_decorations.has(node_name):
			var deco_data = all_decorations[node_name].duplicate()
			deco_data["deco_node"] = node_name
			items.append(deco_data)
	return {
		"sprite_sheet": SPRITE_SHEET,
		"items": items,
		"visible_nodes": visible_nodes
	}

func get_decorations_for_theme(theme_id: String) -> Dictionary:
	"""Get decoration data for specified theme"""
	var visible_nodes = get_visible_decoration_nodes(theme_id)
	var items = []
	for node_name in visible_nodes:
		if all_decorations.has(node_name):
			var deco_data = all_decorations[node_name].duplicate()
			deco_data["deco_node"] = node_name
			items.append(deco_data)
	return {
		"sprite_sheet": SPRITE_SHEET,
		"items": items,
		"visible_nodes": visible_nodes
	}

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
