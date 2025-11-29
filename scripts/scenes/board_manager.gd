extends Node

# ============================================
# NODE REFERENCES
# ============================================

@onready var settings_button: TextureButton = get_node("../Settings")
@onready var grid_container = $GridContainer
@onready var play_button: TextureButton = get_node("../BottomContainer/PlayButton")
@onready var pause_button: TextureButton = get_node("../BottomContainer/PauseButton")
@onready var reset_button: TextureButton = get_node("../BottomContainer/ResetButton")
@onready var session_time_label: Label = get_node("../SessionTimeLabel")
@onready var progress_label: Label = get_node("../ProgressLabel")
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var background: TextureRect = get_node("../Background")
@onready var calendar_button: TextureButton = get_node("../Calendar/CalendarButton")

var deco_nodes: Array = []

# ============================================
# PRELOADS
# ============================================

const SETTINGS_POPUP = preload("res://scenes/SettingsPopup.tscn")
const TASK_INPUT_POPUP = preload("res://scenes/TaskInputPopup.tscn")
const BINGO_TILE = preload("res://scenes/BingoTile.tscn")
const CONFIRM_DIALOG = preload("res://scenes/ConfirmDialog.tscn")
const COIN_SOUND = preload("res://assets/audio/coin-sound.mp3")
const BINGO_SOUND = preload("res://assets/audio/bingo.mp3")
const BUTTON_CLICK_SOUND = preload("res://assets/audio/touchpad.mp3")
const SUCCESS_SOUND = preload("res://assets/audio/notification-alert.mp3")
const DEADLINE_WARNING_SOUND = preload("res://assets/audio/notification-alert.mp3")
const DEADLINE_EXPIRED_SOUND = preload("res://assets/audio/notification-error.mp3")
const CALENDAR_POPUP = preload("res://scenes/CalendarPopup.tscn")

# ============================================
# VARIABLES
# ============================================

var tiles: Array = []
var scheduled_tasks: Dictionary = {}
var is_scheduling_mode: bool = false
var scheduling_date: Dictionary = {}
var debug_date_override: Dictionary = {}

# ============================================
# DEBUG DATE HELPER
# ============================================

func _get_current_date() -> Dictionary:
	if not debug_date_override.is_empty():
		return debug_date_override
	return Time.get_datetime_dict_from_system()

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	create_bingo_grid()
	debug_date_override = SaveManager.get_setting("debug_date_override", {})
	is_scheduling_mode = SaveManager.get_setting("is_scheduling_mode", false)
	
	if is_scheduling_mode:
		_load_scheduling_mode()
	else:
		if debug_date_override.is_empty():
			load_saved_tasks()
		else:
			print("🧪 Debug mode: Skipping today's tasks, will load scheduled tasks for debug date")
			for tile in tiles:
				tile.set_task_text("")
		_load_and_apply_today_scheduled_tasks()
	
	_apply_audio_settings()
	add_child(audio_player)
	audio_player.bus = "SFX"
	_auto_collect_decorations()
	
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme()
	_update_decorations()
	
	SessionManager.timer_updated.connect(_on_timer_updated)
	SessionManager.session_started.connect(_on_session_started)
	SessionManager.session_paused.connect(_on_session_paused)
	SessionManager.session_resumed.connect(_on_session_resumed)
	SessionManager.session_stopped.connect(_on_session_stopped)
	SessionManager.deadline_warning.connect(_on_deadline_warning)
	SessionManager.deadline_expired.connect(_on_deadline_expired)
	
	play_button.pressed.connect(_on_play_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)

	if calendar_button:
		if is_scheduling_mode:
			calendar_button.pressed.connect(_on_exit_scheduling_mode)
		else:
			calendar_button.pressed.connect(_on_calendar_pressed)
	
	_update_timer_display(SessionManager.get_session_elapsed_time())
	_update_progress_display()
	
	# Check notification state on startup
	if not is_scheduling_mode:
		NotificationManager.check_no_tasks_state()
	
	print("✓ BoardManager initialized (Scheduling Mode: %s)" % is_scheduling_mode)

# ============================================
# SCHEDULING MODE
# ============================================

func _load_scheduling_mode():
	scheduling_date = SaveManager.get_setting("scheduling_date", {})
	
	if scheduling_date.is_empty():
		print("⚠️ No scheduling date found, loading normal mode")
		SaveManager.set_setting("is_scheduling_mode", false)
		is_scheduling_mode = false
		load_saved_tasks()
		return
	
	var date_key = "%04d-%02d-%02d" % [scheduling_date.year, scheduling_date.month, scheduling_date.day]
	scheduled_tasks = SaveManager.load_scheduled_tasks()
	
	if scheduled_tasks.has(date_key):
		var tasks_for_date = scheduled_tasks[date_key]
		for i in range(min(tasks_for_date.size(), tiles.size())):
			tiles[i].set_task_text(tasks_for_date[i])
		print("✓ Loaded %d existing scheduled tasks for %s" % [tasks_for_date.size(), date_key])
	else:
		for tile in tiles:
			tile.set_task_text("")
		print("✓ Clean board for new date: %s" % date_key)
	
	var date_display = "%s %d, %d" % [
		["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][scheduling_date.month - 1],
		scheduling_date.day,
		scheduling_date.year
	]
	Toast.show_toast("📅 Planning for %s\n💡 Tap calendar to save & exit" % date_display, 3.0)

func _on_exit_scheduling_mode():
	_play_sound(BUTTON_CLICK_SOUND)
	_save_scheduled_tasks_for_date()
	SaveManager.set_setting("is_scheduling_mode", false)
	SaveManager.set_setting("scheduling_date", {})
	Toast.show_toast("✅ Tasks scheduled! Returning...", 2.0)
	get_tree().reload_current_scene()

func _save_scheduled_tasks_for_date():
	if scheduling_date.is_empty():
		return
	
	var date_key = "%04d-%02d-%02d" % [scheduling_date.year, scheduling_date.month, scheduling_date.day]
	var tasks_for_date = []
	
	for tile in tiles:
		var task_text = tile.task_label.text
		if task_text != "" and task_text != "Tap to add task":
			tasks_for_date.append(task_text)
	
	scheduled_tasks = SaveManager.load_scheduled_tasks()
	print("💾 Saving scheduled tasks for %s" % date_key)
	print("  Tasks to save: %d" % tasks_for_date.size())
	print("  Existing scheduled dates: %d" % scheduled_tasks.size())
	
	if tasks_for_date.size() > 0:
		scheduled_tasks[date_key] = tasks_for_date
		print("✓ Saved %d tasks for %s" % [tasks_for_date.size(), date_key])
		# Schedule daily reminders for this date
		NotificationManager.schedule_daily_reminders(date_key, tasks_for_date.size())
	else:
		scheduled_tasks.erase(date_key)
		print("✓ Removed empty schedule for %s" % date_key)
		# Cancel daily reminders for this date
		NotificationManager.cancel_daily_reminders(date_key)
	
	if SaveManager.save_scheduled_tasks(scheduled_tasks):
		print("✓ Scheduled tasks file updated (%d dates)" % scheduled_tasks.size())
	else:
		print("⚠️ Failed to save scheduled tasks")
	
	for date in scheduled_tasks.keys():
		print("    - %s: %d tasks" % [date, scheduled_tasks[date].size()])

# ============================================
# CALENDAR INTEGRATION
# ============================================

func _on_calendar_pressed():
	_play_sound(BUTTON_CLICK_SOUND)
	var calendar = CALENDAR_POPUP.instantiate()
	get_tree().root.add_child(calendar)
	calendar.scheduled_tasks = _get_scheduled_task_counts()
	calendar.date_selected.connect(_on_calendar_date_selected)
	calendar.popup_closed.connect(func(): calendar.queue_free())
	print("📅 Calendar opened")

func _on_calendar_date_selected(date: Dictionary):
	save_all_tasks()
	SaveManager.set_setting("scheduling_date", date)
	SaveManager.set_setting("is_scheduling_mode", true)
	var date_string = "%s %d, %d" % [
		["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.month - 1],
		date.day,
		date.year
	]
	Toast.show_toast("📅 Loading board for %s..." % date_string, 1.5)
	get_tree().reload_current_scene()

func _load_and_apply_today_scheduled_tasks():
	scheduled_tasks = SaveManager.load_scheduled_tasks()
	var today = _get_current_date()
	var today_key = "%04d-%02d-%02d" % [today.year, today.month, today.day]
	
	print("📅 Checking scheduled tasks for: %s" % today_key)
	print("  Total scheduled dates: %d" % scheduled_tasks.size())
	
	for date_key in scheduled_tasks.keys():
		print("    - %s: %d task(s)" % [date_key, scheduled_tasks[date_key].size()])
	
	var last_load_date = SaveManager.get_setting("last_scheduled_load_date", "")
	var is_debug_mode = not debug_date_override.is_empty()
	
	if not is_debug_mode and last_load_date == today_key:
		print("  ✓ Already loaded today's tasks earlier")
		return
	
	if not is_debug_mode:
		SaveManager.set_setting("last_scheduled_load_date", today_key)
	
	if scheduled_tasks.has(today_key):
		var tasks_for_today = scheduled_tasks[today_key].duplicate()
		var tile_index = 0
		
		print("✓ Found %d scheduled tasks for %s" % [tasks_for_today.size(), today_key])
		
		for task_text in tasks_for_today:
			if tile_index >= tiles.size():
				break
			tiles[tile_index].set_task_text(task_text)
			tile_index += 1
		
		if not is_debug_mode:
			scheduled_tasks.erase(today_key)
			SaveManager.save_scheduled_tasks(scheduled_tasks)
			print("✓ Loaded and removed today's tasks")
		else:
			print("🧪 Debug mode: Loaded tasks but keeping them in schedule")
		
		print("  Remaining scheduled dates: %d" % scheduled_tasks.size())
		
		if tasks_for_today.size() > 0:
			if is_debug_mode:
				Toast.show_toast("🧪 DEBUG: Loaded %d task(s) for %s!" % [tasks_for_today.size(), today_key], 3.0)
			else:
				Toast.show_toast("📅 Loaded %d task(s) for today!" % tasks_for_today.size(), 2.0)
			if not is_debug_mode:
				save_all_tasks()
	else:
		print("  No scheduled tasks for %s" % today_key)
		if is_debug_mode:
			Toast.show_toast("🧪 No tasks scheduled for this date", 2.0)

func _get_scheduled_task_counts() -> Dictionary:
	var saved_scheduled = SaveManager.load_scheduled_tasks()
	var counts = {}
	for date_key in saved_scheduled.keys():
		counts[date_key] = saved_scheduled[date_key].size()
	return counts

# ============================================
# DECORATION AUTO-DETECTION
# ============================================

func _auto_collect_decorations():
	deco_nodes.clear()
	var i = 1
	while true:
		var deco_name = "../Deco%d" % i
		var deco = get_node_or_null(deco_name)
		if deco == null:
			break
		deco_nodes.append(deco)
		i += 1
	if deco_nodes.size() == 0:
		print("  ⚠️ No decoration nodes found")
	else:
		print("  ✓ Found %d decoration nodes" % deco_nodes.size())

# ============================================
# THEME MANAGEMENT
# ============================================

func _apply_theme():
	if not background:
		print("⚠️ Background node not found")
		return
	var texture = ThemeManager.get_current_background()
	if texture and texture is Texture:
		background.texture = texture
		print("✓ Background applied")
	else:
		print("⚠️ No valid background texture found")

func _on_theme_changed(_theme_id: String):
	print("\n🎨 Theme changed in board, updating...")
	_apply_theme()
	_update_decorations()

func _update_decorations():
	var decoration_data = ThemeManager.get_current_decorations()
	
	if decoration_data.size() == 0:
		_hide_all_decorations()
		return
	
	var sprite_sheet = decoration_data.get("sprite_sheet")
	if not sprite_sheet or not sprite_sheet is Texture2D:
		_hide_all_decorations()
		return
	
	var items = decoration_data.get("items", [])
	print("  📦 Applying %d decorations to %d available nodes" % [items.size(), deco_nodes.size()])
	
	# Apply decorations to available nodes
	for i in range(min(items.size(), deco_nodes.size())):
		var deco = deco_nodes[i]
		var item = items[i]
		
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = sprite_sheet
		atlas_texture.region = item.region
		
		deco.texture = atlas_texture
		deco.scale = Vector2(item.scale, item.scale)
		deco.visible = true
		
		print("    ✓ Deco%d: %s applied" % [i + 1, item.name])
	
	# Hide unused decoration nodes
	for i in range(items.size(), deco_nodes.size()):
		if deco_nodes[i]:
			deco_nodes[i].visible = false
			print("    ⚪ Deco%d: hidden" % [i + 1])

func _hide_all_decorations():
	for deco in deco_nodes:
		if deco:
			deco.visible = false
	print("  ⚪ All decorations hidden")

# ============================================
# SESSION MANAGER SIGNAL HANDLERS
# ============================================

func _on_timer_updated(elapsed: float):
	_update_timer_display(elapsed)

func _on_session_started():
	Toast.show_toast("▶️ Session started!", 1.5)

func _on_session_paused():
	Toast.show_toast("⏸⏸ Session paused", 1.5)

func _on_session_resumed():
	Toast.show_toast("▶️ Session resumed!", 1.5)

func _on_session_stopped():
	_update_timer_display(0)
	Toast.show_toast("⏹ Session stopped!", 1.5)

func _on_deadline_warning(seconds_remaining: int):
	_play_sound(DEADLINE_WARNING_SOUND)
	Toast.show_toast("⚠️ Deadline in %ds!" % seconds_remaining, 1.5)
	print("⚠️ Deadline warning: %d seconds remaining" % seconds_remaining)

func _on_deadline_expired():
	_play_sound(DEADLINE_EXPIRED_SOUND)
	Toast.show_toast("⚠️ Deadline expired! 25 coins only", 2.0)
	print("⚠️ Deadline has expired!")

# ============================================
# SETTINGS FUNCTIONS
# ============================================

func _on_settings_pressed():
	_play_sound(BUTTON_CLICK_SOUND)
	var popup = SETTINGS_POPUP.instantiate()
	get_tree().root.add_child(popup)
	popup.settings_closed.connect(_on_settings_closed)
	print("⚙️ Settings opened from bingo board")

func _on_settings_closed():
	_apply_audio_settings()
	print("⚙️ Settings closed")

func _apply_audio_settings():
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, 0.0 if music_on else -80.0)
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, 0.0 if sfx_on else -80.0)
	print("✓ Audio settings applied: Music=%s, SFX=%s" % [music_on, sfx_on])

# ============================================
# BINGO GRID CREATION
# ============================================

func create_bingo_grid():
	for i in 9:
		var new_tile = BINGO_TILE.instantiate()
		new_tile.tile_index = i
		new_tile.edit_requested.connect(on_tile_edit_requested)
		new_tile.tile_changed.connect(_on_tile_changed)
		new_tile.request_complete.connect(_on_tile_complete_requested)
		grid_container.add_child(new_tile)
		var color_pattern = [0, 2, 0, 1, 2, 1, 2, 1, 0]
		new_tile.set_sticky_color(color_pattern[i])
		tiles.append(new_tile)
	print("✓ Bingo grid created with %d tiles" % tiles.size())

# ============================================
# TILE EDIT HANDLER
# ============================================

func on_tile_edit_requested(tile_to_edit):
	var popup = TASK_INPUT_POPUP.instantiate()
	get_tree().root.add_child(popup)
	var current_text = tile_to_edit.task_label.text
	var current_texture = tile_to_edit.get_current_texture()
	popup.popup(current_text, current_texture)
	var result = await popup.task_confirmed
	var new_task_text = result[0]
	var was_cancelled = result[1]
	
	if not was_cancelled:
		tile_to_edit.set_task_text(new_task_text)
		
		if is_scheduling_mode:
			_save_scheduled_tasks_for_date()
			print("✓ Auto-saved scheduled tasks after edit")
		else:
			save_all_tasks()
			# Notify when a task is added
			if new_task_text != "" and new_task_text != "Tap to add task":
				NotificationManager.on_task_added()
		
		print("✓ Task updated: %s" % new_task_text)

# ============================================
# TILE COMPLETION HANDLER
# ============================================

func _on_tile_complete_requested(tile):
	if is_scheduling_mode:
		Toast.show_toast("⚠️ Can't complete in planning mode!", 1.5)
		return
	if tile.is_completed:
		Toast.show_toast("✅ Already completed!", 1.0)
		return
	if not SessionManager.is_running():
		Toast.show_toast("⚠️ Start the session first!")
		return
	if not SessionManager.can_earn_coins():
		var elapsed = SessionManager.get_session_elapsed_time()
		var remaining = int(SessionManager.MIN_TIME_FOR_COINS - elapsed)
		Toast.show_toast("⏳ Keep working! %ds" % remaining, 1.0)
		return
	
	_play_sound(COIN_SOUND)
	var coins_earned = SessionManager.get_coins_for_task()
	
	if coins_earned > 0:
		Toast.show_toast("🪙 +%d Coins!" % coins_earned, 2.0)
		CurrencyManager.earn_coins(coins_earned, "Task completed")
		print("Task completed! Earned %d coins" % coins_earned)
	else:
		Toast.show_toast("⏳ Too early! Keep working", 1.5)
		return
	
	tile.mark_as_completed()
	BadgeManager.increment_tasks()
	_update_progress_display()
	
	var row_complete = tile._check_row_complete()
	var col_complete = tile._check_column_complete()
	
	if row_complete and col_complete:
		CurrencyManager.earn_coins(50, "BINGO bonus")
		_play_sound(BINGO_SOUND)
		Toast.show_toast("🎉 BINGO! +50!", 2.0)
		BadgeManager.increment_bingos()
	elif row_complete or col_complete:
		CurrencyManager.earn_coins(20, "Row/Col bonus")
		_play_sound(COIN_SOUND)
		Toast.show_toast("🎊 Row/Col +20", 1.5)
		BadgeManager.increment_bingos()
	
	_check_badge_unlocks()
	save_all_tasks()
	
	# Notify task completion
	NotificationManager.on_task_completed()
	var completed = _count_completed_tasks()
	NotificationManager.update_progress(completed, tiles.size())

# ============================================
# BADGE UNLOCK CHECKING
# ============================================

func _check_badge_unlocks():
	print("\n📊 === CHECKING BADGES ===")
	var completed_count = _count_completed_tasks()
	var total_coins = CurrencyManager.get_total_coins()
	print("  Session completed: %d" % completed_count)
	print("  Lifetime tasks: %d" % BadgeManager.stats.total_tasks)
	print("  Total coins: %d" % total_coins)
	
	if completed_count >= 1:
		BadgeManager.unlock_badge("starter")
	if BadgeManager.stats.first_bingo_done:
		BadgeManager.unlock_badge("badge3")
	if BadgeManager.stats.total_bingos >= 3:
		BadgeManager.unlock_badge("badge2")
	if total_coins >= 500:
		BadgeManager.unlock_badge("badge4")
	if BadgeManager.stats.total_tasks >= 20:
		BadgeManager.unlock_badge("badge6")
	
	_check_legend_badge()
	print("\n✓ Badge check complete\n=========================\n")

func _check_legend_badge():
	var required_badges = ["starter", "badge2", "badge3", "badge4", "badge6"]
	for badge_id in required_badges:
		if not BadgeManager.is_unlocked(badge_id):
			return
	BadgeManager.unlock_badge("badge5")

func _count_completed_tasks() -> int:
	var count = 0
	for tile in tiles:
		if tile.is_completed:
			count += 1
	return count

# ============================================
# SESSION CONTROL BUTTONS
# ============================================

func _on_play_button_pressed():
	if is_scheduling_mode:
		Toast.show_toast("⚠️ Can't start session in planning mode!", 1.5)
		return
	_play_sound(BUTTON_CLICK_SOUND)
	SessionManager.start_session()

func _on_pause_button_pressed():
	if is_scheduling_mode:
		return
	_play_sound(BUTTON_CLICK_SOUND)
	SessionManager.pause_session()

func _on_reset_button_pressed():
	_play_sound(BUTTON_CLICK_SOUND)
	var dialog = CONFIRM_DIALOG.instantiate()
	get_tree().root.add_child(dialog)
	await dialog.confirmed
	if not is_scheduling_mode:
		SessionManager.stop_session()
	for tile in tiles:
		tile.is_loading = true
		tile.set_task_text("")
		tile.is_completed = false
		tile._update_x_mark()
		tile.is_loading = false
	
	if is_scheduling_mode:
		_save_scheduled_tasks_for_date()
	else:
		save_all_tasks()
	
	_update_progress_display()
	Toast.show_toast("↺ Board cleared!", 1.5)

# ============================================
# BACK BUTTON
# ============================================

func _on_back_pressed():
	_play_sound(BUTTON_CLICK_SOUND)
	if is_scheduling_mode:
		_save_scheduled_tasks_for_date()
		SaveManager.set_setting("is_scheduling_mode", false)
		SaveManager.set_setting("scheduling_date", {})
	else:
		save_all_tasks()
	SessionManager.save_session_data()
	print("⬅️ Returning to main menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ============================================
# DISPLAY UPDATE FUNCTIONS
# ============================================

func _update_timer_display(elapsed: float):
	@warning_ignore("integer_division")
	var minutes = int(elapsed) / 60
	var seconds = int(elapsed) % 60
	session_time_label.text = "⏱️ %02d:%02d" % [minutes, seconds]

func _update_progress_display():
	if progress_label and not is_scheduling_mode:
		var completed = _count_completed_tasks()
		var total = tiles.size()
		progress_label.text = "📋 %d/%d" % [completed, total]
		# Update notification manager with progress
		NotificationManager.update_progress(completed, total)

# ============================================
# SAVE/LOAD
# ============================================

func save_all_tasks() -> void:
	var tasks_data = []
	for tile in tiles:
		tasks_data.append(tile.get_tile_data())
	if SaveManager.save_tasks(tasks_data):
		print("✓ Tasks saved to file")
	else:
		print("⚠️ Failed to save tasks")

func load_saved_tasks() -> void:
	var saved_data = SaveManager.load_tasks()
	var color_pattern = [0, 2, 0, 1, 2, 1, 2, 1, 0]
	if saved_data.size() > 0:
		for i in range(min(saved_data.size(), tiles.size())):
			tiles[i].is_loading = true
			if saved_data[i].has("text"):
				tiles[i].set_task_text(saved_data[i].text)
			if saved_data[i].has("completed"):
				tiles[i].is_completed = saved_data[i].completed
				tiles[i]._update_x_mark()
			tiles[i].set_sticky_color(color_pattern[i])
			tiles[i].is_loading = false
		print("✓ Loaded %d saved tasks from file" % saved_data.size())

func _on_tile_changed(_tile):
	if is_scheduling_mode:
		_save_scheduled_tasks_for_date()
		print("✓ Auto-saved scheduled tasks (tile changed)")
	else:
		save_all_tasks()
		_update_progress_display()

# ============================================
# SOUND EFFECTS
# ============================================

func _play_sound(sound: AudioStream, volume: float = 0.0) -> void:
	if sound == null:
		return
	audio_player.stream = sound
	audio_player.volume_db = volume
	audio_player.play()

# ============================================
# DEBUG HELPERS
# ============================================

func _debug_print_scheduled_tasks():
	var saved_scheduled = SaveManager.load_scheduled_tasks()
	var last_load = SaveManager.get_setting("last_scheduled_load_date", "none")
	print("\n📊 === SCHEDULED TASKS DEBUG ===")
	print("Save file: %s" % SaveManager.SCHEDULED_TASKS_SAVE_PATH)
	print("File exists: %s" % FileAccess.file_exists(SaveManager.SCHEDULED_TASKS_SAVE_PATH))
	print("Last load date: %s" % last_load)
	print("Total scheduled dates: %d" % saved_scheduled.size())
	if saved_scheduled.size() == 0:
		print("  (No scheduled tasks)")
	else:
		for date_key in saved_scheduled.keys():
			print("  📅 %s:" % date_key)
			for task in saved_scheduled[date_key]:
				print("    - %s" % task)
	print("================================\n")

# ============================================
# DEBUG (Symbol Keys)
# ============================================

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_BRACKETLEFT:
				print("\n🧪 TEST: Force unlocking all badges...\n")
				BadgeManager.stats.total_tasks = 20
				BadgeManager.stats.total_bingos = 3
				BadgeManager.stats.first_bingo_done = true
				BadgeManager.save_stats()
				_check_badge_unlocks()
				Toast.show_toast("🧪 All badges unlocked!", 2.0)
			KEY_BRACKETRIGHT:
				print("\n📊 CURRENT STATS:")
				print("  Tasks completed: %d / 20" % BadgeManager.stats.total_tasks)
				print("  BINGOs achieved: %d / 3" % BadgeManager.stats.total_bingos)
				print("  Total coins: %d / 500" % CurrencyManager.get_total_coins())
				print("  First BINGO: %s" % BadgeManager.stats.first_bingo_done)
				print("  Badges unlocked: %d / 6" % BadgeManager.get_unlock_count())
			KEY_SEMICOLON:
				_debug_print_scheduled_tasks()
			KEY_APOSTROPHE:
				SaveManager.print_save_locations()
			KEY_SLASH:
				var tomorrow = Time.get_datetime_dict_from_system()
				tomorrow.day += 1
				if tomorrow.day > 31:
					tomorrow.day = 1
					tomorrow.month += 1
					if tomorrow.month > 12:
						tomorrow.month = 1
						tomorrow.year += 1
				var date_key = "%04d-%02d-%02d" % [tomorrow.year, tomorrow.month, tomorrow.day]
				var scheduled = SaveManager.load_scheduled_tasks()
				var task_count = 0
				if scheduled.has(date_key):
					task_count = scheduled[date_key].size()
				SaveManager.set_setting("debug_date_override", tomorrow)
				SaveManager.set_setting("last_scheduled_load_date", "")
				print("🧪 DEBUG: Jumping to next day: %s" % date_key)
				if task_count > 0:
					print("  Found %d scheduled task(s) for this date" % task_count)
					Toast.show_toast("🧪 Tomorrow: %d task(s)" % task_count, 2.0)
				else:
					print("  No scheduled tasks for this date")
					Toast.show_toast("🧪 Tomorrow (no tasks)", 2.0)
				get_tree().reload_current_scene()
			KEY_PERIOD:
				debug_date_override = {}
				SaveManager.set_setting("debug_date_override", {})
				SaveManager.set_setting("last_scheduled_load_date", "")
				var real = Time.get_datetime_dict_from_system()
				print("🧪 DEBUG: Reset to real date: %04d-%02d-%02d" % [real.year, real.month, real.day])
				Toast.show_toast("🧪 Back to today", 2.0)
				get_tree().reload_current_scene()

# ============================================
# CLEANUP - SAVE ON EXIT
# ============================================

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if is_scheduling_mode:
				_save_scheduled_tasks_for_date()
				print("📱 Scheduled tasks saved (app paused/closed)")
			else:
				save_all_tasks()
			SessionManager.save_session_data()
			print("✓ Tasks and session saved on exit/pause")
