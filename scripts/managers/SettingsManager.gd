# Filename: SettingsManager.gd
# Global autoload for managing app settings
extends Node

# ============================================
# DEBUG LOGGING SYSTEM
# ============================================

const DEBUG_MODE: bool = false

static func debug_log(message: String) -> void:
	"""Helper function for conditional debug logging"""
	if DEBUG_MODE:
		print(message)

# Signals
signal settings_changed
signal daily_reset_toggled(enabled: bool)

# Save paths
const SETTINGS_SAVE_PATH = "user://settings.save"
const LAST_RESET_DATE_PATH = "user://last_reset_date.save"

# Settings data with defaults
var settings = {
	"daily_reset_enabled": false,
	"reset_time_hour": 0,  # Midnight (0-23)
	"reset_behavior": "clear_all",  # "clear_all", "clear_checkmarks", "archive"
	"sound_volume": 1.0,  # 0.0 to 1.0
	"random_colors_enabled": true,
	"background_theme": "cozy_desk"
}

func _ready():
	load_settings()
	check_daily_reset()
	print("SettingsManager initialized")

# ============================================
# SETTINGS GETTERS/SETTERS
# ============================================

func get_setting(key: String):
	return settings.get(key, null)

func set_setting(key: String, value) -> void:
	if settings.has(key):
		settings[key] = value
		save_settings()
		settings_changed.emit()
		
		# Emit specific signals
		if key == "daily_reset_enabled":
			daily_reset_toggled.emit(value)
		
		print("✓ Setting updated: %s = %s" % [key, value])
	else:
		print("⚠ Unknown setting key: %s" % key)

# ============================================
# DAILY RESET SYSTEM
# ============================================

func check_daily_reset() -> void:
	if not settings.daily_reset_enabled:
		print("Daily reset is disabled")
		return
	
	var today = _get_today_string()
	var last_reset = _load_last_reset_date()
	
	print("Checking daily reset - Today: %s | Last: %s" % [today, last_reset])
	
	if last_reset != today:
		print("🔄 New day detected! Performing daily reset...")
		_perform_daily_reset()
		_save_last_reset_date(today)
	else:
		print("Already reset today")

func _perform_daily_reset() -> void:
	var behavior = settings.reset_behavior
	
	print("Performing reset with behavior: %s" % behavior)
	
	match behavior:
		"clear_all":
			_reset_clear_all()
		"clear_checkmarks":
			_reset_clear_checkmarks()
		"archive":
			_reset_archive_tasks()
		_:
			print("⚠ Unknown reset behavior: %s" % behavior)

func _reset_clear_all() -> void:
	var save_path = "user://bingo_task_data.save"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("✓ All tasks cleared")
	else:
		print("No tasks to clear")

func _reset_clear_checkmarks() -> void:
	var save_path = "user://bingo_task_data.save"
	if not FileAccess.file_exists(save_path):
		print("No tasks to reset")
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("⚠ Failed to open save file")
		return
	
	var tile_data = file.get_var()
	file.close()
	
	# Clear completed status
	for i in range(tile_data.size()):
		if tile_data[i].has("completed"):
			tile_data[i]["completed"] = false
		if tile_data[i].has("coins_earned"):
			tile_data[i]["coins_earned"] = false
	
	# Save back
	file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(tile_data)
		file.close()
		print("✓ Checkmarks cleared (text preserved)")

func _reset_archive_tasks() -> void:
	# Future feature: archive completed tasks
	print("Archive feature coming soon!")
	_reset_clear_all()

# ============================================
# STATISTICS
# ============================================

func get_total_coins() -> int:
	return CurrencyManager.get_coins()

func get_tasks_completed() -> int:
	var completed = 0
	var save_path = "user://bingo_task_data.save"
	
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var tile_data = file.get_var()
			file.close()
			for tile in tile_data:
				if tile.get("completed", false):
					completed += 1
	
	return completed

func get_current_streak() -> int:
	# Future: track consecutive days of usage
	return 0

# ============================================
# DANGER ZONE ACTIONS
# ============================================

func clear_all_tasks() -> void:
	_reset_clear_all()
	print("User cleared all tasks")

func reset_all_coins() -> void:
	CurrencyManager.coins = 0
	CurrencyManager.save_coins()
	print("User reset all coins")

# ============================================
# SAVE/LOAD
# ============================================

func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()
		print("Settings saved to disk")
	else:
		print("⚠ Failed to save settings")

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_SAVE_PATH):
		var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
		if file:
			var loaded_data = file.get_var()
			file.close()
			
			# Merge loaded data with defaults (in case new settings were added)
			for key in loaded_data:
				if settings.has(key):
					settings[key] = loaded_data[key]
			
			print("Settings loaded from disk")
		else:
			print("⚠ Failed to load settings file")
	else:
		print("No settings file found - using defaults")
		save_settings()

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_today_string() -> String:
	var date = Time.get_date_dict_from_system()
	return "%d-%02d-%02d" % [date.year, date.month, date.day]

func _save_last_reset_date(date_string: String) -> void:
	var file = FileAccess.open(LAST_RESET_DATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(date_string)
		file.close()
		print("Last reset date saved: %s" % date_string)

func _load_last_reset_date() -> String:
	if FileAccess.file_exists(LAST_RESET_DATE_PATH):
		var file = FileAccess.open(LAST_RESET_DATE_PATH, FileAccess.READ)
		if file:
			var date = file.get_as_text().strip_edges()
			file.close()
			return date
	return ""

# ============================================
# AUDIO SETTINGS (Consolidated)
# ============================================

func apply_audio_settings() -> void:
	"""Apply audio settings from SaveManager to AudioServer buses"""
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	
	_set_bus_volume("Music", music_on)
	_set_bus_volume("SFX", sfx_on)
	
	debug_log("✓ Audio settings applied: Music=%s, SFX=%s" % [music_on, sfx_on])

func _set_bus_volume(bus_name: String, enabled: bool) -> void:
	"""Helper to set audio bus volume based on enabled state"""
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		debug_log("⚠️ '%s' bus not found in AudioServer" % bus_name)
		return
	AudioServer.set_bus_volume_db(bus_index, 0.0 if enabled else -80.0)
