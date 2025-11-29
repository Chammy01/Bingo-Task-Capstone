# base_scene.gd
# Base script for all scenes with background support
extends Control

@onready var background: TextureRect = $Background

# Preload all background textures for reliable loading on all platforms including mobile
const BG_DEFAULT = preload("res://assets/backgrounds/default.png")
const BG_GRASS = preload("res://assets/backgrounds/grass.png")
const BG_CLOUD = preload("res://assets/backgrounds/cloud.png")
const BG_SAKURA = preload("res://assets/backgrounds/sakura.png")

func _ready():
	_apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)

func _apply_theme():
	"""Apply the current theme background texture"""
	if not background:
		print("⚠️ Background node not found in the scene")
		return
	
	# Get preloaded texture from ThemeManager
	var texture = ThemeManager.get_current_background()
	
	if texture:
		background.texture = texture
		print("✓ Background applied successfully")
	else:
		print("⚠️ No texture available for current theme")

func _on_theme_changed(_theme_id: String):
	"""Called when the theme changes"""
	_apply_theme()
