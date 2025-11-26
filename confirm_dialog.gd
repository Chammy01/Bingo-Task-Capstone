# Filename: ConfirmDialog.gd
extends CanvasLayer

signal confirmed

@onready var confirm_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CancelButton
@onready var overlay: ColorRect = $Overlay

func _ready():
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	overlay.gui_input.connect(_on_overlay_clicked)

func _on_confirm():
	emit_signal("confirmed")
	queue_free()

func _on_cancel():
	queue_free()

func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_cancel()
