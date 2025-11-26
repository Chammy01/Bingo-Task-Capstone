# Filename: SessionManager.gd
# Global session timer management system with deadline tracking
extends Node

# ============================================
# SIGNALS
# ============================================

signal session_started
signal session_paused
signal session_stopped
signal session_resumed
signal timer_updated(elapsed: float)
signal deadline_warning(seconds_remaining: int)
signal deadline_expired

# ============================================
# ENUMS & CONSTANTS
# ============================================

enum SessionState { IDLE, RUNNING, PAUSED }

const SESSION_SAVE_PATH = "user://session_data.save"
const MIN_TIME_FOR_COINS = 5  # Minimum time before earning coins (seconds)
const COINS_PER_TASK = 30  # Not used with deadline system
const TASK_DEADLINE = 15.0  # Deadline for all tasks (seconds)
const BASE_COINS = 30  # Coins if on time
const LATE_COINS = 25  # Coins if late
const DEADLINE_WARNING_TIME = 10.0  # When to show warning before deadline

# ============================================
# VARIABLES
# ============================================

var session_state: SessionState = SessionState.IDLE
var session_start_time: float = 0.0
var session_pause_time: float = 0.0
var total_paused_time: float = 0.0

# Deadline tracking
var deadline_warning_shown: bool = false
var deadline_expired_shown: bool = false

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	load_session_data()
	print("✓ SessionManager initialized")

func _process(_delta):
	"""Emit timer updates every frame when session is running"""
	if session_state == SessionState.RUNNING:
		var elapsed = get_session_elapsed_time()
		timer_updated.emit(elapsed)
		_check_deadline_warnings(elapsed)

# ============================================
# SESSION CONTROL
# ============================================

func start_session() -> void:
	"""Start a new session or resume a paused one"""
	if session_state == SessionState.RUNNING:
		print("⚠️ Session already running!")
		return
	
	if session_state == SessionState.PAUSED:
		print("▶ Resuming session...")
		resume_session()
		return
	
	# Start fresh session
	print("▶ Starting new session...")
	session_start_time = Time.get_unix_time_from_system()
	session_pause_time = 0.0
	total_paused_time = 0.0
	session_state = SessionState.RUNNING
	
	# Reset deadline tracking
	deadline_warning_shown = false
	deadline_expired_shown = false
	
	session_started.emit()
	print("✓ Session started")

func pause_session() -> void:
	"""Pause the current session"""
	if session_state != SessionState.RUNNING:
		print("⚠️ No active session to pause!")
		return
	
	print("⏸ Pausing session...")
	session_pause_time = Time.get_unix_time_from_system()
	session_state = SessionState.PAUSED
	
	session_paused.emit()

func resume_session() -> void:
	"""Resume a paused session"""
	if session_state != SessionState.PAUSED:
		print("⚠️ No paused session to resume!")
		return
	
	print("▶ Resuming session...")
	var pause_duration = Time.get_unix_time_from_system() - session_pause_time
	total_paused_time += pause_duration
	session_state = SessionState.RUNNING
	
	session_resumed.emit()

func stop_session() -> void:
	"""Stop the current session completely"""
	if session_state == SessionState.IDLE:
		print("⚠️ No active session to stop!")
		return
	
	print("⏹ Stopping session...")
	var final_time = get_session_elapsed_time()
	session_state = SessionState.IDLE
	
	# Reset deadline tracking
	deadline_warning_shown = false
	deadline_expired_shown = false
	
	print("✓ Session ended. Total time: %s" % format_time(final_time))
	
	session_stopped.emit()

# ============================================
# TIME CALCULATIONS
# ============================================

func get_session_elapsed_time() -> float:
	"""Get elapsed time (excludes paused duration)"""
	if session_state == SessionState.IDLE:
		return 0.0
	
	var current_time = Time.get_unix_time_from_system()
	
	if session_state == SessionState.RUNNING:
		return (current_time - session_start_time) - total_paused_time
	else:  # PAUSED
		return (session_pause_time - session_start_time) - total_paused_time

func format_time(seconds: float) -> String:
	"""Format seconds to MM:SS or HH:MM:SS"""
	@warning_ignore("integer_division")
	var hours = int(seconds) / 3600
	@warning_ignore("integer_division")
	var minutes = (int(seconds) % 3600) / 60
	var secs = int(seconds) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]

# ============================================
# DEADLINE SYSTEM
# ============================================

func _check_deadline_warnings(elapsed: float) -> void:
	"""Check if deadline warnings should be shown"""
	var time_remaining = TASK_DEADLINE - elapsed
	
	# Show warning when approaching deadline
	if time_remaining > 0 and time_remaining <= DEADLINE_WARNING_TIME:
		if not deadline_warning_shown:
			deadline_warning.emit(int(time_remaining))
			deadline_warning_shown = true
			print("⚠️ Deadline warning: %d seconds remaining" % int(time_remaining))
	
	# Deadline has expired
	elif time_remaining <= 0:
		if not deadline_expired_shown:
			deadline_expired.emit()
			deadline_expired_shown = true
			print("⚠️ Deadline expired!")

func is_past_deadline() -> bool:
	"""Check if the current session has passed the deadline"""
	return get_session_elapsed_time() > TASK_DEADLINE

# ============================================
# HELPER FUNCTIONS
# ============================================

func is_running() -> bool:
	"""Check if session is currently running"""
	return session_state == SessionState.RUNNING

func is_paused() -> bool:
	"""Check if session is currently paused"""
	return session_state == SessionState.PAUSED

func is_idle() -> bool:
	"""Check if no session is active"""
	return session_state == SessionState.IDLE

# ============================================
# REWARD LOGIC WITH DEADLINE
# ============================================

func can_earn_coins() -> bool:
	"""Check if session is active and minimum time passed"""
	if session_state != SessionState.RUNNING:
		return false
	
	var elapsed = get_session_elapsed_time()
	return elapsed >= MIN_TIME_FOR_COINS

func get_coins_for_task() -> int:
	"""Get coins for completing a task (checks current deadline status)"""
	if not can_earn_coins():
		return 0
	
	# Check current deadline status for every task
	if is_past_deadline():
		return LATE_COINS  # 25 coins - deadline exceeded
	else:
		return BASE_COINS  # 30 coins - still on time

func get_session_state_string() -> String:
	"""Get current session state as string"""
	match session_state:
		SessionState.IDLE:
			return "Not Started"
		SessionState.RUNNING:
			return "Running"
		SessionState.PAUSED:
			return "Paused"
		_:
			return "Unknown"

# ============================================
# SAVE/LOAD
# ============================================

func save_session_data() -> void:
	"""Save session state to file"""
	var data = {
		"state": session_state,
		"start_time": session_start_time,
		"pause_time": session_pause_time,
		"total_paused": total_paused_time
	}
	
	var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		print("💾 Session data saved")

func load_session_data() -> void:
	"""Load session state from file"""
	if FileAccess.file_exists(SESSION_SAVE_PATH):
		var file = FileAccess.open(SESSION_SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			session_state = data.get("state", SessionState.IDLE)
			session_start_time = data.get("start_time", 0.0)
			session_pause_time = data.get("pause_time", 0.0)
			total_paused_time = data.get("total_paused", 0.0)
			print("📂 Session data loaded")
