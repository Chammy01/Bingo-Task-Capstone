# scripts/ui/task_history_popup.gd
extends Control

signal popup_closed

@onready var overlay: ColorRect = $ColorRect
@onready var background: Panel = $Background
@onready var date_label: Label = $Background/DateLabel
@onready var tasks_container: VBoxContainer = $Background/ScrollContainer/TasksContainer
@onready var close_button: Button = $Background/CloseButton

const MONTH_NAMES = ["January", "February", "March", "April", "May", "June",
					"July", "August", "September", "October", "November", "December"]

# Animation settings
const ANIMATION_DURATION = 0.3
const SCALE_START_FACTOR = 0.8
const FADE_START = 0.0

func _ready():
	_setup_overlay()
	close_button.pressed.connect(_on_close_pressed)
	_play_entrance_animation()

func _setup_overlay():
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_clicked)

func setup(date: Dictionary, history: Dictionary):
	"""Initialize the popup with date and task history"""
	date_label.text = "%s %d, %d" % [MONTH_NAMES[date.month - 1], date.day, date.year]
	
	# Clear existing tasks
	for child in tasks_container.get_children():
		child.queue_free()
	
	if history.is_empty() or not history.has("tasks"):
		_add_no_history_label()
		return
	
	var tasks = history.tasks
	for task in tasks:
		if task.text != "" and task.text != "Tap to add task":
			_add_task_item(task.text, task.get("completed", false))

func _add_task_item(task_text: String, is_completed: bool):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	# Status icon
	var status = Label.new()
	status.text = "✅" if is_completed else "⬜"
	status.add_theme_font_size_override("font_size", 24)
	hbox.add_child(status)
	
	# Task text
	var label = Label.new()
	label.text = task_text
	label.add_theme_font_size_override("font_size", 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 250
	
	if is_completed:
		label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	
	hbox.add_child(label)
	tasks_container.add_child(hbox)

func _add_no_history_label():
	var label = Label.new()
	label.text = "No tasks recorded for this date"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tasks_container.add_child(label)

func _play_entrance_animation():
	"""Smooth fade-in and scale-up animation"""
	var start_scale = SCALE_START_FACTOR
	var end_scale = 1.0
	
	# Set initial states
	overlay.modulate.a = FADE_START
	background.modulate.a = FADE_START
	background.scale = Vector2(start_scale, start_scale)
	background.pivot_offset = background.size / 2
	
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

func _play_exit_animation():
	"""Smooth fade-out and scale-down animation before closing"""
	var end_scale = SCALE_START_FACTOR
	
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

func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_close_pressed()

func _on_close_pressed():
	await _play_exit_animation()
	emit_signal("popup_closed")
	queue_free()
