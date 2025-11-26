# Filename: NotificationManager.gd
# Global notification management system with debug/production interval support
extends Node

# ============================================
# NOTIFICATION IDS
# ============================================
const NOTIFICATION_ID_NO_TASKS: int = 1000
const NOTIFICATION_ID_NO_PROGRESS: int = 2000
const NOTIFICATION_ID_HOURLY_PROGRESS: int = 3000
const NOTIFICATION_ID_DAILY_AM_BASE: int = 4000
const NOTIFICATION_ID_DAILY_PM_BASE: int = 5000
const NOTIFICATION_ID_DEADLINE_WARNING: int = 6000
const NOTIFICATION_ID_DEADLINE_EXPIRED: int = 6001

# ============================================
# PRODUCTION INTERVALS (in seconds)
# ============================================
const PROD_NO_TASKS_INTERVAL: float = 7200.0        # 2 hours
const PROD_NO_PROGRESS_INTERVAL: float = 10800.0    # 3 hours
const PROD_HOURLY_PROGRESS_INTERVAL: float = 3600.0 # 1 hour
const PROD_DEADLINE_WARNING_BEFORE: float = 60.0    # 60s before deadline
const PROD_DAILY_REMINDER_AM_HOUR: int = 6          # 6:00 AM
const PROD_DAILY_REMINDER_PM_HOUR: int = 18         # 6:00 PM

# ============================================
# DEBUG INTERVALS (in seconds)
# ============================================
const DEBUG_NO_TASKS_INTERVAL: float = 10.0         # 10 seconds
const DEBUG_NO_PROGRESS_INTERVAL: float = 15.0      # 15 seconds
const DEBUG_HOURLY_PROGRESS_INTERVAL: float = 7.0   # 7 seconds
const DEBUG_DEADLINE_WARNING_BEFORE: float = 5.0    # 5s before deadline
const DEBUG_DAILY_REMINDER_DELAY: float = 5.0       # 5 seconds (immediate test)

# ============================================
# CONSTANTS
# ============================================
const THREE_FINGER_TAP_THRESHOLD: float = 0.3  # Time window for 3 fingers to touch

# ============================================
# VARIABLES
# ============================================
var debug_mode: bool = false

# Touch tracking for 3-finger tap
var _active_touches: Dictionary = {}

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	# Load debug mode setting from SaveManager
	debug_mode = SaveManager.get_setting("notification_debug_mode", false)
	print("🔔 [NotificationManager] Initialized (Debug Mode: %s)" % ("ENABLED" if debug_mode else "DISABLED"))
	print_debug_status()

func _input(event):
	"""Handle debug mode toggle via keyboard and 3-finger tap"""
	# Keyboard shortcut (for desktop): Ctrl+Shift+N
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N and event.ctrl_pressed and event.shift_pressed:
			_toggle_debug_mode()

	# 3-finger tap detection (for mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = Time.get_ticks_msec()
			_check_three_finger_tap()
		else:
			_active_touches.erase(event.index)

func _check_three_finger_tap():
	"""Check if 3 fingers touched within the threshold time"""
	if _active_touches.size() >= 3:
		var current_time = Time.get_ticks_msec()
		var touch_times = _active_touches.values()
		var min_time = touch_times.min()
		var max_time = touch_times.max()

		# Check if all 3 touches happened within threshold
		if (max_time - min_time) <= (THREE_FINGER_TAP_THRESHOLD * 1000):
			_toggle_debug_mode()
			_active_touches.clear()  # Reset to prevent repeated toggles

# ============================================
# DEBUG MODE CONTROL
# ============================================

func _toggle_debug_mode():
	"""Toggle between debug and production mode"""
	set_debug_mode(not debug_mode)

func set_debug_mode(enabled: bool):
	"""Set debug mode and update all intervals"""
	debug_mode = enabled
	SaveManager.save_setting("notification_debug_mode", enabled)

	var mode_str = "DEBUG" if enabled else "PRODUCTION"
	print("\n🔔 ============================================")
	print("🔔 [NotificationManager] Mode switched to: %s" % mode_str)
	print("🔔 ============================================")
	print("🔔 Current Intervals:")
	print("🔔   No Tasks:        %ss" % (DEBUG_NO_TASKS_INTERVAL if enabled else PROD_NO_TASKS_INTERVAL))
	print("🔔   No Progress:     %ss" % (DEBUG_NO_PROGRESS_INTERVAL if enabled else PROD_NO_PROGRESS_INTERVAL))
	print("🔔   Hourly Progress: %ss" % (DEBUG_HOURLY_PROGRESS_INTERVAL if enabled else PROD_HOURLY_PROGRESS_INTERVAL))
	print("🔔   Deadline Warn:   %ss before" % (DEBUG_DEADLINE_WARNING_BEFORE if enabled else PROD_DEADLINE_WARNING_BEFORE))
	print("🔔   Daily Reminders: %s" % ("5s delay (test)" if enabled else "6:00 AM & 6:00 PM"))
	print("🔔 ============================================\n")

	# Show toast notification
	if is_instance_valid(Toast):
		Toast.show_toast("🔔 Notification Mode: %s\n⏱️ Intervals updated!" % mode_str, 2.5)

	# Reschedule all active notifications with new intervals
	_reschedule_all_notifications()

func _reschedule_all_notifications():
	"""Reschedule notifications when debug mode changes"""
	print("🔔 [NotificationManager] Rescheduling all notifications with new intervals...")
	# Cancel existing and reschedule based on current state
	# This ensures switching debug mode takes effect immediately
	# Note: Actual implementation depends on notification scheduler plugin

# ============================================
# INTERVAL GETTERS (respects debug_mode)
# ============================================

func get_no_tasks_interval() -> float:
	"""Get the interval for 'no tasks added' notification"""
	var interval = DEBUG_NO_TASKS_INTERVAL if debug_mode else PROD_NO_TASKS_INTERVAL
	print("🔔 [NotificationManager] No Tasks interval: %ss (%s mode)" % [interval, "DEBUG" if debug_mode else "PROD"])
	return interval

func get_no_progress_interval() -> float:
	"""Get the interval for 'no progress' notification"""
	var interval = DEBUG_NO_PROGRESS_INTERVAL if debug_mode else PROD_NO_PROGRESS_INTERVAL
	print("🔔 [NotificationManager] No Progress interval: %ss (%s mode)" % [interval, "DEBUG" if debug_mode else "PROD"])
	return interval

func get_hourly_progress_interval() -> float:
	"""Get the interval for 'hourly progress' notification"""
	var interval = DEBUG_HOURLY_PROGRESS_INTERVAL if debug_mode else PROD_HOURLY_PROGRESS_INTERVAL
	print("🔔 [NotificationManager] Hourly Progress interval: %ss (%s mode)" % [interval, "DEBUG" if debug_mode else "PROD"])
	return interval

func get_deadline_warning_time() -> float:
	"""Get the time before deadline for warning notification"""
	var time = DEBUG_DEADLINE_WARNING_BEFORE if debug_mode else PROD_DEADLINE_WARNING_BEFORE
	print("🔔 [NotificationManager] Deadline Warning time: %ss before (%s mode)" % [time, "DEBUG" if debug_mode else "PROD"])
	return time

func get_daily_reminder_delay() -> float:
	"""Get the delay for daily reminders (debug mode returns immediate delay)"""
	# In debug mode, fire immediately (5s), in prod use actual scheduled time
	if debug_mode:
		print("🔔 [NotificationManager] Daily Reminder: DEBUG mode - firing in %ss" % DEBUG_DAILY_REMINDER_DELAY)
		return DEBUG_DAILY_REMINDER_DELAY
	return -1.0  # Signal to use actual time calculation

func get_daily_am_hour() -> int:
	"""Get the AM hour for daily reminders"""
	return PROD_DAILY_REMINDER_AM_HOUR

func get_daily_pm_hour() -> int:
	"""Get the PM hour for daily reminders"""
	return PROD_DAILY_REMINDER_PM_HOUR

func is_debug_mode() -> bool:
	"""Check if debug mode is enabled"""
	return debug_mode

# ============================================
# NOTIFICATION SCHEDULING FUNCTIONS
# ============================================

func schedule_no_tasks_notification():
	"""Schedule notification for when no tasks are added"""
	var interval = get_no_tasks_interval()
	print("🔔 [NotificationManager] Scheduling No Tasks notification in %ss" % interval)
	# TODO: Implement actual scheduling with notification plugin
	# Example: NotificationScheduler.schedule(NOTIFICATION_ID_NO_TASKS, interval, "Add Some Tasks!", "You haven't added any tasks yet")

func cancel_no_tasks_notification():
	"""Cancel the no tasks notification"""
	print("🔔 [NotificationManager] Cancelling No Tasks notification (ID: %d)" % NOTIFICATION_ID_NO_TASKS)
	# TODO: Implement actual cancellation with notification plugin

func schedule_no_progress_notification():
	"""Schedule notification for when no progress is made"""
	var interval = get_no_progress_interval()
	print("🔔 [NotificationManager] Scheduling No Progress notification in %ss" % interval)
	# TODO: Implement actual scheduling with notification plugin

func cancel_no_progress_notification():
	"""Cancel the no progress notification"""
	print("🔔 [NotificationManager] Cancelling No Progress notification (ID: %d)" % NOTIFICATION_ID_NO_PROGRESS)
	# TODO: Implement actual cancellation with notification plugin

func schedule_hourly_progress_notification():
	"""Schedule notification for hourly progress updates"""
	var interval = get_hourly_progress_interval()
	print("🔔 [NotificationManager] Scheduling Hourly Progress notification in %ss" % interval)
	# TODO: Implement actual scheduling with notification plugin

func cancel_hourly_progress_notification():
	"""Cancel the hourly progress notification"""
	print("🔔 [NotificationManager] Cancelling Hourly Progress notification (ID: %d)" % NOTIFICATION_ID_HOURLY_PROGRESS)
	# TODO: Implement actual cancellation with notification plugin

func schedule_deadline_warning(deadline_seconds: float):
	"""Schedule a warning notification before a deadline"""
	var warning_time = get_deadline_warning_time()
	var delay = max(1.0, deadline_seconds - warning_time)
	print("🔔 [NotificationManager] Scheduling Deadline Warning in %ss (deadline in %ss, warning %ss before)" % [delay, deadline_seconds, warning_time])
	# TODO: Implement actual scheduling with notification plugin

func cancel_deadline_warning():
	"""Cancel the deadline warning notification"""
	print("🔔 [NotificationManager] Cancelling Deadline Warning notification (ID: %d)" % NOTIFICATION_ID_DEADLINE_WARNING)
	# TODO: Implement actual cancellation with notification plugin

func schedule_deadline_expired():
	"""Schedule notification for when deadline expires"""
	print("🔔 [NotificationManager] Scheduling Deadline Expired notification (ID: %d)" % NOTIFICATION_ID_DEADLINE_EXPIRED)
	# TODO: Implement actual scheduling with notification plugin

func cancel_deadline_expired():
	"""Cancel the deadline expired notification"""
	print("🔔 [NotificationManager] Cancelling Deadline Expired notification (ID: %d)" % NOTIFICATION_ID_DEADLINE_EXPIRED)
	# TODO: Implement actual cancellation with notification plugin

func schedule_daily_reminders():
	"""Schedule daily AM and PM reminder notifications"""
	var delay = get_daily_reminder_delay()

	if delay > 0:
		# Debug mode - schedule immediately
		print("🔔 [NotificationManager] Scheduling Daily Reminders in %ss (DEBUG mode)" % delay)
	else:
		# Production mode - calculate time until 6 AM and 6 PM
		var am_hour = get_daily_am_hour()
		var pm_hour = get_daily_pm_hour()
		print("🔔 [NotificationManager] Scheduling Daily Reminders for %d:00 AM and %d:00 PM" % [am_hour, pm_hour - 12])
	# TODO: Implement actual scheduling with notification plugin

func cancel_daily_reminders():
	"""Cancel all daily reminder notifications"""
	print("🔔 [NotificationManager] Cancelling Daily Reminders (AM: %d+, PM: %d+)" % [NOTIFICATION_ID_DAILY_AM_BASE, NOTIFICATION_ID_DAILY_PM_BASE])
	# TODO: Implement actual cancellation with notification plugin

# ============================================
# EVENT HANDLERS (for integration with other managers)
# ============================================

func on_task_added():
	"""Called when a task is added to the board"""
	print("🔔 [NotificationManager] Task added - cancelling No Tasks notification")
	cancel_no_tasks_notification()

func on_task_completed():
	"""Called when a task is completed"""
	print("🔔 [NotificationManager] Task completed - updating progress notifications")
	cancel_no_progress_notification()
	schedule_no_progress_notification()

func update_progress():
	"""Called to update progress tracking notifications"""
	print("🔔 [NotificationManager] Progress updated")
	schedule_hourly_progress_notification()

func on_session_started():
	"""Called when a session starts"""
	print("🔔 [NotificationManager] Session started - scheduling deadline notifications")
	# Schedule deadline warning based on session deadline
	var deadline = SessionManager.TASK_DEADLINE
	schedule_deadline_warning(deadline)

func on_session_stopped():
	"""Called when a session stops"""
	print("🔔 [NotificationManager] Session stopped - cancelling deadline notifications")
	cancel_deadline_warning()
	cancel_deadline_expired()

# ============================================
# DEBUG INFO
# ============================================

func print_debug_status():
	"""Print current notification status for debugging"""
	print("\n🔔 ============ NOTIFICATION STATUS ============")
	print("🔔 Debug Mode: %s" % ("ENABLED" if debug_mode else "DISABLED"))
	print("🔔 ")
	print("🔔 CURRENT INTERVALS:")
	print("🔔   No Tasks Added:    %s seconds" % (DEBUG_NO_TASKS_INTERVAL if debug_mode else PROD_NO_TASKS_INTERVAL))
	print("🔔   No Progress:       %s seconds" % (DEBUG_NO_PROGRESS_INTERVAL if debug_mode else PROD_NO_PROGRESS_INTERVAL))
	print("🔔   Hourly Progress:   %s seconds" % (DEBUG_HOURLY_PROGRESS_INTERVAL if debug_mode else PROD_HOURLY_PROGRESS_INTERVAL))
	print("🔔   Deadline Warning:  %s seconds before" % (DEBUG_DEADLINE_WARNING_BEFORE if debug_mode else PROD_DEADLINE_WARNING_BEFORE))
	print("🔔 ")
	print("🔔 COMPARISON:")
	print("🔔   Feature            | DEBUG    | PRODUCTION")
	print("🔔   -------------------|----------|------------")
	print("🔔   No Tasks           | 10s      | 7200s (2hr)")
	print("🔔   No Progress        | 15s      | 10800s (3hr)")
	print("🔔   Hourly Progress    | 7s       | 3600s (1hr)")
	print("🔔   Deadline Warning   | 5s       | 60s")
	print("🔔   Daily Reminders    | 5s       | 6AM & 6PM")
	print("🔔 ================================================\n")
