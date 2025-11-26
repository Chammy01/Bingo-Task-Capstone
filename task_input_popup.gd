# Filename: TaskInputPopup.gd
extends Control

signal task_confirmed(new_text, was_cancelled)

@onready var task_input: TextEdit = $StickyNote/MarginContainer/TaskInput
@onready var confirm_button: TextureButton = $StickyNote/ConfirmButton
@onready var cancel_button: TextureButton = $StickyNote/CancelButton
@onready var sticky_note: TextureRect = $StickyNote

func _ready():
	self.hide()
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP

func popup(existing_text: String = "", sticky_texture: Texture2D = null):
	task_input.text = existing_text
	
	if sticky_texture != null:
		sticky_note.texture = sticky_texture
	
	self.show()
	
	# Wait for UI to update
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Give focus first
	task_input.grab_focus()
	
	# Wait for keyboard to appear
	await get_tree().process_frame
	
	# NEW: Select all text if there's existing text
	if not existing_text.is_empty():
		var line_count = task_input.get_line_count()
		var last_line = line_count - 1
		var last_column = task_input.get_line(last_line).length()
		
		# Select from start (0,0) to end (last_line, last_column)
		task_input.select(0, 0, last_line, last_column)
	else:
		# No existing text, just position cursor at start
		task_input.set_caret_line(0)
		task_input.set_caret_column(0)

func _on_confirm_pressed():
	task_input.release_focus()
	await get_tree().create_timer(0.1).timeout
	
	var confirmed_text = task_input.text.strip_edges()
	emit_signal("task_confirmed", confirmed_text, false)
	queue_free()

func _on_cancel_pressed():
	task_input.release_focus()
	await get_tree().create_timer(0.1).timeout
	
	emit_signal("task_confirmed", "", true)
	queue_free()
