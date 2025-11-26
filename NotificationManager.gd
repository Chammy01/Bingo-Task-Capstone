extends Node

# ============================================
# NOTIFICATION IDS
# ============================================

const NOTIFICATION_ID_NO_TASKS = 1000
const NOTIFICATION_ID_NO_PROGRESS = 2000
const NOTIFICATION_ID_HOURLY_PROGRESS = 3000
const NOTIFICATION_ID_DAILY_AM_BASE = 4000
const NOTIFICATION_ID_DAILY_PM_BASE = 5000

# ============================================
# CHANNEL CONFIGURATION
# ============================================

const CHANNEL_ID = "bingo_task_reminders"
const CHANNEL_NAME = "Task Reminders"
const CHANNEL_DESCRIPTION = "Notifications to help you stay on track with your tasks"

# ============================================
# INTERVAL CONSTANTS (in seconds)
# ============================================

# Production intervals
const INTERVAL_NO_TASKS_PROD = 7200  # 2 hours
const INTERVAL_NO_PROGRESS_PROD = 10800  # 3 hours
const INTERVAL_HOURLY_PROGRESS_PROD = 3600  # 1 hour

# Debug intervals
const INTERVAL_NO_TASKS_DEBUG = 10  # 10 seconds
const INTERVAL_NO_PROGRESS_DEBUG = 15  # 15 seconds
const INTERVAL_HOURLY_PROGRESS_DEBUG = 7  # 7 seconds

# ============================================
# NOTIFICATION MESSAGES
# ============================================

const NO_TASKS_MESSAGES = [
	"You haven't planned anything yet! Add your first task to get started.",
	"A goal is a dream with a deadline. What's your first move?",
	"Success starts with a single task. Plan for progress!",
	"Make today count—write down a goal!",
	"Start small and win big. Add a Bingo!"
]

# ============================================
# STATE TRACKING
# ============================================

var notification_scheduler: NotificationScheduler = null
var is_initialized: bool = false
var has_permission: bool = false
var debug_mode: bool = false
var no_progress_timer: Timer = null
var has_tasks: bool = false
var has_completed_task: bool = false
var last_task_count: int = 0
var last_completed_count: int = 0

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	debug_mode = SaveManager.get_setting("notification_debug_mode", false)
	_setup_notification_scheduler()
	_create_no_progress_timer()
	print("✓ NotificationManager initialized (Debug Mode: %s)" % debug_mode)

func _setup_notification_scheduler():
	notification_scheduler = NotificationScheduler.new()
	add_child(notification_scheduler)
	
	notification_scheduler.initialization_completed.connect(_on_initialization_completed)
	notification_scheduler.notification_opened.connect(_on_notification_opened)
	notification_scheduler.notification_dismissed.connect(_on_notification_dismissed)
	notification_scheduler.permission_granted.connect(_on_permission_granted)
	notification_scheduler.permission_denied.connect(_on_permission_denied)
	
	notification_scheduler.initialize()

func _create_no_progress_timer():
	no_progress_timer = Timer.new()
	no_progress_timer.one_shot = true
	no_progress_timer.timeout.connect(_on_no_progress_timeout)
	add_child(no_progress_timer)

# ============================================
# SIGNAL HANDLERS
# ============================================

func _on_initialization_completed():
	is_initialized = true
	_debug_log("📲 Notification plugin initialized")
	
	if notification_scheduler.has_post_notifications_permission():
		has_permission = true
		_create_notification_channel()
	else:
		_debug_log("⚠️ No notification permission, requesting...")
		notification_scheduler.request_post_notifications_permission()

func _on_permission_granted(permission_name: String):
	has_permission = true
	_debug_log("✓ Permission granted: %s" % permission_name)
	_create_notification_channel()

func _on_permission_denied(permission_name: String):
	has_permission = false
	_debug_log("⚠️ Permission denied: %s" % permission_name)

func _on_notification_opened(notification_data: NotificationData):
	_debug_log("📬 Notification opened: ID=%d" % notification_data.get_id())

func _on_notification_dismissed(notification_data: NotificationData):
	_debug_log("🗑️ Notification dismissed: ID=%d" % notification_data.get_id())

# ============================================
# CHANNEL CREATION
# ============================================

func _create_notification_channel():
	var channel = NotificationChannel.new() \
		.set_id(CHANNEL_ID) \
		.set_name(CHANNEL_NAME) \
		.set_description(CHANNEL_DESCRIPTION) \
		.set_importance(NotificationChannel.Importance.DEFAULT)
	
	var result = notification_scheduler.create_notification_channel(channel)
	
	if result == OK:
		_debug_log("✓ Notification channel created: %s" % CHANNEL_ID)
	elif result == ERR_ALREADY_EXISTS:
		_debug_log("✓ Notification channel already exists: %s" % CHANNEL_ID)
	else:
		_debug_log("⚠️ Failed to create notification channel: %d" % result)

# ============================================
# PUBLIC API - TASK EVENTS
# ============================================

func on_task_added():
	"""Called when a task is added to the board"""
	if not _can_schedule_notifications():
		return
	
	has_tasks = true
	_debug_log("📝 Task added - cancelling 'no tasks' notifications")
	_cancel_notification(NOTIFICATION_ID_NO_TASKS)
	
	# Start no progress timer if not already running
	if not has_completed_task:
		_start_no_progress_timer()
	
	# Schedule hourly progress reminder
	_schedule_hourly_progress_reminder()

func on_task_completed():
	"""Called when a task is completed"""
	if not _can_schedule_notifications():
		return
	
	has_completed_task = true
	_debug_log("✅ Task completed - resetting no progress timer")
	
	# Reset no progress timer
	_cancel_notification(NOTIFICATION_ID_NO_PROGRESS)
	_start_no_progress_timer()

func update_progress(completed_count: int, total_count: int):
	"""Called when task progress changes"""
	if not _can_schedule_notifications():
		return
	
	last_completed_count = completed_count
	last_task_count = total_count
	
	_debug_log("📊 Progress updated: %d/%d" % [completed_count, total_count])
	
	# If all tasks completed, cancel all progress reminders
	if completed_count >= total_count and total_count > 0:
		_debug_log("🎉 All tasks completed - cancelling progress reminders")
		_cancel_notification(NOTIFICATION_ID_HOURLY_PROGRESS)
		_cancel_notification(NOTIFICATION_ID_NO_PROGRESS)
		if no_progress_timer:
			no_progress_timer.stop()
	elif completed_count > 0:
		# Has made some progress
		has_completed_task = true

func check_no_tasks_state():
	"""Check if user has no tasks and schedule notification if needed"""
	if not _can_schedule_notifications():
		return
	
	# This should be called on app open
	var saved_data = SaveManager.load_tasks()
	var has_any_tasks = false
	
	for task in saved_data:
		if task.has("text") and task.text != "" and task.text != "Tap to add task":
			has_any_tasks = true
			break
	
	if not has_any_tasks:
		has_tasks = false
		_debug_log("⚠️ No tasks found - scheduling 'no tasks' reminder")
		_schedule_no_tasks_notification()
	else:
		has_tasks = true

# ============================================
# PUBLIC API - DAILY REMINDERS
# ============================================

func schedule_daily_reminders(date_key: String, task_count: int):
	"""Schedule 6 AM and 6 PM reminders for a future date"""
	if not _can_schedule_notifications():
		return
	
	if task_count == 0:
		_debug_log("⚠️ No tasks to schedule reminders for date: %s" % date_key)
		return
	
	# Parse date_key (format: "YYYY-MM-DD")
	var parts = date_key.split("-")
	if parts.size() != 3:
		_debug_log("⚠️ Invalid date key format: %s" % date_key)
		return
	
	var year = int(parts[0])
	var month = int(parts[1])
	var day = int(parts[2])
	
	var now = Time.get_datetime_dict_from_system()
	var current_unix = Time.get_unix_time_from_datetime_dict(now)
	
	# Calculate 6 AM for the target date
	var am_time = {
		"year": year, "month": month, "day": day,
		"hour": 6, "minute": 0, "second": 0
	}
	var am_unix = Time.get_unix_time_from_datetime_dict(am_time)
	var am_delay = int(am_unix - current_unix)
	
	# Calculate 6 PM for the target date
	var pm_time = {
		"year": year, "month": month, "day": day,
		"hour": 18, "minute": 0, "second": 0
	}
	var pm_unix = Time.get_unix_time_from_datetime_dict(pm_time)
	var pm_delay = int(pm_unix - current_unix)
	
	# Get day of year for unique IDs
	var day_of_year = _get_day_of_year(year, month, day)
	
	# Schedule AM reminder if in future
	if am_delay > 0:
		var am_id = NOTIFICATION_ID_DAILY_AM_BASE + day_of_year
		var message = "You have %d task(s) scheduled for today. Let's get started!" % task_count
		_schedule_notification(am_id, "Morning Task Reminder 🌅", message, am_delay, 0)
		_debug_log("📅 Scheduled 6 AM reminder for %s (ID: %d, delay: %ds)" % [date_key, am_id, am_delay])
	
	# Schedule PM reminder if in future
	if pm_delay > 0:
		var pm_id = NOTIFICATION_ID_DAILY_PM_BASE + day_of_year
		var message = "You have %d task(s) scheduled for today. Let's get started!" % task_count
		_schedule_notification(pm_id, "Evening Task Reminder 🌆", message, pm_delay, 0)
		_debug_log("📅 Scheduled 6 PM reminder for %s (ID: %d, delay: %ds)" % [date_key, pm_id, pm_delay])

func cancel_daily_reminders(date_key: String):
	"""Cancel daily reminders for a specific date"""
	if not is_initialized:
		return
	
	# Parse date_key
	var parts = date_key.split("-")
	if parts.size() != 3:
		return
	
	var year = int(parts[0])
	var month = int(parts[1])
	var day = int(parts[2])
	var day_of_year = _get_day_of_year(year, month, day)
	
	var am_id = NOTIFICATION_ID_DAILY_AM_BASE + day_of_year
	var pm_id = NOTIFICATION_ID_DAILY_PM_BASE + day_of_year
	
	_cancel_notification(am_id)
	_cancel_notification(pm_id)
	_debug_log("📅 Cancelled daily reminders for %s" % date_key)

# ============================================
# PRIVATE - NOTIFICATION SCHEDULING
# ============================================

func _schedule_no_tasks_notification():
	var message = NO_TASKS_MESSAGES[randi() % NO_TASKS_MESSAGES.size()]
	var interval = INTERVAL_NO_TASKS_DEBUG if debug_mode else INTERVAL_NO_TASKS_PROD
	_schedule_notification(NOTIFICATION_ID_NO_TASKS, "No Tasks Yet 📋", message, interval, interval)

func _schedule_hourly_progress_reminder():
	if last_task_count == 0:
		return
	
	var completion_percent = (float(last_completed_count) / float(last_task_count)) * 100.0
	var message = _get_progress_message(completion_percent)
	var interval = INTERVAL_HOURLY_PROGRESS_DEBUG if debug_mode else INTERVAL_HOURLY_PROGRESS_PROD
	
	_schedule_notification(NOTIFICATION_ID_HOURLY_PROGRESS, "Progress Check 📊", message, interval, interval)

func _get_progress_message(completion_percent: float) -> String:
	if completion_percent == 0:
		return "Let's get started—your tasks await!"
	elif completion_percent < 50:
		return "You've completed %.0f%% of your tasks. Keep going!" % completion_percent
	else:
		return "Awesome! %.0f%% done. Nearly there!" % completion_percent

func _start_no_progress_timer():
	if not no_progress_timer:
		return
	
	var interval = INTERVAL_NO_PROGRESS_DEBUG if debug_mode else INTERVAL_NO_PROGRESS_PROD
	no_progress_timer.start(interval)
	_debug_log("⏱️ No progress timer started (%ds)" % interval)

func _on_no_progress_timeout():
	if not _can_schedule_notifications():
		return
	
	if last_task_count == 0:
		return
	
	var message = "No progress for a while. You have %d tasks waiting!" % last_task_count
	_schedule_notification(NOTIFICATION_ID_NO_PROGRESS, "No Progress ⏰", message, 0, 0)
	_debug_log("📬 No progress notification scheduled")

func _schedule_notification(id: int, title: String, content: String, delay: int, interval: int):
	if not _can_schedule_notifications():
		return
	
	var data = NotificationData.new() \
		.set_id(id) \
		.set_channel_id(CHANNEL_ID) \
		.set_title(title) \
		.set_content(content) \
		.set_delay(delay)
	
	if interval > 0:
		data.set_interval(interval)
	
	var result = notification_scheduler.schedule(data)
	
	if result == OK:
		_debug_log("✓ Scheduled notification ID=%d, delay=%ds, interval=%ds" % [id, delay, interval])
		if debug_mode:
			Toast.show_toast("🔔 Notification scheduled (ID: %d)" % id, 2.0)
	else:
		_debug_log("⚠️ Failed to schedule notification ID=%d: %d" % [id, result])

func _cancel_notification(id: int):
	if not is_initialized or not notification_scheduler:
		return
	
	var result = notification_scheduler.cancel(id)
	
	if result == OK:
		_debug_log("✓ Cancelled notification ID=%d" % id)
		if debug_mode:
			Toast.show_toast("🔕 Notification cancelled (ID: %d)" % id, 2.0)
	else:
		_debug_log("⚠️ Failed to cancel notification ID=%d: %d" % [id, result])

# ============================================
# PRIVATE - HELPERS
# ============================================

func _can_schedule_notifications() -> bool:
	return is_initialized and has_permission

func _get_day_of_year(year: int, month: int, day: int) -> int:
	"""Calculate day of year (1-366)"""
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	
	# Check for leap year
	if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
		days_in_month[1] = 29
	
	var day_of_year = day
	for i in range(month - 1):
		day_of_year += days_in_month[i]
	
	return day_of_year

func _debug_log(message: String):
	if debug_mode:
		print("🔔 [NotificationManager] %s" % message)
	else:
		print("🔔 %s" % message)

# ============================================
# PUBLIC API - SETTINGS
# ============================================

func set_debug_mode(enabled: bool):
	debug_mode = enabled
	SaveManager.set_setting("notification_debug_mode", enabled)
	_debug_log("Debug mode %s" % ("enabled" if enabled else "disabled"))
	
	# Reschedule notifications with new intervals if currently scheduled
	if has_tasks and not has_completed_task:
		_start_no_progress_timer()
	if last_task_count > 0:
		_schedule_hourly_progress_reminder()

func get_debug_mode() -> bool:
	return debug_mode

# ============================================
# DEBUG INPUT HANDLER
# ============================================

func _input(event):
	"""Handle keyboard shortcuts for debug mode toggle"""
	if event is InputEventKey and event.pressed:
		# Ctrl+Shift+N to toggle notification debug mode
		if event.keycode == KEY_N and event.ctrl_pressed and event.shift_pressed:
			set_debug_mode(not debug_mode)
			var status = "ENABLED" if debug_mode else "DISABLED"
			Toast.show_toast("🔔 Notification Debug Mode %s" % status, 2.0)
			print("🔔 Notification debug mode toggled: %s" % status)
