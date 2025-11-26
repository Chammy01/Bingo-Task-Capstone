# Filename: NotificationManager.gd
# Comprehensive notification system for BingoTask app
extends Node

# ============================================
# NOTIFICATION IDS
# ============================================

const NOTIFICATION_ID_NO_TASKS = 1000
const NOTIFICATION_ID_NO_PROGRESS = 2000
const NOTIFICATION_ID_HOURLY_PROGRESS = 3000
const NOTIFICATION_ID_DAILY_AM_BASE = 4000  # 4000+ for each date
const NOTIFICATION_ID_DAILY_PM_BASE = 5000  # 5000+ for each date
const NOTIFICATION_ID_DEADLINE_WARNING = 6000
const NOTIFICATION_ID_DEADLINE_EXPIRED = 6001

# ============================================
# PRODUCTION INTERVALS (seconds)
# ============================================

const NO_TASKS_INTERVAL_PROD = 7200      # 2 hours
const NO_PROGRESS_INTERVAL_PROD = 10800  # 3 hours
const HOURLY_PROGRESS_INTERVAL_PROD = 3600  # 1 hour
const DEADLINE_5MIN_PROD = 300   # 5 minutes
const DEADLINE_1MIN_PROD = 60    # 1 minute

# ============================================
# DEBUG INTERVALS (seconds)
# ============================================

const NO_TASKS_INTERVAL_DEBUG = 10       # 10 seconds
const NO_PROGRESS_INTERVAL_DEBUG = 15    # 15 seconds
const HOURLY_PROGRESS_INTERVAL_DEBUG = 7 # 7 seconds
const DEADLINE_5MIN_DEBUG = 30    # 30 seconds
const DEADLINE_1MIN_DEBUG = 15    # 15 seconds

# ============================================
# NO TASKS MESSAGES (Randomized)
# ============================================

const NO_TASKS_MESSAGES = [
	"You haven't planned anything yet! Add your first task to get started.",
	"A goal is a dream with a deadline. What's your first move?",
	"Success starts with a single task. Plan for progress!",
	"Make today count—write down a goal!",
	"Start small and win big. Add a Bingo!"
]

# ============================================
# VARIABLES
# ============================================

var debug_mode: bool = false
var no_tasks_timer: Timer
var no_progress_timer: Timer
var hourly_progress_timer: Timer
var deadline_check_timer: Timer

# Progress tracking
var current_completed: int = 0
var current_total: int = 0
var pending_task_count: int = 0

# Deadline tracking
var deadline_active: bool = false
var deadline_total_seconds: float = 0.0
var deadline_5min_warning_shown: bool = false
var deadline_1min_warning_shown: bool = false
var deadline_expired_shown: bool = false

# Daily reminders tracking
var scheduled_notification_ids: Dictionary = {}  # date_key -> [notification_ids]

# Touch tracking for 3-finger tap
var active_touches: Dictionary = {}
var THREE_FINGER_TAP_WINDOW = 0.3  # seconds

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	debug_mode = SaveManager.get_setting("notification_debug_mode", false)
	_create_timers()
	print("✓ NotificationManager initialized (Debug: %s)" % debug_mode)

func _create_timers():
	# No Tasks Timer
	no_tasks_timer = Timer.new()
	no_tasks_timer.one_shot = false
	no_tasks_timer.timeout.connect(_on_no_tasks_timer_timeout)
	add_child(no_tasks_timer)
	
	# No Progress Timer
	no_progress_timer = Timer.new()
	no_progress_timer.one_shot = true
	no_progress_timer.timeout.connect(_on_no_progress_timer_timeout)
	add_child(no_progress_timer)
	
	# Hourly Progress Timer
	hourly_progress_timer = Timer.new()
	hourly_progress_timer.one_shot = false
	hourly_progress_timer.timeout.connect(_on_hourly_progress_timer_timeout)
	add_child(hourly_progress_timer)
	
	# Deadline Check Timer (runs every second when active)
	deadline_check_timer = Timer.new()
	deadline_check_timer.one_shot = false
	deadline_check_timer.wait_time = 1.0
	deadline_check_timer.timeout.connect(_on_deadline_check_timer_timeout)
	add_child(deadline_check_timer)

# ============================================
# DEBUG MODE
# ============================================

func toggle_debug_mode():
	debug_mode = not debug_mode
	SaveManager.set_setting("notification_debug_mode", debug_mode)
	
	if Toast != null:
		if debug_mode:
			Toast.show_toast("🧪 Debug Mode: ON", 2.0)
		else:
			Toast.show_toast("🧪 Debug Mode: OFF", 2.0)
	
	print("🔔 NotificationManager debug mode: %s" % ("ON" if debug_mode else "OFF"))
	
	# Restart any active timers with new intervals
	_restart_active_timers()

func is_debug_mode() -> bool:
	return debug_mode

func get_interval(prod_interval: int, debug_interval: int) -> int:
	return debug_interval if debug_mode else prod_interval

func _restart_active_timers():
	# Restart no_tasks_timer if running
	if not no_tasks_timer.is_stopped():
		var interval = get_interval(NO_TASKS_INTERVAL_PROD, NO_TASKS_INTERVAL_DEBUG)
		no_tasks_timer.stop()
		no_tasks_timer.wait_time = interval
		no_tasks_timer.start()
		print("  ↻ No Tasks timer restarted with %ds interval" % interval)
	
	# Restart no_progress_timer if running
	if not no_progress_timer.is_stopped():
		var interval = get_interval(NO_PROGRESS_INTERVAL_PROD, NO_PROGRESS_INTERVAL_DEBUG)
		no_progress_timer.stop()
		no_progress_timer.wait_time = interval
		no_progress_timer.start()
		print("  ↻ No Progress timer restarted with %ds interval" % interval)
	
	# Restart hourly_progress_timer if running
	if not hourly_progress_timer.is_stopped():
		var interval = get_interval(HOURLY_PROGRESS_INTERVAL_PROD, HOURLY_PROGRESS_INTERVAL_DEBUG)
		hourly_progress_timer.stop()
		hourly_progress_timer.wait_time = interval
		hourly_progress_timer.start()
		print("  ↻ Hourly Progress timer restarted with %ds interval" % interval)

# ============================================
# INPUT HANDLING (3-Finger Tap & Keyboard)
# ============================================

func _input(event):
	# Keyboard shortcut: Ctrl+Shift+N (for desktop testing)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N and event.ctrl_pressed and event.shift_pressed:
			toggle_debug_mode()
			return
	
	# 3-finger tap detection (mobile)
	if event is InputEventScreenTouch:
		_handle_touch(event)

func _handle_touch(event: InputEventScreenTouch):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if event.pressed:
		# Touch started - record it
		active_touches[event.index] = {
			"time": current_time,
			"position": event.position
		}
		
		# Check if we now have exactly 3 simultaneous touches
		if active_touches.size() == 3:
			# Verify all touches are within the time window
			var all_recent = true
			for touch_data in active_touches.values():
				if current_time - touch_data.time > THREE_FINGER_TAP_WINDOW:
					all_recent = false
					break
			
			if all_recent:
				toggle_debug_mode()
				active_touches.clear()
	else:
		# Touch released - remove from tracking
		if event.index in active_touches:
			active_touches.erase(event.index)
		
		# Clean up old touches that are outside the time window
		var touches_to_remove = []
		for index in active_touches.keys():
			if current_time - active_touches[index].time > THREE_FINGER_TAP_WINDOW:
				touches_to_remove.append(index)
		for index in touches_to_remove:
			active_touches.erase(index)

# ============================================
# NO TASKS ADDED NOTIFICATION
# ============================================

func start_no_tasks_reminder():
	var interval = get_interval(NO_TASKS_INTERVAL_PROD, NO_TASKS_INTERVAL_DEBUG)
	no_tasks_timer.wait_time = interval
	no_tasks_timer.start()
	print("🔔 No Tasks reminder started (every %ds)" % interval)

func stop_no_tasks_reminder():
	no_tasks_timer.stop()
	print("🔔 No Tasks reminder stopped")

func _on_no_tasks_timer_timeout():
	var message = _get_random_no_tasks_message()
	_show_notification("📋 Plan Your Day!", message)
	print("🔔 No Tasks notification fired")

func _get_random_no_tasks_message() -> String:
	return NO_TASKS_MESSAGES[randi() % NO_TASKS_MESSAGES.size()]

# ============================================
# NO PROGRESS NOTIFICATION
# ============================================

func start_no_progress_reminder(task_count: int):
	pending_task_count = task_count
	var interval = get_interval(NO_PROGRESS_INTERVAL_PROD, NO_PROGRESS_INTERVAL_DEBUG)
	no_progress_timer.wait_time = interval
	no_progress_timer.start()
	print("🔔 No Progress reminder started (%d tasks waiting, fires in %ds)" % [task_count, interval])

func stop_no_progress_reminder():
	no_progress_timer.stop()
	print("🔔 No Progress reminder stopped")

func reset_no_progress_timer():
	if not no_progress_timer.is_stopped():
		var interval = get_interval(NO_PROGRESS_INTERVAL_PROD, NO_PROGRESS_INTERVAL_DEBUG)
		no_progress_timer.stop()
		no_progress_timer.wait_time = interval
		no_progress_timer.start()
		print("🔔 No Progress timer reset (%ds)" % interval)

func _on_no_progress_timer_timeout():
	var message = "No progress for a while. You have %d task(s) waiting!" % pending_task_count
	_show_notification("⏰ Time to Focus!", message)
	print("🔔 No Progress notification fired")

# ============================================
# HOURLY PROGRESS REMINDERS
# ============================================

func start_hourly_progress_reminder():
	var interval = get_interval(HOURLY_PROGRESS_INTERVAL_PROD, HOURLY_PROGRESS_INTERVAL_DEBUG)
	hourly_progress_timer.wait_time = interval
	hourly_progress_timer.start()
	print("🔔 Hourly Progress reminder started (every %ds)" % interval)

func stop_hourly_progress_reminder():
	hourly_progress_timer.stop()
	print("🔔 Hourly Progress reminder stopped")

func update_progress(completed: int, total: int):
	current_completed = completed
	current_total = total
	pending_task_count = total - completed
	
	# If all tasks completed, stop progress reminders
	if completed >= total and total > 0:
		stop_hourly_progress_reminder()
		stop_no_progress_reminder()
		print("🔔 All tasks completed! Progress reminders stopped")

func _on_hourly_progress_timer_timeout():
	if current_total <= 0:
		return
	
	var percentage = int((float(current_completed) / current_total) * 100)
	var message = _get_progress_message(percentage)
	_show_notification("📊 Progress Update", message)
	print("🔔 Hourly Progress notification fired (%d%%)" % percentage)

func _get_progress_message(percentage: int) -> String:
	if percentage == 0:
		return "Let's get started—your tasks await!"
	elif percentage < 50:
		return "You've completed %d%% of your tasks. Keep going!" % percentage
	else:
		return "Awesome! %d%% done. Nearly there!" % percentage

# ============================================
# DAILY TASK REMINDERS (6 AM & 6 PM)
# NOTE: This feature logs scheduling intent. Full system notification
# functionality requires the godot-notification-scheduler plugin.
# ============================================

func schedule_daily_reminders_for_date(date_key: String, task_count: int):
	if task_count <= 0:
		cancel_daily_reminders_for_date(date_key)
		return
	
	# Parse date_key (YYYY-MM-DD)
	var parts = date_key.split("-")
	if parts.size() != 3:
		print("⚠️ Invalid date_key format: %s" % date_key)
		return
	
	var date = {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2])
	}
	
	var message = "You have %d task(s) scheduled for today. Let's get started!" % task_count
	
	# Generate unique IDs for this date using the date string directly
	# Format: base_id + YYYYMMDD to avoid hash collisions
	var date_num = date_key.replace("-", "")
	var am_id = "%d_%s" % [NOTIFICATION_ID_DAILY_AM_BASE, date_num]
	var pm_id = "%d_%s" % [NOTIFICATION_ID_DAILY_PM_BASE, date_num]
	
	# Schedule 6 AM notification
	_schedule_notification_at_time(6, 0, date, "🌅 Morning Tasks!", message, am_id)
	
	# Schedule 6 PM notification
	_schedule_notification_at_time(18, 0, date, "🌆 Evening Check-in!", message, pm_id)
	
	# Store IDs for cancellation
	scheduled_notification_ids[date_key] = [am_id, pm_id]
	
	print("🔔 Daily reminders scheduled for %s (AM: %s, PM: %s)" % [date_key, am_id, pm_id])

func cancel_daily_reminders_for_date(date_key: String):
	if not scheduled_notification_ids.has(date_key):
		return
	
	var ids = scheduled_notification_ids[date_key]
	for notification_id in ids:
		# TODO: Integrate with godot-notification-scheduler plugin for actual cancellation
		print("  🔕 Cancelled notification ID: %s" % notification_id)
	
	scheduled_notification_ids.erase(date_key)
	print("🔔 Daily reminders cancelled for %s" % date_key)

func _schedule_notification_at_time(hour: int, minute: int, date: Dictionary, title: String, message: String, notification_id: String):
	# Calculate seconds until the scheduled time
	var now = Time.get_datetime_dict_from_system()
	
	var target_unix = Time.get_unix_time_from_datetime_dict({
		"year": date.year,
		"month": date.month,
		"day": date.day,
		"hour": hour,
		"minute": minute,
		"second": 0
	})
	
	var now_unix = Time.get_unix_time_from_system()
	var delay_seconds = target_unix - now_unix
	
	if delay_seconds <= 0:
		print("  ⚠️ Scheduled time already passed for %s %02d:%02d" % [
			"%04d-%02d-%02d" % [date.year, date.month, date.day], hour, minute
		])
		return
	
	# TODO: Integrate with godot-notification-scheduler plugin for actual scheduling
	# Currently logs the scheduling intent for future implementation
	print("  📅 Scheduled: %s at %02d:%02d (in %d seconds)" % [
		"%04d-%02d-%02d" % [date.year, date.month, date.day], hour, minute, delay_seconds
	])
	print("     Title: %s" % title)
	print("     Message: %s" % message)
	print("     ID: %s" % notification_id)

# ============================================
# DEADLINE WARNING NOTIFICATIONS
# ============================================

func start_deadline_tracking(deadline_seconds: float, is_resume: bool = false):
	deadline_active = true
	deadline_total_seconds = deadline_seconds
	# Only reset warning flags on fresh start, not on resume
	if not is_resume:
		deadline_5min_warning_shown = false
		deadline_1min_warning_shown = false
		deadline_expired_shown = false
	deadline_check_timer.start()
	print("🔔 Deadline tracking started (%d seconds, resume=%s)" % [int(deadline_seconds), is_resume])

func pause_deadline_tracking():
	"""Pause deadline tracking (preserves warning state for resume)"""
	deadline_active = false
	deadline_check_timer.stop()
	print("🔔 Deadline tracking paused")

func stop_deadline_tracking():
	"""Stop deadline tracking completely (resets warning state)"""
	deadline_active = false
	deadline_check_timer.stop()
	deadline_5min_warning_shown = false
	deadline_1min_warning_shown = false
	deadline_expired_shown = false
	print("🔔 Deadline tracking stopped")

func _on_deadline_check_timer_timeout():
	if not deadline_active:
		return
	
	# Get elapsed time from SessionManager
	var elapsed = 0.0
	if SessionManager and SessionManager.is_running():
		elapsed = SessionManager.get_session_elapsed_time()
	else:
		pause_deadline_tracking()
		return
	
	_check_deadline_warnings(elapsed, deadline_total_seconds)

func _check_deadline_warnings(elapsed: float, deadline: float):
	var remaining = deadline - elapsed
	
	# Get warning thresholds based on mode
	var threshold_5min = get_interval(DEADLINE_5MIN_PROD, DEADLINE_5MIN_DEBUG)
	var threshold_1min = get_interval(DEADLINE_1MIN_PROD, DEADLINE_1MIN_DEBUG)
	
	# Ensure proper ordering (5min threshold should always be > 1min threshold)
	# In debug mode: 5min=30s, 1min=15s (correct order)
	# In prod mode: 5min=300s, 1min=60s (correct order)
	
	# 5-minute warning (fires when remaining is between 5min threshold and 1min threshold)
	if remaining <= threshold_5min and remaining > threshold_1min and not deadline_5min_warning_shown:
		deadline_5min_warning_shown = true
		_show_notification("⏰ Deadline Approaching!", "⏰ 5 minutes left to complete your session!")
		print("🔔 Deadline 5-min warning fired (remaining: %.1fs)" % remaining)
	
	# 1-minute warning (fires when remaining is below 1min threshold but not expired)
	if remaining <= threshold_1min and remaining > 0 and not deadline_1min_warning_shown:
		deadline_1min_warning_shown = true
		_show_notification("⏰ Almost Time!", "⏰ Only 1 minute remaining! Finish strong!")
		print("🔔 Deadline 1-min warning fired (remaining: %.1fs)" % remaining)
	
	# Expired (fires when deadline is reached)
	if remaining <= 0 and not deadline_expired_shown:
		deadline_expired_shown = true
		_show_notification("⏰ Time's Up!", "⏰ Time's up! Session deadline reached.")
		print("🔔 Deadline expired notification fired")
		pause_deadline_tracking()

# ============================================
# BOARD INTEGRATION CALLBACKS
# ============================================

func on_task_added(total_tasks: int, completed_tasks: int):
	"""Called when a task is added to the board"""
	# Stop no-tasks reminder since we now have tasks
	stop_no_tasks_reminder()
	
	# Update progress tracking
	update_progress(completed_tasks, total_tasks)
	
	# Start progress reminders if not already running
	if total_tasks > 0 and completed_tasks < total_tasks:
		if hourly_progress_timer.is_stopped():
			start_hourly_progress_reminder()
		if no_progress_timer.is_stopped():
			start_no_progress_reminder(total_tasks - completed_tasks)
	
	print("🔔 Task added: %d/%d tasks" % [completed_tasks, total_tasks])

func on_task_completed(total_tasks: int, completed_tasks: int):
	"""Called when a task is completed"""
	# Reset no-progress timer
	reset_no_progress_timer()
	
	# Update progress
	update_progress(completed_tasks, total_tasks)
	
	# Update pending count for no-progress reminder
	pending_task_count = total_tasks - completed_tasks
	
	print("🔔 Task completed: %d/%d tasks" % [completed_tasks, total_tasks])

func on_board_loaded(total_tasks: int, completed_tasks: int):
	"""Called when the board is loaded"""
	update_progress(completed_tasks, total_tasks)
	
	if total_tasks == 0:
		# No tasks - start no-tasks reminder
		start_no_tasks_reminder()
		print("🔔 Board loaded: No tasks, starting reminder")
	elif completed_tasks < total_tasks:
		# Has incomplete tasks
		start_hourly_progress_reminder()
		start_no_progress_reminder(total_tasks - completed_tasks)
		print("🔔 Board loaded: %d/%d tasks, starting progress reminders" % [completed_tasks, total_tasks])
	else:
		# All complete
		print("🔔 Board loaded: All tasks complete")

func on_session_started():
	"""Called when a session starts"""
	# Deadline tracking is handled by SessionManager
	pass

func on_session_stopped():
	"""Called when a session stops"""
	stop_deadline_tracking()

# ============================================
# NOTIFICATION DISPLAY HELPER
# ============================================

func _show_notification(title: String, message: String):
	"""Display notification using Toast system"""
	if Toast != null:
		Toast.show_toast("%s\n%s" % [title, message], 3.0)
	else:
		print("🔔 NOTIFICATION: %s - %s" % [title, message])
