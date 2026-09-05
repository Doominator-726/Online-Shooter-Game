extends StaticBody3D

@export var weapon: String = "Automatic Gun"

@export var touch_activation: bool = true
@export var shot_activation: bool = false

signal add_weapon(weapon)

@rpc("any_peer", "call_local", "reliable")
func activate():
	
	if $"Pickup Sound".stream:
		$CollisionShape3D.disabled = true
		visible = false
		
		# Remove from groups to avoid confusion
		for group in get_groups():
			remove_from_group(group)
		
		$"Pickup Sound".play()
	else:
		await get_tree().process_frame # Process rpc stuff
		queue_free()
	
func pick_up():
	
	add_weapon.emit(weapon)
	
func _on_pickup_sound_finished():
	queue_free()
	
