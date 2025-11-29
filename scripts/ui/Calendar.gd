extends Node2D

# Node references
@onready var month_label: Label = $MonthLabel
@onready var day_label: Label = $DayLabel
@onready var update_timer: Timer = $UpdateTimer

var last_known_day = -1
var is_scheduling_mode: bool = false
var scheduling_date: Dictionary = {}
var debug_date_override: Dictionary = {}

func _ready():
	"""
	Initial setup: checks if in scheduling mode, then updates display.
	"""
	# Load debug date override
	debug_date_override = SaveManager.get_setting("debug_date_override", {})
	
	# Check if we're in scheduling mode
	is_scheduling_mode = SaveManager.get_setting("is_scheduling_mode", false)
	
	if is_scheduling_mode:
		scheduling_date = SaveManager.get_setting("scheduling_date", {})
		if not scheduling_date.is_empty():
			# Show scheduling date
			update_calendar_to_scheduling_date()
		else:
			# Fallback to normal
			update_calendar_display()
	else:
		# Normal mode - show today's date with auto-update
		update_timer.wait_time = 10.0
		update_timer.start()
		
		if not update_timer.timeout.is_connected(check_for_date_change):
			update_timer.timeout.connect(check_for_date_change)
		
		update_calendar_display()

func check_for_date_change():
	"""
	Called periodically to detect if the system day has changed.
	Also checks for debug date override changes.
	Only active in normal mode.
	"""
	if is_scheduling_mode:
		return
	
	# Refresh debug override
	var new_override = SaveManager.get_setting("debug_date_override", {})
	var override_changed = (new_override != debug_date_override)
	debug_date_override = new_override
	
	var current_date = _get_current_date()
	var current_day = current_date.day
	
	# Update if day changed OR override changed
	if current_day != last_known_day or override_changed:
		update_calendar_display()

func update_calendar_display():
	"""
	Updates the month and day labels to reflect the CURRENT date.
	Respects debug date override.
	Used in normal mode.
	"""
	var now = _get_current_date()
	last_known_day = now.day
	
	month_label.text = get_month_abbreviation(now.month)
	day_label.text = str(now.day)
	
	var debug_indicator = "" if debug_date_override.is_empty() else " 🧪"
	print("📅 Calendar updated to: %s %d%s" % [month_label.text, now.day, debug_indicator])

func update_calendar_to_scheduling_date():
	"""
	Updates the calendar to show the SCHEDULING date.
	Used when planning tasks for a future date.
	"""
	if scheduling_date.is_empty():
		update_calendar_display()
		return
	
	month_label.text = get_month_abbreviation(scheduling_date.month)
	day_label.text = str(scheduling_date.day)
	
	print("📅 Calendar updated to scheduling date: %s %d, %d" % [
		month_label.text, 
		scheduling_date.day, 
		scheduling_date.year
	])

func _get_current_date() -> Dictionary:
	"""Get current date, respecting debug override"""
	if not debug_date_override.is_empty():
		return debug_date_override
	return Time.get_datetime_dict_from_system()

func get_month_abbreviation(month_num: int) -> String:
	"""
	Converts month number to three-letter abbreviation.
	Returns "???" for invalid month numbers.
	"""
	match month_num:
		1: return "JAN"
		2: return "FEB"
		3: return "MAR"
		4: return "APR"
		5: return "MAY"
		6: return "JUN"
		7: return "JUL"
		8: return "AUG"
		9: return "SEP"
		10: return "OCT"
		11: return "NOV"
		12: return "DEC"
		_: return "???"
