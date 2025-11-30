extends TextureButton

signal edit_requested(tile)
signal tile_changed(tile)
signal request_complete(tile)  # ← For BoardManager to handle session/coin check

@onready var task_label: Label = $TaskLabel
@onready var x_mark: AnimatedSprite2D = $Xmark
@onready var double_tap_timer: Timer = $Timer
@onready var edit_sound: AudioStreamPlayer = $EditSound
@onready var complete_sound: AudioStreamPlayer = $CompleteSound
@onready var uncomplete_sound: AudioStreamPlayer = $UncompleteSound

var tap_count: int = 0
var is_completed: bool = false
const DOUBLE_TAP_DELAY: float = 0.3

var sticky_textures: Array[Texture2D] = []
var current_texture_index: int = 0
var tile_index: int = 0

var is_loading: bool = false
var coins_earned_for_this_task: bool = false
var completed_at_elapsed: float = -1.0

var is_sprite_initialized: bool = false

# ============================================
# DATA FUNCTIONS
# ============================================

func get_current_texture() -> Texture2D:
	return self.texture_normal

func get_tile_data() -> Dictionary:
	return {
		"text": task_label.text,
		"completed": is_completed,
		"color_index": current_texture_index,
		"coins_earned": coins_earned_for_this_task,
		"completed_at_elapsed": completed_at_elapsed
	}

func set_tile_data(data: Dictionary) -> void:
	is_loading = true
	if data.has("text"):
		set_task_text(data.text)
	if data.has("completed"):
		is_completed = data.completed
		_update_x_mark()
	if data.has("color_index"):
		set_sticky_color(data.color_index)
	if data.has("coins_earned"):
		coins_earned_for_this_task = data.coins_earned
	if data.has("completed_at_elapsed"):
		completed_at_elapsed = data.completed_at_elapsed
	is_loading = false
	is_sprite_initialized = true

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	toggle_mode = false
	x_mark.hide()
	double_tap_timer.one_shot = true
	double_tap_timer.wait_time = DOUBLE_TAP_DELAY
	double_tap_timer.timeout.connect(_on_double_tap_timer_timeout)
	self.pressed.connect(_on_button_pressed)
	_load_sticky_textures()

func _load_sticky_textures() -> void:
	sticky_textures = [
		load("res://assets/backgrounds/green_sticky.png"),
		load("res://assets/backgrounds/pink_sticky.png"),
		load("res://assets/backgrounds/yellow_sticky.png"),
	]

func set_sticky_color(color_index: int) -> void:
	if color_index >= 0 and color_index < sticky_textures.size():
		current_texture_index = color_index
		self.texture_normal = sticky_textures[color_index]

func set_random_sticky_color() -> void:
	var random_index = randi() % sticky_textures.size()
	set_sticky_color(random_index)

# ============================================
# INPUT HANDLING
# ============================================

func _on_button_pressed() -> void:
	tap_count += 1
	if tap_count == 1:
		double_tap_timer.start()
	elif tap_count == 2:
		double_tap_timer.stop()
		_on_double_tap()

# ============================================
# DOUBLE TAP HANDLING (Session-based completion)
# ============================================

func _on_double_tap_timer_timeout() -> void:
	if tap_count == 1:
		if not task_label.text.is_empty() and not is_loading:
			# Ask BoardManager if tile can be completed (session/coin check)
			emit_signal("request_complete", self)
	tap_count = 0

func _on_double_tap() -> void:
	# Edit open always works
	edit_sound.play()
	emit_signal("edit_requested", self)
	tap_count = 0

# ============================================
# BOARDMANAGER CALLS THIS IF COMPLETION SUCCESSFUL
# ============================================

func mark_as_completed():
	if not is_completed:
		is_completed = true
		coins_earned_for_this_task = true
		_update_x_mark()

# Optional: For visual uncompletion
func unmark_completed():
	if is_completed:
		is_completed = false
		coins_earned_for_this_task = false
		_update_x_mark()

# ============================================
# CHECKMARK ANIMATION
# ============================================

func _update_x_mark() -> void:
	if is_completed:
		x_mark.show()
		x_mark.frame = 0
		if is_sprite_initialized:
			await get_tree().process_frame
		x_mark.play("check")
		if not is_loading:
			complete_sound.play()
	else:
		x_mark.stop()
		x_mark.frame = 0
		x_mark.hide()
		if not is_loading:
			uncomplete_sound.play()
	emit_signal("tile_changed", self)

func set_task_text(new_text: String) -> void:
	task_label.text = new_text
	if new_text.is_empty():
		is_completed = false
		coins_earned_for_this_task = false
		completed_at_elapsed = -1.0
		x_mark.hide()

# ============================================
# BONUS CALCULATION HELPER FUNCTIONS (OPTIONAL)
# ============================================

func _check_row_complete() -> bool:
	var grid_container = get_node("../../GridContainer")
	if grid_container == null:
		return false
	var tiles = grid_container.get_children()
	if tiles.is_empty():
		return false
	var my_index = get_index()
	@warning_ignore("integer_division")
	var my_row = my_index / 3
	var completed_count = 0
	for i in range(3):
		var row_tile_index = my_row * 3 + i
		if row_tile_index >= tiles.size():
			return false
		var tile = tiles[row_tile_index]
		if tile.is_completed:
			completed_count += 1
	return completed_count == 3

func _check_column_complete() -> bool:
	var grid_container = get_node("../../GridContainer")
	if grid_container == null:
		return false
	var tiles = grid_container.get_children()
	if tiles.is_empty():
		return false
	var my_index = get_index()
	var my_col = my_index % 3
	var completed_count = 0
	for i in range(3):
		var col_tile_index = my_col + (i * 3)
		if col_tile_index >= tiles.size():
			return false
		var tile = tiles[col_tile_index]
		if tile.is_completed:
			completed_count += 1
	return completed_count == 3
