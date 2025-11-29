# Filename: SettingsPopup.gd
extends Control

signal settings_closed

# ============================================
# NODE REFERENCES
# ============================================

@onready var overlay: ColorRect = $Overlay
@onready var panel: Panel = $CorkboardPanel
# @onready var close_button: TextureButton = $CorkboardPanel/CloseButton

# Sound toggles
@onready var music_toggle: TextureButton = $CorkboardPanel/SoundStickyNote/MusicLabel/MusicToggle
@onready var sfx_toggle: TextureButton = $CorkboardPanel/SoundStickyNote/SFXLabel/SFXToggle

# Audio player
@onready var button_sound: AudioStreamPlayer = AudioStreamPlayer.new()

# ============================================
# PRELOADS
# ============================================

const BUTTON_CLICK_SOUND = preload("res://assets/audio/touchpad.mp3")

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Setup audio player
	add_child(button_sound)
	button_sound.bus = "SFX"
	
	# Setup toggle buttons
	_setup_sound_toggles()
	
	# Connect signals
	_connect_signals()
	
	# Load saved settings
	_load_settings()
	
	# Animate entrance
	_animate_open()
	
	print("✓ Settings popup initialized")

func _setup_sound_toggles():
	"""Setup toggle button properties"""
	
	# Music toggle
	music_toggle.toggle_mode = true
	music_toggle.ignore_texture_size = true
	music_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	music_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	music_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_toggle.custom_minimum_size = Vector2(45, 22)
	
	# SFX toggle
	sfx_toggle.toggle_mode = true
	sfx_toggle.ignore_texture_size = true
	sfx_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	sfx_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sfx_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx_toggle.custom_minimum_size = Vector2(45, 22)
	
	print("✓ Sound toggles configured")

func _connect_signals():
	"""Connect all signals"""
	
	# Close button (uncomment when you add it)
	# close_button.pressed.connect(_on_close_pressed)
	
	# Overlay click (close when clicking outside)
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# Sound toggles
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	
	print("✓ Signals connected")

# ============================================
# ANIMATIONS
# ============================================

func _animate_open():
	"""Entrance animation - preserves your 1.315 scale"""
	panel.modulate.a = 0.0
	
	# ✅ FIX: Save your scene's scale (1.315, 1.315)
	var target_scale = panel.scale
	
	# Start animation from 80% of YOUR scale
	panel.scale = target_scale * 0.8
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	# ✅ FIX: Animate to YOUR scale (not hardcoded 1.0)
	tween.tween_property(panel, "scale", target_scale, 0.3).set_trans(Tween.TRANS_BACK)

func _animate_close():
	"""Exit animation"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	
	# ✅ FIX: Scale down from current scale
	var start_scale = panel.scale
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", start_scale * 0.8, 0.2)
	
	await tween.finished
	emit_signal("settings_closed")
	queue_free()

# ============================================
# CLOSE HANDLERS
# ============================================

func _on_close_pressed():
	"""Close button clicked"""
	_play_sound(BUTTON_CLICK_SOUND)
	_save_settings()
	_animate_close()

func _on_overlay_clicked(event: InputEvent):
	"""Click outside panel to close"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_close_pressed()

# ============================================
# SOUND TOGGLE HANDLERS
# ============================================

func _on_music_toggled(is_on: bool):
	"""Music toggle switched"""
	print("🎵 MUSIC TOGGLED:", is_on)
	
	var music_bus = AudioServer.get_bus_index("Music")
	print("  Music bus index:", music_bus)
	
	if music_bus >= 0:
		if is_on:
			AudioServer.set_bus_volume_db(music_bus, 0.0)
			print("  ✓ Music ON (0 dB)")
		else:
			AudioServer.set_bus_volume_db(music_bus, -80.0)
			print("  ✓ Music OFF (-80 dB)")
	else:
		print("  ❌ ERROR: Music bus doesn't exist!")
	
	_play_sound(BUTTON_CLICK_SOUND)

func _on_sfx_toggled(is_on: bool):
	"""SFX toggle switched"""
	print("🔊 SFX TOGGLED:", is_on)
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	print("  SFX bus index:", sfx_bus)
	
	if sfx_bus >= 0:
		if is_on:
			AudioServer.set_bus_volume_db(sfx_bus, 0.0)
			print("  ✓ SFX ON (0 dB)")
			_play_sound(BUTTON_CLICK_SOUND)
		else:
			_play_sound(BUTTON_CLICK_SOUND)
			await get_tree().create_timer(0.1).timeout
			AudioServer.set_bus_volume_db(sfx_bus, -80.0)
			print("  ✓ SFX OFF (-80 dB)")
	else:
		print("  ❌ ERROR: SFX bus doesn't exist!")

# ============================================
# SAVE/LOAD SETTINGS
# ============================================

func _save_settings():
	"""Save settings to disk"""
	SaveManager.set_setting("music_enabled", music_toggle.button_pressed)
	SaveManager.set_setting("sfx_enabled", sfx_toggle.button_pressed)
	SaveManager.save_settings()
	print("✓ Sound settings saved")

func _load_settings():
	"""Load settings from disk"""
	# Load toggle states (default: both ON)
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	
	# Set toggle button states
	music_toggle.button_pressed = music_on
	sfx_toggle.button_pressed = sfx_on
	
	# Apply audio state immediately (without playing sound)
	_apply_audio_state(music_on, sfx_on)
	
	print("✓ Sound settings loaded: Music=%s, SFX=%s" % [music_on, sfx_on])

func _apply_audio_state(music_on: bool, sfx_on: bool):
	"""Apply audio state without triggering toggle signals"""
	# Set music volume
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"), 
		0.0 if music_on else -80.0
	)
	
	# Set SFX volume
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"), 
		0.0 if sfx_on else -80.0
	)

# ============================================
# SOUND EFFECTS
# ============================================

func _play_sound(sound: AudioStream):
	"""Play button click sound"""
	if sound == null:
		return
	
	button_sound.stream = sound
	button_sound.play()
