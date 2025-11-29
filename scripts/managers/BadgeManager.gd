extends Node

# ============================================
# CONSTANTS
# ============================================

const SAVE_FILE = "user://badges.save"
const STATS_FILE = "user://badge_stats.save"

# ============================================
# STATE
# ============================================

# List of unlocked badge IDs
var unlocked_badges: Array = []

# Badge-related statistics
var stats = {
	"total_tasks": 0,
	"total_bingos": 0,
	"first_bingo_done": false
}

# ============================================
# SIGNALS
# ============================================

signal badge_unlocked(badge_id: String)

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	"""Load badges and stats on start"""
	load_badges()
	load_stats()
	print("✓ BadgeManager initialized: %d badges unlocked" % unlocked_badges.size())
	print("✓ Stats: Tasks=%d, BINGOs=%d" % [stats.total_tasks, stats.total_bingos])

# ============================================
# STAT TRACKING
# ============================================

func increment_tasks():
	"""Called when a task is completed"""
	stats.total_tasks += 1
	save_stats()
	print("📊 Total tasks: %d" % stats.total_tasks)

func increment_bingos():
	"""Called when a BINGO is achieved"""
	stats.total_bingos += 1
	if not stats.first_bingo_done:
		stats.first_bingo_done = true
	save_stats()
	print("📊 Total BINGOs: %d" % stats.total_bingos)

# ============================================
# UNLOCK CHECKING
# ============================================

func is_unlocked(badge_id: String) -> bool:
	"""Check if badge has been unlocked"""
	return badge_id in unlocked_badges

func get_unlock_count() -> int:
	"""Get the number of badges unlocked"""
	return unlocked_badges.size()

# ============================================
# UNLOCKING BADGES
# ============================================

func unlock_badge(badge_id: String) -> bool:
	"""
	Unlock a badge by id.
	Returns true if newly unlocked; false if already unlocked.
	Emits signal 'badge_unlocked' if unlocked.
	"""
	print("\n🔍 unlock_badge() called with: '%s'" % badge_id)
	
	if is_unlocked(badge_id):
		print("  ℹ️ Already unlocked, skipping")
		return false
	
	print("  ✅ Unlocking badge...")
	unlocked_badges.append(badge_id)
	save_badges()
	
	print("🏆 Badge unlocked: %s" % badge_id)
	
	if has_node("/root/Toast"):
		Toast.show_toast("📮 New Stamp Unlocked!", 2.0)
	
	emit_signal("badge_unlocked", badge_id)
	return true

# ============================================
# SAVE/LOAD BADGES
# ============================================

func save_badges() -> void:
	"""Save unlocked badges to file"""
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_var(unlocked_badges)
		file.close()

func load_badges() -> void:
	"""Load unlocked badges from file"""
	if not FileAccess.file_exists(SAVE_FILE):
		unlocked_badges = []
		return
		
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Array:
			unlocked_badges = data
		file.close()

# ============================================
# SAVE/LOAD STATS
# ============================================

func save_stats() -> void:
	"""Save badge stats to file"""
	var file = FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if file:
		file.store_var(stats)
		file.close()

func load_stats() -> void:
	"""Load badge stats from file"""
	if not FileAccess.file_exists(STATS_FILE):
		return
	
	var file = FileAccess.open(STATS_FILE, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			stats = data
		file.close()

# ============================================
# DEBUG
# ============================================

func reset_all() -> void:
	"""Reset badges and stats to default"""
	unlocked_badges.clear()
	stats.total_tasks = 0
	stats.total_bingos = 0
	stats.first_bingo_done = false
	save_badges()
	save_stats()
	print("⚠️ All badges and stats reset!")
