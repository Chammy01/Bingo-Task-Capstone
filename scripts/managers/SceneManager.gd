# SceneManager.gd
extends Node

# Reference to our animation scene
var transition_scene = preload("res://transition_layer.tscn")
var current_transition = null

# This is the main function we'll call from anywhere in the game.
func change_scene(target_scene_path: String):
	# Don't start a new transition if one is already happening.
	if current_transition and is_instance_valid(current_transition):
		return

	# Create an instance of our transition layer.
	current_transition = transition_scene.instantiate()
	# Add it to the scene tree.
	get_tree().root.add_child(current_transition)

	# Play the fade-out animation.
	current_transition.get_node("AnimationPlayer").play("fade_to_black")

	# Wait for the animation to finish.
	await current_transition.get_node("AnimationPlayer").animation_finished

	# --- The screen is now black ---

	# Change the actual scene.
	get_tree().change_scene_to_file(target_scene_path)

	# Play the fade-in animation on the same transition layer.
	current_transition.get_node("AnimationPlayer").play("fade_from_black")

	# Wait for the fade-in to finish.
	await current_transition.get_node("AnimationPlayer").animation_finished

	# The new scene is visible. Remove the transition layer.
	current_transition.queue_free()
	current_transition = null
