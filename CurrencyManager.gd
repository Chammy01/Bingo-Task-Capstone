# Filename: CurrencyManager.gd
# Global autoload for managing gold coin currency
extends Node

signal coins_changed(new_amount, change_amount)
signal coins_earned(amount, reason)

const SAVE_PATH = "user://bingo_task_currency.save"

# --- REWARD SYSTEM CONSTANTS ---

# Time-tier coin rewards (global session time)
const TIER1_TIME = 30      # seconds
const TIER2_TIME = 120     # seconds
const TIER3_TIME = 300     # seconds
const BASE_TIER1 = 10      # coins (>=30s <120s)
const BASE_TIER2 = 15      # coins (>=120s <300s)
const BASE_TIER3 = 20      # coins (>=300s)

# Row/Column bonuses
const ROW_COL_BONUS = 20
const BINGO_BONUS = 30

var coins: int = 0
var total_coins_earned: int = 0  # ✅ ADDED: Track lifetime earnings for badges

func _ready():
	load_coins()
	print("✓ CurrencyManager: %d coins, %d total earned" % [coins, total_coins_earned])

# --- MAIN EARNING API ---

# Use this from BoardManager or BingoTile (do not call directly from tile!)
func earn_coins(amount: int, reason: String = ""):
	coins += amount
	total_coins_earned += amount  # ✅ ADDED: Track lifetime
	save_coins()
	coins_changed.emit(coins, amount)
	coins_earned.emit(amount, reason)
	print("Earned %d coins! (%s) Total: %d, Lifetime: %d" % [amount, reason, coins, total_coins_earned])

# --- TIER & BONUS CALCULATOR (BoardManager should call!) ---
func calculate_session_reward(elapsed_session_time: float, is_row_complete: bool = false, is_col_complete: bool = false) -> Dictionary:
	var breakdowns = {}
	var base_coins = 0
	# CORE: Time tier
	if elapsed_session_time < TIER1_TIME:
		base_coins = 0      # Too quick, no reward
	elif elapsed_session_time < TIER2_TIME:
		base_coins = BASE_TIER1
	elif elapsed_session_time < TIER3_TIME:
		base_coins = BASE_TIER2
	else:
		base_coins = BASE_TIER3
	breakdowns["base"] = base_coins

	# Pattern bonuses
	var pattern_bonus = 0
	if is_row_complete and is_col_complete:
		pattern_bonus = BINGO_BONUS
	elif is_row_complete or is_col_complete:
		pattern_bonus = ROW_COL_BONUS
	breakdowns["pattern"] = pattern_bonus

	var total = base_coins + pattern_bonus
	return {
		"total": total,
		"base": base_coins,
		"breakdowns": breakdowns
	}

# --- SPENDING ---
func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		save_coins()
		coins_changed.emit(coins, -amount)
		print("Spent %d coins! Remaining: %d" % [amount, coins])
		return true
	else:
		print("Not enough coins! Need %d, have %d" % [amount, coins])
		return false

# --- GETTERS ---
func get_coins() -> int:
	"""Get current coin balance"""
	return coins

# ✅ ADDED: Get lifetime earnings
func get_total_coins() -> int:
	"""Get total coins earned (lifetime) - for Badge 4"""
	return total_coins_earned

# --- SAVE / LOAD ---
func save_coins():
	var save_data = {
		"coins": coins,
		"total_earned": total_coins_earned  # ✅ ADDED: Save lifetime
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)  # ✅ CHANGED: Save dictionary instead of just coins
		file.close()
		print("Coins saved: %d (lifetime: %d)" % [coins, total_coins_earned])
	else:
		print("ERROR: Could not save coins!")

func load_coins():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			
			# ✅ ADDED: Handle both old (int) and new (dict) save formats
			if data is Dictionary:
				coins = data.get("coins", 0)
				total_coins_earned = data.get("total_earned", 0)
			elif data is int:
				# Old save format - just had coins
				coins = data
				total_coins_earned = data  # Assume all current coins were earned
			
			file.close()
			print("Coins loaded: %d (lifetime: %d)" % [coins, total_coins_earned])
	else:
		coins = 0
		total_coins_earned = 0
		print("No save file found - starting with 0 coins")

# --- DEBUG (OPTIONAL) ---
func reset_all():
	"""Reset all coins and lifetime earnings"""
	coins = 0
	total_coins_earned = 0
	save_coins()
	coins_changed.emit(coins, 0)
	print("⚠️ All coins reset!")
