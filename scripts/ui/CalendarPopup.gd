extends Control

signal date_selected(date: Dictionary)
signal past_date_selected(date: Dictionary, history: Dictionary)
signal popup_closed

# ============================================
# NODE REFERENCES
# ============================================

@onready var overlay: ColorRect = $ColorRect
@onready var background: TextureRect = $Background
@onready var month_label: Label = $Background/MonthLabel
@onready var days_grid: GridContainer = $Background/DaysGrid
@onready var prev_button: TextureButton = $Background/PrevButton
@onready var next_button: TextureButton = $Background/NextButton
@onready var exit_button: TextureButton = $Background/ExitButton

# ============================================
# VARIABLES
# ============================================

var current_month: int = 0
var current_year: int = 0
var scheduled_tasks: Dictionary = {}
var task_history_summary: Dictionary = {}

# Animation settings
const ANIMATION_DURATION = 0.3
const SCALE_START_FACTOR = 0.8
const FADE_START = 0.0
const BASE_SCALE = 1.0  # Background no longer scaled
const BACKGROUND_POSITION = Vector2(6.0, 130.0)

# ============================================
# SPRITE SHEET & ATLAS REGIONS
# ============================================

const CALENDAR_SHEET = preload("res://assets/backgrounds/calendar.png")
const GRID_SCALE = 0.4  # Updated from 0.245
const GRID_SIZE = Vector2(710, 752.645)

const DAY_REGIONS = {
	# Row 0
	1:  Rect2(0,   0,   115, 121),
	2:  Rect2(118,  0,   115, 121),
	3:  Rect2(238, 0,   115, 121),
	4:  Rect2(356, 0,   115, 121),
	5:  Rect2(475, 0,   115, 121),
	6:  Rect2(595, 0,   115, 121),
	
	# Row 1
	7:  Rect2(715, 0,  115, 121),
	8:  Rect2(0,  130,  115, 121),
	9:  Rect2(118, 130,  115, 121),
	10: Rect2(238, 130,  115, 121),
	11: Rect2(356, 130,  115, 121),
	12: Rect2(475, 130,  115, 121),
	
	# Row 2
	13: Rect2(595,   130, 115, 121),
	14: Rect2(715,  130, 115, 121),
	15: Rect2(0, 258, 115, 121),
	16: Rect2(118, 258, 115, 121),
	17: Rect2(238, 258, 115, 121),
	18: Rect2(356, 258, 115, 121),
	
	# Row 3
	19: Rect2(475,   258, 115, 121),
	20: Rect2(595,  258, 115, 121),
	21: Rect2(715, 258, 115, 121),
	22: Rect2(0, 388, 115, 121),
	23: Rect2(118, 388, 115, 121),
	24: Rect2(238, 388, 115, 121),
	
	# Row 4
	25: Rect2(356,   388, 115, 121),
	26: Rect2(475,  388, 115, 121),
	27: Rect2(595, 388, 115, 121),
	28: Rect2(715, 388, 115, 121),
	29: Rect2(0, 519, 115, 121),
	30: Rect2(118, 519, 115, 121),
	
	# Row 5
	31: Rect2(0, 643, 115, 121)
}

const MONTH_NAMES = [
	"JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
	"JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
]

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	var time = Time.get_datetime_dict_from_system()
	current_month = time.month
	current_year = time.year
	
	# Setup overlay
	_setup_overlay()
	
	# Apply custom size and scale to days grid
	days_grid.custom_minimum_size = GRID_SIZE
	days_grid.size = GRID_SIZE
	days_grid.scale = Vector2(GRID_SCALE, GRID_SCALE)
	
	# Configure grid
	days_grid.columns = 6
	days_grid.add_theme_constant_override("h_separation", 8)
	days_grid.add_theme_constant_override("v_separation", 8)
	
	# Connect navigation buttons
	prev_button.pressed.connect(_on_prev_month)
	next_button.pressed.connect(_on_next_month)
	
	# Connect exit button
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# Build calendar
	_build_calendar()
	
	# Play entrance animation
	_play_entrance_animation()
	
	print("✓ Calendar popup opened with animation")

# ============================================
# OVERLAY SETUP
# ============================================

func _setup_overlay():
	"""Configure the ColorRect for background tap detection"""
	if not overlay:
		print("⚠️ ColorRect node not found!")
		return
	
	# Make fullscreen
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	
	# Set color
	overlay.color = Color(0, 0, 0, 0.5)
	
	# Enable mouse input
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Move to back
	move_child(overlay, 0)
	
	# Connect click event
	overlay.gui_input.connect(_on_overlay_clicked)
	
	print("✓ Overlay configured and clickable")

func _on_overlay_clicked(event: InputEvent):
	"""Handle clicks on the overlay"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("📅 Background tapped - closing popup")
			_on_exit_pressed()

# ============================================
# ANIMATIONS
# ============================================

func _play_entrance_animation():
	"""Smooth fade-in and scale-up animation"""
	
	# Calculate scales (now 1.0 base instead of 1.74)
	var start_scale = BASE_SCALE * SCALE_START_FACTOR  # 0.8
	var end_scale = BASE_SCALE  # 1.0
	
	# Set initial states
	overlay.modulate.a = FADE_START
	background.modulate.a = FADE_START
	background.scale = Vector2(start_scale, start_scale)
	background.position = BACKGROUND_POSITION  # Ensure correct position
	background.pivot_offset = background.size / 2  # Scale from center
	
	# Create tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate overlay fade-in
	tween.tween_property(overlay, "modulate:a", 1.0, ANIMATION_DURATION)
	
	# Animate background fade-in
	tween.tween_property(background, "modulate:a", 1.0, ANIMATION_DURATION)
	
	# Animate background scale
	tween.tween_property(background, "scale", Vector2(end_scale, end_scale), ANIMATION_DURATION)
	
	print("▶️ Entrance animation: scale %.2f → %.2f at position (%.1f, %.1f)" % [start_scale, end_scale, BACKGROUND_POSITION.x, BACKGROUND_POSITION.y])

func _play_exit_animation():
	"""Smooth fade-out and scale-down animation before closing"""
	
	# Calculate scales
	@warning_ignore("unused_variable")
	var start_scale = BASE_SCALE  # 1.0
	var end_scale = BASE_SCALE * SCALE_START_FACTOR  # 0.8
	
	# Create tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate overlay fade-out
	tween.tween_property(overlay, "modulate:a", 0.0, ANIMATION_DURATION * 0.8)
	
	# Animate background fade-out
	tween.tween_property(background, "modulate:a", 0.0, ANIMATION_DURATION * 0.8)
	
	# Animate background scale-down
	tween.tween_property(background, "scale", Vector2(end_scale, end_scale), ANIMATION_DURATION * 0.8)
	
	# Wait for animation to finish
	await tween.finished
	
	print("⏹️ Exit animation complete")

# ============================================
# CALENDAR BUILDING
# ============================================

func _build_calendar():
	# Clear existing buttons
	for child in days_grid.get_children():
		child.queue_free()
	
	# Update month label with year
	month_label.text = "%s %d" % [MONTH_NAMES[current_month - 1], current_year]
	
	# Get calendar info
	var days_in_month = _get_days_in_month(current_month, current_year)
	var first_day_offset = _get_first_day_offset(current_month, current_year)
	
	# Add day headers
	var day_headers = ["S", "M", "T", "W", "T", "F"]
	for header in day_headers:
		var label = Label.new()
		label.text = header
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(115, 30)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
		days_grid.add_child(label)
	
	# Add empty spaces before first day
	for i in range(first_day_offset):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(115, 121)
		days_grid.add_child(spacer)
	
	# Add day buttons
	var today = Time.get_datetime_dict_from_system()
	for day in range(1, days_in_month + 1):
		var day_button = _create_day_button(day, today)
		days_grid.add_child(day_button)
	
	print("📅 %s %d (%d days)" % [MONTH_NAMES[current_month - 1], current_year, days_in_month])

# ============================================
# DAY BUTTON CREATION
# ============================================

func _create_day_button(day: int, today: Dictionary) -> TextureButton:
	var day_button = TextureButton.new()
	day_button.custom_minimum_size = Vector2(115, 121)
	
	# Create AtlasTexture from sprite sheet
	var atlas = AtlasTexture.new()
	atlas.atlas = CALENDAR_SHEET
	atlas.region = DAY_REGIONS[day]
	
	day_button.texture_normal = atlas
	day_button.ignore_texture_size = true
	day_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	# Add task indicator if scheduled (for future dates)
	var date_string = _get_date_string(day, current_month, current_year)
	if scheduled_tasks.has(date_string) and scheduled_tasks[date_string] > 0:
		_add_task_indicator(day_button, scheduled_tasks[date_string])
	
	# Highlight today
	if _is_today(day, current_month, current_year, today):
		day_button.modulate = Color(1.0, 0.95, 0.7)
	
	# Handle past dates - make clickable for history view
	if _is_past_date(day, current_month, current_year, today):
		# Keep clickable but style differently (slightly faded, not grey)
		day_button.disabled = false
		day_button.modulate = Color(0.9, 0.9, 0.95)  # Subtle blue tint for past
		
		# Check if we have history for this date
		if task_history_summary.has(date_string):
			var summary = task_history_summary[date_string]
			_add_history_indicator(day_button, summary.completed, summary.total)
		
		# Connect to history view
		day_button.pressed.connect(func(): _on_past_date_selected(day))
	else:
		# Future date - keep existing scheduling behavior
		day_button.pressed.connect(func(): _on_day_selected(day))
	
	return day_button

# ============================================
# TASK INDICATOR
# ============================================

func _add_task_indicator(day_button: TextureButton, task_count: int):
	# Orange dot indicator
	var indicator = ColorRect.new()
	indicator.custom_minimum_size = Vector2(20, 20)
	indicator.color = Color(1.0, 0.5, 0.2)
	indicator.position = Vector2(95, 5)
	day_button.add_child(indicator)
	
	# Count badge if multiple tasks
	if task_count > 1:
		var badge = Label.new()
		badge.text = str(task_count)
		badge.add_theme_font_size_override("font_size", 24)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.position = Vector2(88, 0)
		day_button.add_child(badge)

func _add_history_indicator(day_button: TextureButton, completed: int, total: int):
	"""Add completion indicator for past dates with history"""
	var indicator = Label.new()
	indicator.text = "%d/%d" % [completed, total]
	indicator.add_theme_font_size_override("font_size", 18)
	
	# Color based on completion
	if completed == total and total > 0:
		indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green for complete
	elif completed > 0:
		indicator.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))  # Orange for partial
	else:
		indicator.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))  # Red for none
	
	indicator.position = Vector2(5, 90)
	day_button.add_child(indicator)

# ============================================
# SIGNAL HANDLERS
# ============================================

func _create_date_dict(day: int) -> Dictionary:
	"""Helper to create date dictionary"""
	return {
		"day": day,
		"month": current_month,
		"year": current_year
	}

func _on_day_selected(day: int):
	var selected_date = _create_date_dict(day)
	print("📅 Date selected: %s/%s/%s" % [current_month, day, current_year])
	emit_signal("date_selected", selected_date)
	await _close_popup()

func _on_past_date_selected(day: int):
	var selected_date = _create_date_dict(day)
	var date_string = _get_date_string(day, current_month, current_year)
	var history = SaveManager.get_task_history_for_date(date_string)
	
	print("📜 Past date selected: %s" % date_string)
	emit_signal("past_date_selected", selected_date, history)
	await _close_popup()

func _on_prev_month():
	current_month -= 1
	if current_month < 1:
		current_month = 12
		current_year -= 1
	_build_calendar()

func _on_next_month():
	current_month += 1
	if current_month > 12:
		current_month = 1
		current_year += 1
	_build_calendar()

func _on_exit_pressed():
	print("📅 Calendar popup closing...")
	await _close_popup()

func _close_popup():
	"""Animate out and close"""
	await _play_exit_animation()
	emit_signal("popup_closed")
	queue_free()

# ============================================
# DATE HELPER FUNCTIONS
# ============================================

func _get_date_string(day: int, month: int, year: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]

func _get_days_in_month(month: int, year: int) -> int:
	var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and _is_leap_year(year):
		return 29
	return days[month - 1]

func _is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

func _get_first_day_offset(month: int, year: int) -> int:
	# Zeller's Congruence algorithm
	var q = 1
	var m = month
	var y = year
	
	if m < 3:
		m += 12
		y -= 1
	
	var k = y % 100
	@warning_ignore("integer_division")
	var j = int(y / 100)
	var h = (q + int((13 * (m + 1)) / 5.0) + k + int(k / 4.0) + int(j / 4.0) - (2 * j)) % 7
	var day_of_week = (h + 6) % 7
	
	return day_of_week % 6

func _is_today(day: int, month: int, year: int, today: Dictionary) -> bool:
	return day == today.day and month == today.month and year == today.year

func _is_past_date(day: int, month: int, year: int, today: Dictionary) -> bool:
	if year < today.year:
		return true
	if year == today.year and month < today.month:
		return true
	if year == today.year and month == today.month and day < today.day:
		return true
	return false
