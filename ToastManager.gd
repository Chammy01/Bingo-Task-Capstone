# Filename: ToastManager.gd
# Global toast notification system
extends Node

# ============================================
# CUSTOMIZABLE SETTINGS
# ============================================

var default_duration: float = 1.5
var toast_position_offset: float = 150  # Distance from bottom
var toast_width: float = 240
var toast_height: float = 60
var toast_font_size: int = 11
var default_font_size: int = 22 

# Preset sizes for consistency
var FONT_SIZE_SMALL: int = 16
var FONT_SIZE_NORMAL: int = 22
var FONT_SIZE_LARGE: int = 28

# ============================================
# MAIN TOAST FUNCTION
# ============================================

func show_toast(message: String, duration: float = -1, font_size: int = -1) -> void:
	if duration < 0:
		duration = default_duration
	if font_size < 0:
		font_size = default_font_size
	
	var toast_label = Label.new()
	toast_label.text = message
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	toast_label.add_theme_font_size_override("font_size", font_size)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Create background panel
	var panel = Panel.new()
	panel.add_child(toast_label)
	
	# Style the panel background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark semi-transparent
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 20
	style_box.content_margin_right = 20
	style_box.content_margin_top = 14
	style_box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Position at bottom center of screen
	var screen_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(screen_size.x - toast_width) / 2,
		screen_size.y - toast_position_offset
	)
	panel.custom_minimum_size = Vector2(toast_width, toast_height)
	
	# Make sure label fills the panel
	toast_label.size = Vector2(toast_width, toast_height)
	toast_label.position = Vector2.ZERO
	
	# Add to root (visible everywhere)
	get_tree().root.add_child(panel)
	
	# Animate the toast
	_animate_toast(panel, duration)
	
	print("🔔 Toast shown: %s" % message)

# ============================================
# ANIMATION FUNCTIONS
# ============================================

func _animate_toast(panel: Panel, duration: float) -> void:
	# Start invisible
	panel.modulate.a = 0.0
	
	# Create animation sequence
	var tween = create_tween()
	
	# Phase 1: Fade in (0.2s)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	# Phase 2: Stay visible (duration)
	tween.tween_interval(duration)
	
	# Phase 3: Fade out + float up (0.3s)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(panel, "position:y", panel.position.y - 30, 0.3)
	
	# Clean up after animation
	await tween.finished
	panel.queue_free()

# ============================================
# PRESET TOAST TYPES
# ============================================

func show_warning(message: String) -> void:
	show_toast("⚠️ " + message, -1, FONT_SIZE_NORMAL)

func show_error(message: String) -> void:
	show_toast("❌ " + message, -1, FONT_SIZE_NORMAL)

func show_success(message: String) -> void:
	show_toast("✓ " + message, -1, FONT_SIZE_NORMAL)

func show_info(message: String) -> void:
	show_toast("ℹ️ " + message, -1, FONT_SIZE_NORMAL)

# ============================================
# CUSTOM STYLED TOASTS
# ============================================

func show_custom_toast(message: String, bg_color: Color, duration: float = -1) -> void:
	"""Show a toast with custom background color"""
	if duration < 0:
		duration = default_duration
	
	var toast_label = Label.new()
	toast_label.text = message
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	
	var panel = Panel.new()
	panel.add_child(toast_label)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 20
	style_box.content_margin_right = 20
	style_box.content_margin_top = 14
	style_box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style_box)
	
	var screen_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(screen_size.x - toast_width) / 2,
		screen_size.y - toast_position_offset
	)
	panel.custom_minimum_size = Vector2(toast_width, toast_height)
	
	toast_label.size = Vector2(toast_width, toast_height)
	toast_label.position = Vector2.ZERO
	
	get_tree().root.add_child(panel)
	_animate_toast(panel, duration)
	
	print("🔔 Custom toast shown: %s" % message)

# ============================================
# TIER-SPECIFIC TOASTS (Optional)
# ============================================

func show_tier_unlock(tier: int) -> void:
	"""Show notification when user reaches a new reward tier"""
	match tier:
		1:
			show_custom_toast("🎉 Tier 1 Unlocked! +10 coins per task", Color("#A78BFA"), 2.0)
		2:
			show_custom_toast("🎉 Tier 2 Unlocked! +15 coins per task", Color("#FCD34D"), 2.0)
		3:
			show_custom_toast("🎉 Tier 3 Unlocked! +20 coins per task", Color("#34D399"), 2.0)
