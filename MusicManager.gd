# ============================================
# File: scripts/MusicManager.gd
# Purpose: Manage background music library
# ============================================

extends Node

# ============================================
# CONSTANTS
# ============================================

const SAVE_FILE = "user://music_library.save"

# ============================================
# MUSIC CATALOG
# ============================================

# Define all available music tracks
const MUSIC_CATALOG = {
	"Blossom": {
		"name": "Blossom",
		"file": "res://music/Blossom.mp3",
		"price": 50,
		"owned": false,
		"background_theme": "theme_blossom"  # NEW: Links to sakura background
	},
	"Valley": {
		"name": "Valley",
		"file": "res://music/Nature.mp3",
		"price": 100,
		"owned": false,
		"background_theme": "theme_valley"  # NEW: Links to grass background
	},
	"Horizon": {
		"name": "Horizon",
		"file": "res://music/Horizon.mp3",
		"price": 150,
		"owned": false,
		"background_theme": "theme_horizon"  # NEW: Links to cloud background
	},
	"DefaultTrack": {
		"name": "DefaultTrack",
		"file": "res://music/DefaultTrack.mp3",
		"price": 0,
		"owned": true,
		"background_theme": "default"  # NEW: Default background
	},
	"Autumn": {
		"name": "Autumn",
		"file": "res://music/autumn.mp3",
		"price": 200,
		"owned": false,
		"background_theme": "theme_autumn"
	},
	"Snowy": {
		"name": "Snowy",
		"file": "res://music/snowy.mp3",
		"price": 250,
		"owned": false,
		"background_theme": "theme_snowy"
	}
}


# ============================================
# STATE
# ============================================

var owned_music: Dictionary = {}  # track_id: true
var current_track: String = "DefaultTrack"
var music_player: AudioStreamPlayer = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Load purchased music and previous current track
	load_music_library()
	
	# Play the previously selected or default track
	play_music(current_track)
	
	print("✓ MusicManager initialized: %d tracks owned" % owned_music.size())


# ============================================
# MUSIC PLAYBACK
# ============================================

func play_music(track_id: String):
	if not MUSIC_CATALOG.has(track_id):
		print("⚠️ Music track not found: %s" % track_id)
		return
	
	if not is_owned(track_id):
		print("⚠️ Music track not owned: %s" % track_id)
		return
	
	# Stop or mute the default music player node if it exists
	var default_music_player = get_node_or_null("/root/bg_music")
	if default_music_player and default_music_player.playing:
		default_music_player.stop()
		print("⏹ Default music stopped")
	
	var track_data = MUSIC_CATALOG[track_id]
	var music_file = load(track_data.file)
	if music_file:
		music_player.stop()
		music_player.stream = music_file
		music_player.play()
		current_track = track_id
		save_music_library()
		
		# NEW: Apply theme when switching music
		if track_data.has("background_theme"):
			ThemeManager.set_theme(track_data["background_theme"])
		
		print("🎵 Now playing: %s" % track_data.name)
	else:
		print("⚠️ Failed to load music file: %s" % track_data.file)

func stop_music():
	"""Stop current music"""
	music_player.stop()

func set_volume(volume_db: float):
	"""Set music volume"""
	music_player.volume_db = volume_db

# ============================================
# OWNERSHIP
# ============================================

func is_owned(track_id: String) -> bool:
	"""Check if player owns a music track"""
	if not MUSIC_CATALOG.has(track_id):
		return false
	
	# Default/free tracks are always owned
	if MUSIC_CATALOG[track_id].get("owned", false):
		return true
	
	# Check purchased tracks
	return owned_music.get(track_id, false)

func purchase_music(track_id: String) -> bool:
	"""Purchase a music track with coins"""
	if not MUSIC_CATALOG.has(track_id):
		print("⚠️ Invalid track ID: %s" % track_id)
		return false
	
	if is_owned(track_id):
		print("⚠️ Already owned: %s" % track_id)
		return false
	
	var track_data = MUSIC_CATALOG[track_id]
	var price = track_data.price
	
	# Check if player has enough coins
	if CurrencyManager.get_coins() < price:
		print("⚠️ Not enough coins! Need %d" % price)
		return false
	
	# Purchase
	if CurrencyManager.spend_coins(price):
		owned_music[track_id] = true
		save_music_library()
		
		# NEW: Apply theme when purchasing
		if track_data.has("background_theme"):
			ThemeManager.set_theme(track_data["background_theme"])
			print("🎨 Theme changed to: %s" % track_data["background_theme"])
		
		print("🎵 Purchased: %s for %d coins" % [track_data.name, price])
		return true
	
	return false

func get_all_tracks() -> Array:
	"""Get all music tracks with ownership info"""
	var tracks = []
	for track_id in MUSIC_CATALOG.keys():
		var track_data = MUSIC_CATALOG[track_id].duplicate()
		track_data["id"] = track_id
		track_data["is_owned"] = is_owned(track_id)
		track_data["is_current"] = (track_id == current_track)
		tracks.append(track_data)
	return tracks

# ============================================
# SAVE/LOAD
# ============================================

func save_music_library():
	"""Save purchased music"""
	var save_data = {
		"owned_music": owned_music,
		"current_track": current_track
	}
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("✓ Music library saved")

func load_music_library():
	"""Load purchased music"""
	if not FileAccess.file_exists(SAVE_FILE):
		owned_music = {}
		return
	
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var data = file.get_var()
		if data is Dictionary:
			owned_music = data.get("owned_music", {})
			current_track = data.get("current_track", "DefaultTrack")
		file.close()
		print("✓ Music library loaded: %d tracks owned" % owned_music.size())

# ============================================
# DEBUG
# ============================================

func unlock_all():
	"""Debug: Unlock all music"""
	for track_id in MUSIC_CATALOG.keys():
		owned_music[track_id] = true
	save_music_library()
	print("🎵 All music unlocked!")

func reset_library():
	"""Reset all purchases"""
	owned_music.clear()
	current_track = "DefaultTrack"
	save_music_library()
	print("⚠️ Music library reset!")
