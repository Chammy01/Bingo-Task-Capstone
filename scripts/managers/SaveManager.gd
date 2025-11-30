extends Node

# ============================================
# SAVE FILE PATHS
# ============================================

const TASKS_SAVE_PATH = "user://tasks.save"
const SCHEDULED_TASKS_SAVE_PATH = "user://scheduled_tasks.save"
const SETTINGS_SAVE_PATH = "user://settings.save"
const SESSION_SAVE_PATH = "user://session.save"
const TASK_HISTORY_SAVE_PATH = "user://task_history.save"

# ============================================
# CACHE
# ============================================

var _settings_cache: Dictionary = {}
var _scheduled_tasks_cache: Dictionary = {}
var _task_history_cache: Dictionary = {}

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_load_all_caches()
	print("✓ SaveManager initialized with .save files")
	print("  Tasks: %s" % TASKS_SAVE_PATH)
	print("  Scheduled: %s" % SCHEDULED_TASKS_SAVE_PATH)
	print("  Settings: %s" % SETTINGS_SAVE_PATH)
	print("  Task History: %s" % TASK_HISTORY_SAVE_PATH)

func _load_all_caches():
	"""Load all save files into memory on startup"""
	_settings_cache = _load_dictionary(SETTINGS_SAVE_PATH)
	_scheduled_tasks_cache = _load_dictionary(SCHEDULED_TASKS_SAVE_PATH)
	_task_history_cache = _load_dictionary(TASK_HISTORY_SAVE_PATH)
	print("  Loaded %d settings" % _settings_cache.size())
	print("  Loaded %d scheduled dates" % _scheduled_tasks_cache.get("scheduled_tasks", {}).size())
	print("  Loaded %d history dates" % _task_history_cache.get("history", {}).size())

# ============================================
# TASKS (Daily Board)
# ============================================

func save_tasks(tasks_data: Array) -> bool:
	"""Save today's board tasks"""
	var file = FileAccess.open(TASKS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save tasks: " + str(FileAccess.get_open_error()))
		return false
	
	var save_data = {
		"version": "1.0",
		"saved_at": Time.get_datetime_string_from_system(),
		"tasks": tasks_data
	}
	
	file.store_var(save_data)
	file.close()
	return true

func load_tasks() -> Array:
	"""Load today's board tasks"""
	if not FileAccess.file_exists(TASKS_SAVE_PATH):
		print("  No tasks file found, starting fresh")
		return []
	
	var file = FileAccess.open(TASKS_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load tasks: " + str(FileAccess.get_open_error()))
		return []
	
	var save_data = file.get_var()
	file.close()
	
	if save_data is Dictionary and save_data.has("tasks"):
		print("  Loaded %d tasks from file" % save_data.tasks.size())
		return save_data.tasks
	
	return []

# ============================================
# SCHEDULED TASKS (Future Dates)
# ============================================

func save_scheduled_tasks(scheduled_dict: Dictionary) -> bool:
	"""Save all scheduled tasks for future dates"""
	var file = FileAccess.open(SCHEDULED_TASKS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save scheduled tasks: " + str(FileAccess.get_open_error()))
		return false
	
	var save_data = {
		"version": "1.0",
		"saved_at": Time.get_datetime_string_from_system(),
		"scheduled_tasks": scheduled_dict
	}
	
	file.store_var(save_data)
	file.close()
	
	# Update cache
	_scheduled_tasks_cache = save_data
	
	print("💾 Saved scheduled tasks file (%d dates)" % scheduled_dict.size())
	return true

func load_scheduled_tasks() -> Dictionary:
	"""Load all scheduled tasks"""
	if not FileAccess.file_exists(SCHEDULED_TASKS_SAVE_PATH):
		print("  No scheduled tasks file found")
		return {}
	
	var file = FileAccess.open(SCHEDULED_TASKS_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load scheduled tasks: " + str(FileAccess.get_open_error()))
		return {}
	
	var save_data = file.get_var()
	file.close()
	
	if save_data is Dictionary and save_data.has("scheduled_tasks"):
		var tasks = save_data.scheduled_tasks
		_scheduled_tasks_cache = save_data
		print("  Loaded scheduled tasks for %d dates" % tasks.size())
		return tasks
	
	return {}

# ============================================
# TASK HISTORY (Daily Archive)
# ============================================

func save_task_history(date_key: String, tasks_data: Array) -> bool:
	"""Save task history for a specific date (YYYY-MM-DD)"""
	var history = _task_history_cache.get("history", {})
	
	history[date_key] = {
		"tasks": tasks_data,
		"saved_at": Time.get_datetime_string_from_system()
	}
	
	var save_data = {
		"version": "1.0",
		"saved_at": Time.get_datetime_string_from_system(),
		"history": history
	}
	
	var file = FileAccess.open(TASK_HISTORY_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save task history: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_var(save_data)
	file.close()
	
	_task_history_cache = save_data
	print("📅 Task history saved for %s" % date_key)
	return true

func load_all_task_history() -> Dictionary:
	"""Load all task history, returns { date_key: { tasks: Array, saved_at: String } }"""
	if not FileAccess.file_exists(TASK_HISTORY_SAVE_PATH):
		return {}
	
	var file = FileAccess.open(TASK_HISTORY_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load task history: " + str(FileAccess.get_open_error()))
		return {}
	
	var save_data = file.get_var()
	file.close()
	
	if save_data is Dictionary and save_data.has("history"):
		_task_history_cache = save_data
		return save_data.history
	
	return {}

func get_task_history_for_date(date_key: String) -> Dictionary:
	"""Get task history for a specific date, returns { tasks: Array, saved_at: String } or empty"""
	var history = _task_history_cache.get("history", {})
	if history.has(date_key):
		return history[date_key]
	
	# Try loading from file if not in cache
	var all_history = load_all_task_history()
	if all_history.has(date_key):
		return all_history[date_key]
	
	return {}

func get_task_history_summary() -> Dictionary:
	"""Get summary for calendar indicators, returns { date_key: { completed: int, total: int } }"""
	var history = _task_history_cache.get("history", {})
	if history.is_empty():
		history = load_all_task_history()
	
	var summary = {}
	for date_key in history.keys():
		var entry = history[date_key]
		if not entry.has("tasks"):
			continue
		
		var tasks: Array = entry.tasks
		var completed := 0
		var total := 0
		
		for task in tasks:
			if task is Dictionary and task.has("text"):
				var text: String = task.text
				if text != "" and text != "Tap to add task":
					total += 1
					if task.has("completed") and task.completed:
						completed += 1
		
		if total > 0:
			summary[date_key] = { "completed": completed, "total": total }
	
	return summary


# ============================================
# SETTINGS (Generic Key-Value Storage)
# ============================================

func save_setting(key: String, value: Variant) -> bool:
	"""Save a single setting"""
	_settings_cache[key] = value
	return _save_all_settings()

func save_settings() -> bool:
	"""Save all settings (for batch saves from settings popup)"""
	return _save_all_settings()

func get_setting(key: String, default_value: Variant = null) -> Variant:
	"""Get a setting value"""
	if _settings_cache.has(key):
		return _settings_cache[key]
	return default_value

func set_setting(key: String, value: Variant):
	"""Alias for save_setting"""
	save_setting(key, value)

func save_value(key: String, value: Variant):
	"""Another alias for save_setting"""
	save_setting(key, value)

func _save_all_settings() -> bool:
	"""Save all settings to file"""
	var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save settings: " + str(FileAccess.get_open_error()))
		return false
	
	var save_data = {
		"version": "1.0",
		"saved_at": Time.get_datetime_string_from_system(),
		"settings": _settings_cache
	}
	
	file.store_var(save_data)
	file.close()
	print("✓ Settings saved to file")
	return true

func _load_settings() -> Dictionary:
	"""Load settings from file"""
	if not FileAccess.file_exists(SETTINGS_SAVE_PATH):
		return {}
	
	var file = FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load settings: " + str(FileAccess.get_open_error()))
		return {}
	
	var save_data = file.get_var()
	file.close()
	
	if save_data is Dictionary and save_data.has("settings"):
		return save_data.settings
	
	return {}

# ============================================
# HELPER FUNCTIONS
# ============================================

func _load_dictionary(path: String) -> Dictionary:
	"""Generic dictionary loader"""
	if not FileAccess.file_exists(path):
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var data = file.get_var()
	file.close()
	
	if data is Dictionary:
		return data
	
	return {}

func _save_dictionary(path: String, data: Dictionary) -> bool:
	"""Generic dictionary saver"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_var(data)
	file.close()
	return true

# ============================================
# DEBUG / UTILITY
# ============================================

func clear_all_saves():
	"""Clear all save files (for testing)"""
	DirAccess.remove_absolute(TASKS_SAVE_PATH)
	DirAccess.remove_absolute(SCHEDULED_TASKS_SAVE_PATH)
	DirAccess.remove_absolute(SETTINGS_SAVE_PATH)
	DirAccess.remove_absolute(SESSION_SAVE_PATH)
	DirAccess.remove_absolute(TASK_HISTORY_SAVE_PATH)
	_settings_cache.clear()
	_scheduled_tasks_cache.clear()
	_task_history_cache.clear()
	print("🗑️ All save files cleared")

func get_save_file_info() -> Dictionary:
	"""Get info about save files"""
	return {
		"tasks_exists": FileAccess.file_exists(TASKS_SAVE_PATH),
		"scheduled_exists": FileAccess.file_exists(SCHEDULED_TASKS_SAVE_PATH),
		"settings_exists": FileAccess.file_exists(SETTINGS_SAVE_PATH),
		"history_exists": FileAccess.file_exists(TASK_HISTORY_SAVE_PATH),
		"tasks_path": TASKS_SAVE_PATH,
		"scheduled_path": SCHEDULED_TASKS_SAVE_PATH,
		"settings_path": SETTINGS_SAVE_PATH,
		"history_path": TASK_HISTORY_SAVE_PATH
	}

func print_save_locations():
	"""Debug: Print where save files are stored"""
	print("\n📁 === SAVE FILE LOCATIONS ===")
	print("User data directory: %s" % OS.get_user_data_dir())
	print("Tasks: %s" % TASKS_SAVE_PATH)
	print("Scheduled: %s" % SCHEDULED_TASKS_SAVE_PATH)
	print("Settings: %s" % SETTINGS_SAVE_PATH)
	print("Task History: %s" % TASK_HISTORY_SAVE_PATH)
	print("==============================\n")
