extends Panel

@export var task_cell : Button  # The button representing the task cell that triggered the popup
var task_input = ""  # The task input text that will be saved

# Correct usage for Godot 4.x - use @onready instead of onready
@onready var line_edit = $LineEdit  # The LineEdit node for task input (check your node name)
@onready var save_button = $Save  # The Save button
@onready var cancel_button = $Cancel  # The Cancel button

func _ready():
	# Connect the button actions to their respective functions
	save_button.connect("pressed", _on_save_pressed)
	cancel_button.connect("pressed", _on_cancel_pressed)

# Function to show the popup with the initial task and button reference
func show_popup(initial_task: String, cell: Button):
	task_input = initial_task  # Save the initial task (if any)
	task_cell = cell  # The button (task cell) that triggered the popup
	line_edit.text = initial_task  # Set the LineEdit to show the initial task
	visible = true  # Make the popup visible

# Function to handle task saving
func _on_save_pressed():
	task_cell.text = line_edit.text  # Save the task from the LineEdit to the task cell
	visible = false  # Hide the popup
	# Optionally, you can save the task to a file or variable here

# Function to handle canceling the input
func _on_cancel_pressed():
	visible = false  # Hide the popup without saving any changes
