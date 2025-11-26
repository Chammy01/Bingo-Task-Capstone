extends "res://base_scene.gd"  # Inherit background functionality

var tracks = [
	{
		"id": "Blossom",
		"name": "Japanese Chill",
		"price": 100,
		"atlas": "res://Background/woodenbtn.png",
		"region": Rect2(0, 627, 147, 202),
		"is_owned": false,
		"background_theme": "theme_sakura"
	},
	{
		"id": "Valley",
		"name": "Nature Vibes",
		"price": 150,
		"atlas": "res://Background/woodenbtn.png",
		"region": Rect2(153, 627, 147, 202),
		"is_owned": false,
		"background_theme": "theme_valley"
	},
	{
		"id": "Horizon",
		"name": "Light Music",
		"price": 200,
		"atlas": "res://Background/woodenbtn.png",
		"region": Rect2(305, 627, 147, 202),
		"is_owned": false,
		"background_theme": "theme_horizon"
	},
	{
		"id": "DefaultTrack",
		"name": "DefaultTrack",
		"atlas": "res://Background/woodenbtn.png",
		"region": Rect2(0, 834, 147, 202),
		"is_owned": true,
		"background_theme": "default"
	}
]

const SETTINGS_POPUP = preload("res://SettingsPopup.tscn")

@onready var card1 = $CardContainer/Card1
@onready var card2 = $CardContainer/Card2
@onready var card3 = $CardContainer/Card3
@onready var card4 = $CardContainer/Card4
@onready var popup = $MusicPreviewPopup
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var back_button: TextureButton = $BackButton

func _ready():
	super._ready()  # Call base _ready() first for background
	
	print("=== SHOP SCENE STARTING ===")
	
	# Verify nodes exist
	print("Card1: %s" % (card1 != null))
	print("Card2: %s" % (card2 != null))
	print("Card3: %s" % (card3 != null))
	print("Card4: %s" % (card4 != null))
	print("Popup: %s" % (popup != null))
	print("BackButton: %s" % (back_button != null))
	
	if not popup:
		push_error("❌ MusicPreviewPopup not found! Did you instance it in the scene?")
		return
	
	# Setup cards
	_setup_cards()
	
	# Connect signals
	_connect_signals()
	
	# Connect popup signals
	popup.purchase_confirmed.connect(_on_purchase_confirmed)
	popup.purchase_failed.connect(_on_purchase_failed)
	popup.preview_playing.connect(_on_preview_playing)
	popup.popup_closed.connect(_on_popup_closed)
	
	print("✓ Shop ready!")

func _on_settings_pressed() -> void:
	button_sound.play()
	await get_tree().create_timer(0.2).timeout
	
	var popup_inst = SETTINGS_POPUP.instantiate()
	get_tree().root.add_child(popup_inst)
	popup_inst.settings_closed.connect(_on_settings_closed)
	
	print("⚙️ Settings popup opened")

func _on_settings_closed():
	_apply_audio_settings()
	print("⚙️ Settings closed")

func _apply_audio_settings():
	var music_on = SaveManager.get_setting("music_enabled", true)
	var sfx_on = SaveManager.get_setting("sfx_enabled", true)
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 0.0 if music_on else -80.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 0.0 if sfx_on else -80.0)
	
	print("✓ Audio settings applied: Music=%s, SFX=%s" % [music_on, sfx_on])

func _setup_cards():
	var cards = [card1, card2, card3, card4]
	for i in range(cards.size()):
		var card = cards[i]
		var data = tracks[i]
		data.is_owned = MusicManager.is_owned(data.id)
		data.is_current = MusicManager.current_track == data.id
		if card and card.has_method("setup"):
			card.setup(data)

func _connect_signals():
	print("--- Connecting card signals ---")
	if card1:
		card1.card_clicked.connect(_on_card_clicked)
		print("✓ Card1 connected")
	if card2:
		card2.card_clicked.connect(_on_card_clicked)
		print("✓ Card2 connected")
	if card3:
		card3.card_clicked.connect(_on_card_clicked)
		print("✓ Card3 connected")
	if card4:
		card4.card_clicked.connect(_on_card_clicked)
		print("✓ Card4 connected")

func _on_card_clicked(track_data: Dictionary):
	print("\n=== CARD CLICKED ===")
	print("Track: %s" % track_data.get("name", "?"))
	print("Track ID: %s" % track_data.get("id", "?"))
	
	if popup:
		popup.show_preview(track_data)
	
	await get_tree().create_timer(0.3).timeout
	print("Popup should be visible")

func _on_purchase_confirmed(track_id: String):
	# Find the track data
	var purchased_track = null
	for i in range(tracks.size()):
		if tracks[i].id == track_id:
			tracks[i].is_owned = true
			purchased_track = tracks[i]
			break
	
	# Change theme if this track has one
	if purchased_track and purchased_track.has("background_theme"):
		var theme_id = purchased_track["background_theme"]
		ThemeManager.set_theme(theme_id)
		var theme_name = ThemeManager.get_theme_name(theme_id)
		Toast.show_toast("🎨 Theme unlocked: %s!" % theme_name, 2.0)
		print("✓ Theme changed to: %s" % theme_name)
	
	_setup_cards()
	Toast.show_toast("✅ Purchased: %s" % track_id, 2.0)

func _on_purchase_failed(track_id: String):
	Toast.show_toast("❌ Not enough coins to buy %s" % track_id, 2.0)

func _on_preview_playing(track_name: String):
	Toast.show_toast("▶ Playing preview: %s" % track_name, 1.5)

func _on_popup_closed():
	print("Popup closed")

func _on_back_pressed() -> void:
	print("⬅️ Back button pressed")
	button_sound.play()
	get_tree().change_scene_to_file("res://main_menu.tscn")
