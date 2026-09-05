extends StaticBody3D

@export var health_amount: int = 0
@export var armor_amount: int = 0

@export var ammo_amount: int = 5
@export var ammo_type: String = "Bullets"

@export var touch_activation: bool = true
@export var shot_activation: bool = false

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
	
	Globals.player_health += health_amount
	Globals.player_armor += armor_amount
	
	if ammo_type:
		match ammo_type:
			"Bullets":
				Globals.player_bullets += ammo_amount
			"Shells":
				Globals.player_shells += ammo_amount
				
func _on_pickup_sound_finished():
	queue_free()
