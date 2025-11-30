# Filename: DailyResetManager.gd
# Autoload manager that handles automatic daily reset at midnight
extends Node

# ============================================
# SIGNALS
# ============================================

signal daily_reset_triggered

# ============================================
# CONSTANTS
# ============================================

const MIDNIGHT_CHECK_INTERVAL = 60.0  # Check every 60 seconds

# ============================================
# VARIABLES
# ============================================

var midnight_check_timer: Timer = null
var last_known_date: String = ""

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_start_midnight_check_timer()
	_check_day_change_on_startup()
	print("✓ DailyResetManager initialized")

func _start_midnight_check_timer():
	"""Start timer to periodically check for midnight"""
	midnight_check_timer = Timer.new()
	midnight_check_timer.wait_time = MIDNIGHT_CHECK_INTERVAL
	midnight_check_timer.one_shot = false
	midnight_check_timer.timeout.connect(_check_for_midnight)
	add_child(midnight_check_timer)
	midnight_check_timer.start()
	print("  ⏰ Midnight check timer started (interval: %ds)" % int(MIDNIGHT_CHECK_INTERVAL))

func _check_day_change_on_startup():
	"""Check if the date changed since last session"""
	var current_date = _get_current_date_key()
	var last_reset_date = SaveManager.get_last_reset_date()
	last_known_date = current_date
	
	print("  📅 Current date: %s" % current_date)
	print("  📅 Last reset date: %s" % (last_reset_date if last_reset_date != "" else "never"))
	
	if last_reset_date == "":
		# First run - set the date but don't reset
		SaveManager.set_last_reset_date(current_date)
		print("  ✓ First run - set initial reset date")
		return
	
	if last_reset_date != current_date:
		print("  🌙 Day changed since last session! Triggering reset...")
		_perform_daily_reset(true)

# ============================================
# MIDNIGHT DETECTION
# ============================================

func _check_for_midnight():
	"""Compare current date with last known date"""
	var current_date = _get_current_date_key()
	
	if current_date != last_known_date:
		print("🌙 Midnight detected! Date changed from %s to %s" % [last_known_date, current_date])
		last_known_date = current_date
		_perform_daily_reset(false)

# ============================================
# DAILY RESET LOGIC
# ============================================

func _perform_daily_reset(is_app_resume: bool):
	"""
	Perform the daily reset sequence:
	1. Archive current tasks to history
	2. Clear daily tasks
	3. Load scheduled tasks for new day
	4. Update last_reset_date setting
	5. Emit daily_reset_triggered signal
	"""
	var current_date = _get_current_date_key()
	print("\n🔄 === PERFORMING DAILY RESET ===")
	print("  Date: %s" % current_date)
	print("  Triggered by: %s" % ("app resume" if is_app_resume else "midnight timer"))
	
	# Step 1: Archive current tasks to history
	_archive_current_tasks()
	
	# Step 2: Clear daily tasks
	if SaveManager.clear_daily_tasks():
		print("  ✓ Daily tasks cleared")
	else:
		print("  ⚠️ Failed to clear daily tasks")
	
	# Step 3: Load scheduled tasks for new day is handled by board_manager
	# when it receives the daily_reset_triggered signal
	
	# Step 4: Update last_reset_date
	SaveManager.set_last_reset_date(current_date)
	print("  ✓ Last reset date updated to %s" % current_date)
	
	# Step 5: Emit signal so board can refresh
	daily_reset_triggered.emit()
	print("  ✓ Daily reset signal emitted")
	
	# Show toast notification
	if is_app_resume:
		if is_instance_valid(Toast):
			Toast.show_toast("📅 Welcome back! Loading today's tasks", 3.0)
	else:
		if is_instance_valid(Toast):
			Toast.show_toast("🌙 New day! Tasks reset and loaded", 3.0)
	
	print("=================================\n")

func _archive_current_tasks():
	"""Archive current tasks to task history before clearing"""
	# Get yesterday's date for archiving (since we're now in a new day)
	var yesterday = _get_yesterday_date_key()
	var tasks = SaveManager.load_tasks()
	
	if tasks.is_empty():
		print("  ⚪ No tasks to archive")
		return
	
	# Check if there are any non-empty tasks
	var has_tasks = false
	for task in tasks:
		if task is Dictionary and task.has("text"):
			var text: String = task.text
			if text != "" and text != "Tap to add task":
				has_tasks = true
				break
	
	if has_tasks:
		if SaveManager.save_task_history(yesterday, tasks):
			print("  ✓ Tasks archived to history for %s" % yesterday)
		else:
			print("  ⚠️ Failed to archive tasks")
	else:
		print("  ⚪ No non-empty tasks to archive")

# ============================================
# APP LIFECYCLE HANDLERS
# ============================================

func _notification(what):
	match what:
		NOTIFICATION_APPLICATION_RESUMED, \
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_app_resumed()

func _on_app_resumed():
	"""Check if date changed while app was in background"""
	var current_date = _get_current_date_key()
	var last_reset_date = SaveManager.get_last_reset_date()
	
	if last_reset_date != "" and last_reset_date != current_date:
		print("📱 App resumed on new day - triggering reset")
		_perform_daily_reset(true)
	else:
		last_known_date = current_date

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_current_date_key() -> String:
	"""Get current date as YYYY-MM-DD string"""
	var date = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func _get_yesterday_date_key() -> String:
	"""Get yesterday's date as YYYY-MM-DD string"""
	var unix_time = Time.get_unix_time_from_system()
	# Subtract 24 hours (86400 seconds)
	var yesterday_unix = unix_time - 86400
	var yesterday = Time.get_datetime_dict_from_unix_time(yesterday_unix)
	return "%04d-%02d-%02d" % [yesterday.year, yesterday.month, yesterday.day]

# ============================================
# PUBLIC API
# ============================================

func force_reset():
	"""Force a daily reset (for testing purposes)"""
	print("🧪 Force reset triggered")
	_perform_daily_reset(false)
