# Filename: NotificationManager.gd
# Manages local notifications for the Bingo Task app
extends Node

# ============================================
# SIGNALS
# ============================================

signal notification_opened(notification_id: int)
signal notification_dismissed(notification_id: int)

# ============================================
# CONSTANTS
# ============================================

# Notification IDs
const NOTIFICATION_ID_DEADLINE_WARNING: int = 5000
const NOTIFICATION_ID_DEADLINE_EXPIRED: int = 5001

# Intervals (these are triggers, not repeating)
const DEADLINE_WARNING_BEFORE: float = 60.0  # Production: warn 60s before deadline
const DEBUG_DEADLINE_WARNING_BEFORE: float = 5.0  # Debug: warn 5s before deadline

# ============================================
# VARIABLES
# ============================================

var debug_mode: bool = false
var scheduled_notifications: Dictionary = {}  # id -> {delay, message, time_scheduled}

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	debug_mode = OS.is_debug_build()
	print("🔔 NotificationManager initialized (Debug: %s)" % debug_mode)
	
	# Connect to SessionManager signals as alternative approach
	if SessionManager:
		SessionManager.deadline_warning.connect(_on_deadline_warning_signal)
		SessionManager.deadline_expired.connect(_on_deadline_expired_signal)
		print("✓ Connected to SessionManager deadline signals")

# ============================================
# DEBUG MODE
# ============================================

func set_debug_mode(enabled: bool):
	debug_mode = enabled
	print("🔔 Debug mode: %s" % debug_mode)

# ============================================
# DEADLINE NOTIFICATIONS
# ============================================

func schedule_deadline_warning_notification(seconds_until_deadline: float):
	"""Schedule a notification for when deadline is near"""
	# Calculate delay: when to show the notification
	var warning_time = DEBUG_DEADLINE_WARNING_BEFORE if debug_mode else DEADLINE_WARNING_BEFORE
	var delay = max(1.0, seconds_until_deadline - warning_time)
	
	# Cancel any existing deadline notification
	cancel_notification(NOTIFICATION_ID_DEADLINE_WARNING)
	
	# Schedule new one
	var message = "⏰ Deadline approaching! Only %d seconds left to earn full coins!" % int(warning_time)
	
	# Store scheduled notification
	scheduled_notifications[NOTIFICATION_ID_DEADLINE_WARNING] = {
		"delay": delay,
		"message": message,
		"time_scheduled": Time.get_unix_time_from_system()
	}
	
	if debug_mode:
		print("🔔 DEBUG: Scheduled deadline warning for +%.1fs (warning at %ds before deadline)" % [delay, int(warning_time)])
		if is_instance_valid(Toast):
			Toast.show_toast("🔔 DEBUG: Deadline notification scheduled, will fire in %ds" % int(delay), 2.0)
	else:
		print("🔔 Scheduled deadline warning notification (delay: %.1fs)" % delay)
	
	# Set a timer to show the notification
	get_tree().create_timer(delay).timeout.connect(func(): _show_notification(NOTIFICATION_ID_DEADLINE_WARNING, message))

func schedule_deadline_expired_notification(delay: float):
	"""Schedule a notification for when deadline expires"""
	cancel_notification(NOTIFICATION_ID_DEADLINE_EXPIRED)
	
	var message = "⚠️ Deadline passed! Complete tasks now for 25 coins instead of 30"
	
	# Store scheduled notification
	scheduled_notifications[NOTIFICATION_ID_DEADLINE_EXPIRED] = {
		"delay": delay,
		"message": message,
		"time_scheduled": Time.get_unix_time_from_system()
	}
	
	if debug_mode:
		print("🔔 DEBUG: Scheduled deadline expired for +%.1fs" % delay)
	else:
		print("🔔 Scheduled deadline expired notification (delay: %.1fs)" % delay)
	
	# Set a timer to show the notification
	get_tree().create_timer(delay).timeout.connect(func(): _show_notification(NOTIFICATION_ID_DEADLINE_EXPIRED, message))

func cancel_deadline_notifications():
	"""Cancel all deadline-related notifications"""
	cancel_notification(NOTIFICATION_ID_DEADLINE_WARNING)
	cancel_notification(NOTIFICATION_ID_DEADLINE_EXPIRED)
	print("🔔 Cancelled deadline notifications")

func on_session_started(deadline_seconds: float):
	"""Called when a session starts - schedule deadline notifications"""
	print("🔔 Session started, scheduling deadline notifications (deadline: %.1fs)" % deadline_seconds)
	schedule_deadline_warning_notification(deadline_seconds)
	schedule_deadline_expired_notification(deadline_seconds)

func on_session_stopped():
	"""Called when session stops - cancel deadline notifications"""
	print("🔔 Session stopped, cancelling deadline notifications")
	cancel_deadline_notifications()

# ============================================
# SIGNAL HANDLERS (Alternative approach)
# ============================================

func _on_deadline_warning_signal(seconds_remaining: int):
	"""Handle deadline warning signal from SessionManager"""
	# Show immediate notification if app is in background
	if not get_window().has_focus():
		send_immediate_notification(NOTIFICATION_ID_DEADLINE_WARNING, 
			"⏰ Deadline Warning!", 
			"Only %d seconds left to earn full coins!" % seconds_remaining)
		if debug_mode:
			print("🔔 DEBUG: Immediate deadline warning notification sent (app in background)")

func _on_deadline_expired_signal():
	"""Handle deadline expired signal from SessionManager"""
	if not get_window().has_focus():
		send_immediate_notification(NOTIFICATION_ID_DEADLINE_EXPIRED,
			"⚠️ Deadline Passed!",
			"Complete tasks now for reduced coins (25 instead of 30)")
		if debug_mode:
			print("🔔 DEBUG: Immediate deadline expired notification sent (app in background)")

# ============================================
# NOTIFICATION FUNCTIONS
# ============================================

func cancel_notification(notification_id: int):
	"""Cancel a scheduled notification"""
	if scheduled_notifications.has(notification_id):
		scheduled_notifications.erase(notification_id)
		if debug_mode:
			print("🔔 DEBUG: Cancelled notification %d" % notification_id)

func _show_notification(notification_id: int, message: String):
	"""Show a notification (called by timer)"""
	# Remove from scheduled list
	if scheduled_notifications.has(notification_id):
		scheduled_notifications.erase(notification_id)
	
	# Check if app is in background
	if not get_window().has_focus():
		# In a real implementation, this would use platform-specific notification APIs
		# For now, we log it
		print("🔔 [NOTIFICATION] ID: %d, Message: %s" % [notification_id, message])
		if debug_mode:
			print("🔔 DEBUG: Would show notification (app in background)")
	else:
		# App is in foreground, show toast instead
		if is_instance_valid(Toast):
			Toast.show_toast(message, 2.0)
		if debug_mode:
			print("🔔 DEBUG: Showing toast instead (app in foreground): %s" % message)

func send_immediate_notification(notification_id: int, title: String, message: String):
	"""Send an immediate notification (bypasses scheduling)"""
	# In a real implementation, this would use platform-specific notification APIs
	print("🔔 [NOTIFICATION] ID: %d, Title: %s, Message: %s" % [notification_id, title, message])
	
	if debug_mode:
		print("🔔 DEBUG: Immediate notification sent")
	
	# Emit signal
	notification_opened.emit(notification_id)

# ============================================
# NOTIFICATION EVENT HANDLERS
# ============================================

func _on_notification_opened(notification_id: int):
	"""Handle notification being opened by user"""
	print("🔔 [NotificationManager] Notification OPENED - ID: %d" % notification_id)
	notification_opened.emit(notification_id)

func _on_notification_dismissed(notification_id: int):
	"""Handle notification being dismissed by user"""
	print("🔔 [NotificationManager] Notification DISMISSED - ID: %d" % notification_id)
	notification_dismissed.emit(notification_id)
