extends Sprite2D

# Reference to the coin count label node
@onready var coin_label: Label = $CoinLabel

# Original scale of coin_label to restore after animation
var original_scale: Vector2 = Vector2(0.455, 0.455)

func _ready():
	"""
	Initialize the coin jar, connect to currency change signal,
	and store the original scale for animation reference.
	"""
	CurrencyManager.coins_changed.connect(_on_coins_changed)
	update_display()
	
	# Store the actual scale from inspector (overrides default)
	original_scale = coin_label.scale
	
	print("Coin Jar initialized - Current coins: %d" % CurrencyManager.get_coins())
	print("Original scale: %v" % original_scale)

func update_display():
	"""Update coin label text with current coin amount"""
	var current_coins = CurrencyManager.get_coins()
	coin_label.text = str(current_coins)

func _on_coins_changed(new_amount: int, _change_amount: int):
	"""
	Handler for currency change signal.
	Update label and play pop animation.
	"""
	coin_label.text = str(new_amount)
	_animate_pop()

func _animate_pop():
	"""
	Animate the coin_label by scaling up then back to original.
	Enlarges approximately 1.5x the original scale.
	"""
	var enlarged_scale = original_scale * 1.5
	
	var tween = create_tween()
	
	tween.tween_property(coin_label, "scale", enlarged_scale, 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(coin_label, "scale", original_scale, 0.2)
	
	# Await tween completion to ensure scale restored exactly
	await tween.finished
	coin_label.scale = original_scale
