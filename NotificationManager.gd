# Filename: NotificationManager.gd
# Comprehensive local notification system for BingoTask app
# Integrates with godot-notification-scheduler plugin (with fallback stub)
extends Node

# ============================================
# NOTIFICATION ID CONSTANTS
# ============================================

const ID_NO_TASKS = 1000
const ID_NO_PROGRESS = 2000
const ID_HOURLY_PROGRESS = 3000
const ID_DAILY_AM_BASE = 4000  # Format: 4000 + date hash
const ID_DAILY_PM_BASE = 5000  # Format: 5000 + date hash
const ID_DEADLINE_5MIN = 6000
const ID_DEADLINE_1MIN = 6001
const ID_DEADLINE_EXPIRED = 6002

# ============================================
# TIME INTERVALS (Production vs Debug)
# ============================================

# Production intervals (in seconds)
const PROD_NO_TASKS_INTERVAL = 7200      # 2 hours
const PROD_NO_PROGRESS_INTERVAL = 10800  # 3 hours
const PROD_HOURLY_PROGRESS_INTERVAL = 3600  # 1 hour
const PROD_DEADLINE_5MIN = 300           # 5 minutes before deadline
const PROD_DEADLINE_1MIN = 60            # 1 minute before deadline

# Debug intervals (short for testing)
const DEBUG_NO_TASKS_INTERVAL = 10       # 10 seconds
const DEBUG_NO_PROGRESS_INTERVAL = 15    # 15 seconds
const DEBUG_HOURLY_PROGRESS_INTERVAL = 7 # 7 seconds
const DEBUG_DEADLINE_5MIN = 30           # 30 seconds
const DEBUG_DEADLINE_1MIN = 15           # 15 seconds
const DEBUG_DEADLINE_EXPIRED = 10        # 10 seconds

# Daily reminder times (hours in 24h format)
const DAILY_AM_HOUR = 6   # 6:00 AM
const DAILY_PM_HOUR = 18  # 6:00 PM

# ============================================
# NO TASKS MESSAGES
# ============================================

const NO_TASKS_MESSAGES = [
	"You haven't planned anything yet! Add your first task to get started.",
	"A goal is a dream with a deadline. What's your first move?",
	"Success starts with a single task. Plan for progress!",
	"Make today count—write down a goal!",
	"Start small and win big. Add a Bingo!"
]

# ============================================
# STATE VARIABLES
# ============================================

var debug_mode: bool = false
var has_tasks: bool = false
var total_tasks: int = 0
var completed_tasks: int = 0
var last_completion_time: float = 0.0
var session_deadline_enabled: bool = false
var session_deadline_time: float = 0.0

# Notification scheduler reference (plugin or stub)
var notification_scheduler = null
var plugin_available: bool = false

# State persistence keys
const SAVE_KEY_HAS_TASKS = "notif_has_tasks"
const SAVE_KEY_TOTAL_TASKS = "notif_total_tasks"
const SAVE_KEY_COMPLETED_TASKS = "notif_completed_tasks"
const SAVE_KEY_LAST_COMPLETION = "notif_last_completion"
const SAVE_KEY_DEBUG_MODE = "notif_debug_mode"

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Check for debug mode
	debug_mode = OS.is_debug_build()
	
	# Try to load the notification scheduler plugin
	_init_notification_scheduler()
	
	# Load persisted state
	_load_state()
	
	# Schedule initial notifications based on current state
	call_deferred("_schedule_initial_notifications")
	
	print("✓ NotificationManager initialized (Debug: %s, Plugin: %s)" % [debug_mode, plugin_available])

func _init_notification_scheduler():
	"""Initialize the notification scheduler plugin or use stub"""
	# Try to get the plugin singleton
	if Engine.has_singleton("GodotNotificationScheduler"):
		notification_scheduler = Engine.get_singleton("GodotNotificationScheduler")
		plugin_available = true
		print("  ✓ Notification scheduler plugin loaded")
	else:
		# Use stub implementation
		notification_scheduler = NotificationStub.new()
		plugin_available = false
		print("  ⚠️ Using notification stub (plugin not available)")

func _schedule_initial_notifications():
	"""Schedule notifications based on current app state"""
	if not has_tasks:
		schedule_no_tasks_reminder()
	elif completed_tasks < total_tasks:
		schedule_hourly_progress_reminder()
		schedule_no_progress_reminder()

# ============================================
# INPUT HANDLING (Debug Mode Toggle)
# ============================================

func _input(event):
	# Desktop: Ctrl+Shift+N to toggle debug mode
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N and event.ctrl_pressed and event.shift_pressed:
			_toggle_debug_mode()
	
	# Mobile: 3-finger tap to toggle debug mode
	if event is InputEventScreenTouch:
		if event.pressed and _count_touches() >= 3:
			_toggle_debug_mode()

var _touch_count: int = 0

func _count_touches() -> int:
	return _touch_count

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_state()

func _unhandled_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_count += 1
		else:
			_touch_count = max(0, _touch_count - 1)

func _toggle_debug_mode():
	debug_mode = !debug_mode
	_save_state()
	
	if Toast != null:
		Toast.show_toast("🔔 Notifications: %s mode" % ("DEBUG" if debug_mode else "PRODUCTION"), 2.0)
	
	print("🔔 Notification debug mode: %s" % debug_mode)
	
	# Reschedule all notifications with new intervals
	_reschedule_all_notifications()

# ============================================
# PUBLIC API - Task Management
# ============================================

func on_task_added():
	"""Called when a task is added to the board"""
	var had_no_tasks = not has_tasks
	has_tasks = true
	total_tasks += 1
	_save_state()
	
	# Cancel "no tasks" reminder since user has tasks now
	if had_no_tasks:
		cancel_notification(ID_NO_TASKS)
		print("🔔 Cancelled no-tasks reminder (first task added)")
		
		# Schedule progress reminders
		schedule_hourly_progress_reminder()
		schedule_no_progress_reminder()

func on_task_completed():
	"""Called when a task is marked as completed"""
	completed_tasks += 1
	last_completion_time = Time.get_unix_time_from_system()
	_save_state()
	
	# Reset no-progress timer (user is making progress)
	cancel_notification(ID_NO_PROGRESS)
	
	# Check if all tasks completed
	if completed_tasks >= total_tasks:
		# All tasks done! Cancel progress reminders
		cancel_notification(ID_HOURLY_PROGRESS)
		cancel_notification(ID_NO_PROGRESS)
		print("🔔 All tasks completed! Cancelled progress reminders")
	else:
		# Reschedule no-progress reminder (timer resets after each completion)
		schedule_no_progress_reminder()

func update_progress(new_total: int, new_completed: int):
	"""Update task counts and reschedule notifications accordingly"""
	var was_all_completed = (completed_tasks >= total_tasks and total_tasks > 0)
	
	total_tasks = new_total
	completed_tasks = new_completed
	has_tasks = total_tasks > 0
	_save_state()
	
	# Update notifications based on new state
	if not has_tasks:
		# No tasks - schedule no-tasks reminder
		cancel_notification(ID_HOURLY_PROGRESS)
		cancel_notification(ID_NO_PROGRESS)
		schedule_no_tasks_reminder()
	elif completed_tasks >= total_tasks:
		# All completed - cancel progress reminders
		cancel_notification(ID_HOURLY_PROGRESS)
		cancel_notification(ID_NO_PROGRESS)
		if not was_all_completed:
			print("🔔 All tasks completed!")
	else:
		# Tasks in progress - ensure reminders are scheduled
		cancel_notification(ID_NO_TASKS)
		schedule_hourly_progress_reminder()

func reset_all():
	"""Reset all notification state (e.g., when board is cleared)"""
	has_tasks = false
	total_tasks = 0
	completed_tasks = 0
	last_completion_time = 0.0
	_save_state()
	
	# Cancel all recurring notifications
	cancel_notification(ID_NO_TASKS)
	cancel_notification(ID_NO_PROGRESS)
	cancel_notification(ID_HOURLY_PROGRESS)
	
	# Schedule no-tasks reminder
	schedule_no_tasks_reminder()
	print("🔔 Notification state reset")

# ============================================
# PUBLIC API - Daily Reminders (Calendar)
# ============================================

func schedule_daily_reminders(date_key: String, task_count: int):
	"""Schedule 6 AM and 6 PM reminders for a specific date"""
	if task_count <= 0:
		cancel_daily_reminders(date_key)
		return
	
	# Parse date key (YYYY-MM-DD format)
	var parts = date_key.split("-")
	if parts.size() != 3:
		print("⚠️ Invalid date key format: %s" % date_key)
		return
	
	var year = int(parts[0])
	var month = int(parts[1])
	var day = int(parts[2])
	
	# Generate unique IDs for this date
	var date_hash = _get_date_hash(date_key)
	var am_id = "%d_%s" % [ID_DAILY_AM_BASE, date_key.replace("-", "")]
	var pm_id = "%d_%s" % [ID_DAILY_PM_BASE, date_key.replace("-", "")]
	
	var message = "You have %d task(s) scheduled for today. Let's get started!" % task_count
	
	# Calculate timestamps for 6 AM and 6 PM on the given date
	var am_time = _get_timestamp_for_datetime(year, month, day, DAILY_AM_HOUR, 0, 0)
	var pm_time = _get_timestamp_for_datetime(year, month, day, DAILY_PM_HOUR, 0, 0)
	
	var current_time = Time.get_unix_time_from_system()
	
	# Schedule AM reminder if in the future
	if am_time > current_time:
		var delay = am_time - current_time
		_schedule_notification(am_id, "BingoTask - Morning Reminder", message, delay)
		print("🔔 Scheduled AM reminder for %s (in %ds)" % [date_key, int(delay)])
	
	# Schedule PM reminder if in the future
	if pm_time > current_time:
		var delay = pm_time - current_time
		_schedule_notification(pm_id, "BingoTask - Evening Reminder", message, delay)
		print("🔔 Scheduled PM reminder for %s (in %ds)" % [date_key, int(delay)])

func cancel_daily_reminders(date_key: String):
	"""Cancel daily reminders for a specific date"""
	var am_id = "%d_%s" % [ID_DAILY_AM_BASE, date_key.replace("-", "")]
	var pm_id = "%d_%s" % [ID_DAILY_PM_BASE, date_key.replace("-", "")]
	
	cancel_notification_by_string_id(am_id)
	cancel_notification_by_string_id(pm_id)
	print("🔔 Cancelled daily reminders for %s" % date_key)

func update_daily_reminders(date_key: String, task_count: int):
	"""Update daily reminders when task count changes"""
	cancel_daily_reminders(date_key)
	if task_count > 0:
		schedule_daily_reminders(date_key, task_count)

# ============================================
# PUBLIC API - Deadline Notifications (Session)
# ============================================

func on_session_started(deadline_seconds: float = 0.0):
	"""Called when a session starts with optional deadline"""
	if deadline_seconds > 0:
		session_deadline_enabled = true
		session_deadline_time = Time.get_unix_time_from_system() + deadline_seconds
		_schedule_deadline_notifications(deadline_seconds)
		print("🔔 Session started with deadline: %ds" % int(deadline_seconds))
	else:
		session_deadline_enabled = false

func on_session_stopped():
	"""Called when session stops - cancel deadline notifications"""
	session_deadline_enabled = false
	cancel_notification(ID_DEADLINE_5MIN)
	cancel_notification(ID_DEADLINE_1MIN)
	cancel_notification(ID_DEADLINE_EXPIRED)
	print("🔔 Session stopped - deadline notifications cancelled")

func on_session_paused():
	"""Called when session is paused - cancel deadline notifications"""
	cancel_notification(ID_DEADLINE_5MIN)
	cancel_notification(ID_DEADLINE_1MIN)
	cancel_notification(ID_DEADLINE_EXPIRED)
	print("🔔 Session paused - deadline notifications cancelled")

func on_session_resumed(remaining_seconds: float):
	"""Called when session resumes - reschedule deadline notifications"""
	if session_deadline_enabled and remaining_seconds > 0:
		_schedule_deadline_notifications(remaining_seconds)
		print("🔔 Session resumed - rescheduled deadline notifications (%ds remaining)" % int(remaining_seconds))

func _schedule_deadline_notifications(deadline_seconds: float):
	"""Schedule deadline warning notifications"""
	var warning_5min = _get_interval(PROD_DEADLINE_5MIN, DEBUG_DEADLINE_5MIN)
	var warning_1min = _get_interval(PROD_DEADLINE_1MIN, DEBUG_DEADLINE_1MIN)
	
	# Schedule 5-minute warning
	if deadline_seconds > warning_5min:
		var delay = deadline_seconds - warning_5min
		_schedule_notification(
			str(ID_DEADLINE_5MIN),
			"BingoTask - Deadline Warning",
			"⏰ 5 minutes left to complete your session!",
			delay
		)
	
	# Schedule 1-minute warning
	if deadline_seconds > warning_1min:
		var delay = deadline_seconds - warning_1min
		_schedule_notification(
			str(ID_DEADLINE_1MIN),
			"BingoTask - Final Warning",
			"⏰ Only 1 minute remaining! Finish strong!",
			delay
		)
	
	# Schedule deadline expired notification
	if deadline_seconds > 0:
		_schedule_notification(
			str(ID_DEADLINE_EXPIRED),
			"BingoTask - Time's Up",
			"⏰ Time's up! Session deadline reached.",
			deadline_seconds
		)

# ============================================
# NOTIFICATION SCHEDULING
# ============================================

func schedule_no_tasks_reminder():
	"""Schedule reminder for users who haven't added any tasks"""
	var interval = _get_interval(PROD_NO_TASKS_INTERVAL, DEBUG_NO_TASKS_INTERVAL)
	var message = NO_TASKS_MESSAGES[randi() % NO_TASKS_MESSAGES.size()]
	
	_schedule_notification(
		str(ID_NO_TASKS),
		"BingoTask - Get Started!",
		message,
		interval,
		true  # Repeating
	)
	print("🔔 Scheduled no-tasks reminder (interval: %ds)" % interval)

func schedule_no_progress_reminder():
	"""Schedule reminder for users with no progress in 3 hours"""
	if total_tasks <= 0 or completed_tasks >= total_tasks:
		return
	
	var interval = _get_interval(PROD_NO_PROGRESS_INTERVAL, DEBUG_NO_PROGRESS_INTERVAL)
	var remaining = total_tasks - completed_tasks
	var message = "No progress for a while. You have %d task(s) waiting!" % remaining
	
	_schedule_notification(
		str(ID_NO_PROGRESS),
		"BingoTask - Reminder",
		message,
		interval,
		false  # One-time (resets after completion)
	)
	print("🔔 Scheduled no-progress reminder (interval: %ds)" % interval)

func schedule_hourly_progress_reminder():
	"""Schedule hourly progress update reminders"""
	if total_tasks <= 0 or completed_tasks >= total_tasks:
		return
	
	var interval = _get_interval(PROD_HOURLY_PROGRESS_INTERVAL, DEBUG_HOURLY_PROGRESS_INTERVAL)
	var message = _get_progress_message()
	
	_schedule_notification(
		str(ID_HOURLY_PROGRESS),
		"BingoTask - Progress Update",
		message,
		interval,
		true  # Repeating
	)
	print("🔔 Scheduled hourly progress reminder (interval: %ds)" % interval)

func _get_progress_message() -> String:
	"""Get adaptive message based on completion percentage"""
	if total_tasks <= 0:
		return "Let's get started—your tasks await!"
	
	var percent = int((completed_tasks * 100.0) / total_tasks)
	
	if percent == 0:
		return "Let's get started—your tasks await!"
	elif percent < 50:
		return "You've completed %d%% of your tasks. Keep going!" % percent
	else:
		return "Awesome! %d%% done. Nearly there!" % percent

# ============================================
# LOW-LEVEL NOTIFICATION FUNCTIONS
# ============================================

func _schedule_notification(id: String, title: String, message: String, delay_seconds: float, repeating: bool = false):
	"""Schedule a notification through the plugin or stub"""
	if notification_scheduler == null:
		print("⚠️ No notification scheduler available")
		return
	
	# Convert string ID to int for the plugin (use larger modulo to reduce collision risk)
	var int_id = abs(id.hash()) % 2147483647  # Max int32 range
	
	if plugin_available:
		# Use actual plugin
		notification_scheduler.schedule(
			int_id,
			title,
			message,
			int(delay_seconds),
			repeating
		)
	else:
		# Use stub (just logs)
		notification_scheduler.schedule(int_id, title, message, int(delay_seconds), repeating)
	
	print("  📅 Notification scheduled: ID=%s, delay=%ds, repeat=%s" % [id, int(delay_seconds), repeating])

func cancel_notification(id: int):
	"""Cancel a notification by numeric ID"""
	if notification_scheduler == null:
		return
	
	if plugin_available:
		notification_scheduler.cancel(id)
	else:
		notification_scheduler.cancel(id)
	
	print("  ❌ Notification cancelled: ID=%d" % id)

func cancel_notification_by_string_id(id: String):
	"""Cancel a notification by string ID"""
	var int_id = abs(id.hash()) % 2147483647
	cancel_notification(int_id)

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_interval(prod_interval: float, debug_interval: float) -> float:
	"""Get appropriate interval based on debug mode"""
	return debug_interval if debug_mode else prod_interval

func _get_date_hash(date_key: String) -> int:
	"""Generate a hash for date-based notification IDs"""
	return date_key.hash() % 10000

func _get_timestamp_for_datetime(year: int, month: int, day: int, hour: int, minute: int, second: int) -> float:
	"""Convert datetime components to Unix timestamp"""
	var datetime = {
		"year": year,
		"month": month,
		"day": day,
		"hour": hour,
		"minute": minute,
		"second": second
	}
	return Time.get_unix_time_from_datetime_dict(datetime)

func _reschedule_all_notifications():
	"""Reschedule all active notifications with new intervals (after mode change)"""
	# Cancel existing
	cancel_notification(ID_NO_TASKS)
	cancel_notification(ID_NO_PROGRESS)
	cancel_notification(ID_HOURLY_PROGRESS)
	
	# Reschedule based on state
	if not has_tasks:
		schedule_no_tasks_reminder()
	elif completed_tasks < total_tasks:
		schedule_hourly_progress_reminder()
		schedule_no_progress_reminder()

# ============================================
# STATE PERSISTENCE
# ============================================

func _save_state():
	"""Save notification state to SaveManager"""
	SaveManager.set_setting(SAVE_KEY_HAS_TASKS, has_tasks)
	SaveManager.set_setting(SAVE_KEY_TOTAL_TASKS, total_tasks)
	SaveManager.set_setting(SAVE_KEY_COMPLETED_TASKS, completed_tasks)
	SaveManager.set_setting(SAVE_KEY_LAST_COMPLETION, last_completion_time)
	SaveManager.set_setting(SAVE_KEY_DEBUG_MODE, debug_mode)

func _load_state():
	"""Load notification state from SaveManager"""
	has_tasks = SaveManager.get_setting(SAVE_KEY_HAS_TASKS, false)
	total_tasks = SaveManager.get_setting(SAVE_KEY_TOTAL_TASKS, 0)
	completed_tasks = SaveManager.get_setting(SAVE_KEY_COMPLETED_TASKS, 0)
	last_completion_time = SaveManager.get_setting(SAVE_KEY_LAST_COMPLETION, 0.0)
	
	# Load debug mode but override with OS check if in debug build
	var saved_debug = SaveManager.get_setting(SAVE_KEY_DEBUG_MODE, false)
	if OS.is_debug_build():
		debug_mode = saved_debug
	
	print("  Loaded state: has_tasks=%s, total=%d, completed=%d" % [has_tasks, total_tasks, completed_tasks])

# ============================================
# NOTIFICATION STUB (Fallback when plugin not available)
# ============================================

class NotificationStub:
	"""Stub implementation for notification scheduling when plugin is not available"""
	
	var scheduled_notifications: Dictionary = {}
	
	func schedule(id: int, title: String, message: String, delay_seconds: int, repeating: bool = false):
		scheduled_notifications[id] = {
			"title": title,
			"message": message,
			"delay": delay_seconds,
			"repeating": repeating,
			"scheduled_at": Time.get_unix_time_from_system()
		}
		print("    [STUB] Scheduled: %s - %s (delay: %ds, repeat: %s)" % [title, message.left(30), delay_seconds, repeating])
	
	func cancel(id: int):
		if scheduled_notifications.has(id):
			scheduled_notifications.erase(id)
		print("    [STUB] Cancelled notification ID: %d" % id)
	
	func get_scheduled() -> Dictionary:
		return scheduled_notifications
