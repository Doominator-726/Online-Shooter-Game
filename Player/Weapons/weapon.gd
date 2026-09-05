extends Node3D

@export var damage: int = 25

@export var ammo_type: String = "N/A"
@export var ammo_consumption: int = 1
@export var default_ammo_amount = 50

@export var attack_range: float = 20.0
@export var weapon_model: MeshInstance3D

var is_selected: bool = false

func set_to_hud_visibility():
	weapon_model.set_layer_mask_value(1, false)
	weapon_model.set_layer_mask_value(2, true)
	
func shoot_weapon(target, target_damagable):
	$"Attack Sound".play()
		
	rpc("_sync_shoot_anim")
		
	# Checks for target and uses "take_damage" to decide whether a target is an enemy or object
	if target_damagable and target:
		if "take_damage" in target:
			# Enemy Damage, returns true if target  is killed
			target.rpc_id(target.multiplayer_id, "take_damage", damage)
		else:
			# Object Damage
			target.activate(damage)
			
				
@rpc("any_peer", "call_local", "reliable")
func _sync_shoot_anim():
	$"Weapon Animation".play("Shoot")
