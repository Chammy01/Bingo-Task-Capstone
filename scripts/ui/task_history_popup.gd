extends Control

signal popup_closed

# ============================================
# NODE REFERENCES
# ============================================

@onready var overlay: ColorRect = $ColorRect
@onready var background: Panel = $Background
@onready var date_label: Label = $Background/DateLabel
@onready var tasks_container: VBoxContainer = $Background/ScrollContainer/TasksContainer
@onready var close_button: TextureButton = $Background/CloseButton

# ============================================
# ANIMATION SETTINGS
# ============================================

const ANIMATION_DURATION = 0.3
const SCALE_START_FACTOR = 0.8

# ============================================
# MONTH NAMES
# ============================================

const MONTH_NAMES = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_setup_overlay()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	_play_entrance_animation()
	print("✓ TaskHistoryPopup opened")

func _setup_overlay():
	"""Configure the ColorRect for background tap detection"""
	if not overlay:
		return
	
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	move_child(overlay, 0)
	overlay.gui_input.connect(_on_overlay_clicked)

func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_close_pressed()

# ============================================
# PUBLIC API
# ============================================

func setup(date: Dictionary, history: Dictionary):
	"""Initialize the popup with date and history data"""
	# Set date header
	var month_name = MONTH_NAMES[date.month - 1]
	date_label.text = "%s %d, %d" % [month_name, date.day, date.year]
	
	# Clear existing tasks
	for child in tasks_container.get_children():
		child.queue_free()
	
	# Check if history exists
	if not history.has("tasks") or history.tasks.is_empty():
		_add_no_history_label()
		return
	
	# Display tasks with their tile indices
	var tasks: Array = history.tasks
	for i in range(tasks.size()):
		var task = tasks[i]
		if task is Dictionary and task.has("text"):
			var text: String = task.text
			if text != "" and text != "Tap to add task":
				var is_completed = task.get("completed", false)
				_add_task_item(i + 1, text, is_completed)
	
	# If no valid tasks were added, show "no history"
	if tasks_container.get_child_count() == 0:
		_add_no_history_label()

# ============================================
# TASK LIST BUILDING
# ============================================

func _add_task_item(tile_index: int, text: String, completed: bool):
	"""Add a task item to the scrollable list"""
	var task_row = HBoxContainer.new()
	task_row.custom_minimum_size = Vector2(0, 40)
	
	# Status icon
	var status_label = Label.new()
	status_label.text = "✅" if completed else "⬜"
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.custom_minimum_size = Vector2(30, 0)
	task_row.add_child(status_label)
	
	# Tile index label
	var index_label = Label.new()
	index_label.text = "Tile %d:" % tile_index
	index_label.add_theme_font_size_override("font_size", 14)
	index_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	index_label.custom_minimum_size = Vector2(50, 0)
	task_row.add_child(index_label)
	
	# Task text
	var text_label = Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_row.add_child(text_label)
	
	tasks_container.add_child(task_row)

func _add_no_history_label():
	"""Add a message when no history is available"""
	var label = Label.new()
	label.text = "No task history for this date"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tasks_container.add_child(label)

# ============================================
# ANIMATIONS
# ============================================

func _play_entrance_animation():
	if not background:
		return
	
	var start_scale = SCALE_START_FACTOR
	var end_scale = 1.0
	
	overlay.modulate.a = 0.0
	background.modulate.a = 0.0
	background.scale = Vector2(start_scale, start_scale)
	background.pivot_offset = background.size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(overlay, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(background, "modulate:a", 1.0, ANIMATION_DURATION)
	tween.tween_property(background, "scale", Vector2(end_scale, end_scale), ANIMATION_DURATION)

func _play_exit_animation():
	if not background:
		return
	
	var end_scale = SCALE_START_FACTOR
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(overlay, "modulate:a", 0.0, ANIMATION_DURATION * 0.8)
	tween.tween_property(background, "modulate:a", 0.0, ANIMATION_DURATION * 0.8)
	tween.tween_property(background, "scale", Vector2(end_scale, end_scale), ANIMATION_DURATION * 0.8)
	
	await tween.finished

# ============================================
# CLOSE HANDLER
# ============================================

func _on_close_pressed():
	print("📅 TaskHistoryPopup closing...")
	await _play_exit_animation()
	emit_signal("popup_closed")
	queue_free()
