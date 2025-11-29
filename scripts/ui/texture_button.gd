extends TextureButton

# TaskTextureButton.gd
# Attach this script to a TextureButton node

@onready var popup_dialog: Window
@onready var task_input: LineEdit
@onready var save_button: Button
@onready var cancel_button: Button
@onready var task_label: Label
@onready var task_completed: bool = false

func _ready():
	# Connect the main button click
	pressed.connect(_on_button_pressed)
	
	# Create the task label that will display on the button
	_create_task_label()
	
	# Create the popup dialog
	_create_popup_dialog()
	
	# Set initial label text
	task_label.text = "Add Task"
	
	# Enable toggle mode for crossing out tasks
	toggle_mode = true
	toggled.connect(_on_task_toggled)

func _create_task_label():
	# Create a label as child of the TextureButton
	task_label = Label.new()
	task_label.name = "TaskLabel"
	
	# Center the label on the button
	task_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	task_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	task_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Style the label
	task_label.add_theme_color_override("font_color", Color.WHITE)
	task_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	task_label.add_theme_constant_override("shadow_offset_x", 2)
	task_label.add_theme_constant_override("shadow_offset_y", 2)
	task_label.add_theme_font_size_override("font_size", 16)
	
	# Add label to button
	add_child(task_label)
	
	# Make sure label doesn't block mouse input
	task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _create_popup_dialog():
	# Create the popup window
	popup_dialog = Window.new()
	popup_dialog.title = "Add Task"
	popup_dialog.size = Vector2(400, 200)
	popup_dialog.unresizable = true
	popup_dialog.exclusive = true
	popup_dialog.transient = true
	popup_dialog.wrap_controls = true
	
	# Create container for popup content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(360, 160)
	
	# Create label
	var label = Label.new()
	label.text = "Enter your task:"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	# Create input field
	task_input = LineEdit.new()
	task_input.placeholder_text = "Type your task here..."
	task_input.clear_button_enabled = true
	vbox.add_child(task_input)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)
	
	# Create button container
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Create Save button
	save_button = Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(100, 40)
	save_button.pressed.connect(_on_save_pressed)
	hbox.add_child(save_button)
	
	# Create Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_button)
	
	vbox.add_child(hbox)
	
	# Add the container to popup
	popup_dialog.add_child(vbox)
	
	# Add popup to the scene
	get_tree().root.add_child(popup_dialog)
	popup_dialog.hide()
	
	# Connect close request
	popup_dialog.close_requested.connect(_on_cancel_pressed)

func _on_button_pressed():
	# Only show popup if task is not set or if it's a new task button
	if task_label.text == "Add Task" or task_label.text == "":
		_show_popup()
	# If task exists, just toggle completion state
	elif not task_label.text.begins_with("✓ "):
		button_pressed = !button_pressed

func _show_popup():
	# Reset the input field
	task_input.text = ""
	task_input.grab_focus()
	
	# Center the popup on screen
	var viewport_size = get_viewport().get_visible_rect().size
	popup_dialog.position = (viewport_size - popup_dialog.size) / 2
	
	# Show the popup
	popup_dialog.show()

func _on_save_pressed():
	var task_text = task_input.text.strip_edges()
	
	if task_text != "":
		# Update label text with the task
		task_label.text = task_text
		
		# Reset the toggle state
		button_pressed = false
		task_completed = false
		
		# Update button appearance
		_update_button_style()
		
	# Hide the popup
	popup_dialog.hide()

func _on_cancel_pressed():
	popup_dialog.hide()

func _on_task_toggled(pressed: bool):
	# Only process if we have a task
	if task_label.text != "Add Task" and task_label.text != "":
		task_completed = pressed
		_update_button_style()

func _update_button_style():
	if task_completed:
		# Add checkmark
		if not task_label.text.begins_with("✓ "):
			task_label.text = "✓ " + task_label.text
		
		# Gray out completed tasks
		modulate = Color(0.6, 0.6, 0.6, 1.0)
		
		# Add strikethrough effect to label
		task_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		
	else:
		# Remove checkmark if present
		task_label.text = task_label.text.replace("✓ ", "")
		
		# Normal appearance
		modulate = Color.WHITE
		task_label.add_theme_color_override("font_color", Color.WHITE)

# Override draw to add visual strikethrough line
func _draw():
	if task_completed and task_label.text != "Add Task":
		# Get the label's position and size
		var label_pos = task_label.position
		var label_size = task_label.size
		
		# Calculate line position (middle of the label)
		var line_y = label_pos.y + (label_size.y / 2)
		var line_start_x = label_pos.x
		var line_end_x = label_pos.x + label_size.x
		
		# Draw strikethrough line
		draw_line(
			Vector2(line_start_x - 10, line_y),
			Vector2(line_end_x + 10, line_y),
			Color(0.3, 0.3, 0.3, 0.8),
			2.0
		)

# Optional: Set up different textures for different states
func setup_textures(normal: Texture2D, pressed: Texture2D = null, hover: Texture2D = null, disabled: Texture2D = null):
	texture_normal = normal
	
	if pressed:
		texture_pressed = pressed
	else:
		texture_pressed = normal
		
	if hover:
		texture_hover = hover
	else:
		texture_hover = normal
		
	if disabled:
		texture_disabled = disabled
	else:
		texture_disabled = normal

# Helper function to update label position if button is resized
func _on_resized():
	if task_label:
		task_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
