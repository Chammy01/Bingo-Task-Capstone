# Filename: Toast.gd
# Toast notification system for displaying temporary messages
extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label
@onready var timer: Timer = $Timer

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	panel.hide()
	timer.timeout.connect(_on_timer_timeout)

# ============================================
# PUBLIC API
# ============================================

func show_toast(message: String, duration: float = 1.5) -> void:
	"""Display a toast notification"""
	label.text = message
	
	# Show panel with fade-in animation
	panel.show()
	panel.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	# Set timer duration
	timer.wait_time = duration
	timer.start()
	
	print("🔔 Toast: %s" % message)

# ============================================
# CALLBACKS
# ============================================

func _on_timer_timeout():
	"""Hide toast when timer expires"""
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.hide)
