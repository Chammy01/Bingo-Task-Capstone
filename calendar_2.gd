extends Node2D

# Node references
@onready var month_label: Label = $MonthLabel
@onready var day_label: Label = $DayLabel
@onready var update_timer: Timer = $UpdateTimer

var last_known_day = -1

func _ready():
	"""
	Initial setup: starts the update timer and connects signals safely.
	Sets the initial calendar display.
	"""
	update_timer.wait_time = 10.0
	update_timer.start()
	
	if not update_timer.timeout.is_connected(check_for_date_change):
		update_timer.timeout.connect(check_for_date_change)
	
	update_calendar_display()

func check_for_date_change():
	"""
	Called periodically to detect if the system day has changed.
	If a new day is detected, update the calendar display.
	"""
	var current_day = Time.get_datetime_dict_from_system().day
	
	if current_day != last_known_day:
		update_calendar_display()

func update_calendar_display():
	"""
	Updates the month and day labels to reflect the current date.
	Records the current day to avoid repeated updates within the same day.
	"""
	print("A new day has started. Updating calendar!")
	
	var now = Time.get_datetime_dict_from_system()
	last_known_day = now.day
	
	month_label.text = get_month_abbreviation(now.month)
	day_label.text = str(now.day)

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
