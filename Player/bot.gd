extends CharacterBody3D

const JUMP_VELOCITY = 5.5

# Stats
@export var speed: float = 7.5
@export var health: int = 100
@export var armor: int = 0

@export var bullets: int = 50
@export var shells: int = 24

# Weapons [Listed Here By Strength Rather Than In Accordance With Num Keys]
@onready var weapon_0 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Knife")
@onready var weapon_1 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Pistol")
@onready var weapon_2 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Shotgun")
@onready var weapon_3 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Automatic Gun")
@onready var weapon_4 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Super Shotgun")

var weapon_anim_key_map: Dictionary = {}
var weapon_attack_anim_map: Dictionary = {}

@onready var current_weapon = null
@onready var weapons = [weapon_0, weapon_1]

var weapon_index_map: Dictionary = {}
var index_weapon_map: Dictionary = {}
var is_switching_weapon: bool = false

var target = null
var target_dist: float
var retreating: bool = false

@onready var shoot_raycast = get_node("Head/Shoot_Raycast")

# Animation Tree
@onready var animation_tree: AnimationTree = $Character_01/AnimationTree
@onready var base_state_machine = animation_tree.get("parameters/BaseStateMachine/playback")
@onready var weapon_state_machine = animation_tree.get("parameters/WeaponStateMachine/playback")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Multiplayer
var multiplayer_id: int
var username = "Bot: " + str(multiplayer_id)

# How each target position for shots will be offset to introduce inaccuracy
var aim_offset = Vector3(0, 0, 0)
const aim_offset_amount: float = 0.25 

signal respawn(bot)
signal update_scoreboard()

func _enter_tree():
	set_multiplayer_authority(1)
	multiplayer_id = 1
	
func _ready() -> void:
	
	$"Name Tag".text = username
	
	_build_weapon_maps()
	switch_to_best_weapon()
	
	# Process frame before beginning monitoring as not moved to spawn pos yet
	await get_tree().process_frame
	
	$"Head/Player Detection".monitoring = true
	$BeehaveTree.enabled = true
	
func _physics_process(delta):
	
	if not multiplayer.is_server():
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
		# If retreating, then needs momentum to jump back
		if retreating:
			navigate(delta)
	else:
		# Doesn't use navigation agent when in air, allowing jumps
		navigate(delta)
		
	move_and_slide()
	
	# Assign movement animations
	var moving: bool = (Vector3i(velocity) != Vector3i.ZERO)
	var falling: bool = not is_on_floor()
	
	rpc("_sync_switch_state", falling, moving)
	
func navigate(_delta):
	
	# Target may have been freed (e.g. died) without being cleared here first
	if target and not is_instance_valid(target):
		target = null
	
	if target:
		
		var target_pos = $NavigationAgent3D.get_next_path_position()
		var direction = (target_pos - global_position).normalized()
		
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if !retreating:
			$Head.look_at(target.global_position + aim_offset)
			
			# Have Y Axis Look At Target
			$Character_01.look_at(target.global_position)
			$Character_01.global_rotation.x = 0
			$Character_01.rotation.z = 0
		
		if target is CharacterBody3D:
			if current_weapon:
				
				# Checks that animations are finished and that there's enough ammo. If latter is true, then func uses it
				if can_attack() and weapon_state_machine.get_current_node().contains("Idle") and has_ammo(current_weapon, true):
					current_weapon.shoot_weapon(target, true, username)
					rpc("weapon_attack_anim", weapon_index_map[current_weapon])
	else:
		# No target: stop drifting on old velocity instead of sliding forever
		velocity.x = 0
		velocity.z = 0
					
func can_attack():
	
	if not is_instance_valid(target):
		target = null
		return false
		
	# Get info
	var enemy_dist = global_position.distance_squared_to(target.global_position)
	var raycast_target = shoot_raycast.get_collider()
	var enemy_in_sight = raycast_target and raycast_target.get_collision_layer_value(2)
	
	# Check if bot is too close to player and needs to strafe back
	if enemy_dist < 1.5:
		if current_weapon != weapon_0:
			retreating = true
			speed = -abs(speed)
			jump()
			
			# Starts countdown to when retreat ends
			$"Retreat Timer".start()
			
	elif enemy_dist < current_weapon.attack_range and enemy_in_sight:
		velocity.x = 0
		velocity.z = 0
		
	# Check if target is in line of sight
	if !enemy_in_sight:
		return false
		
	# Check if target can be hit with weapon
	target_dist = shoot_raycast.global_position.distance_squared_to(shoot_raycast.get_collision_point())
	var in_range = (target_dist < current_weapon.attack_range)
	
	if !in_range:
		switch_to_best_weapon()
		return false
		
	return true
	
func jump():
	velocity.y = JUMP_VELOCITY
	
func find_group_items(target_group):
	
	var best_item = null
	var best_item_dist = 9999999
	
	for item in get_tree().get_nodes_in_group(target_group):
		if item.visible:
			var item_dist = global_position.distance_squared_to(item.global_position)
			if (item_dist < best_item_dist):
				best_item = item
				best_item_dist = item_dist
			
	if best_item:
		target = best_item
		$NavigationAgent3D.target_position = target.global_position
		
func switch_to_best_weapon():
	
	var best_weapon_index = 0
	
	# Get distance but check for valid target
	if target and is_instance_valid(target):
		target_dist = shoot_raycast.global_position.distance_squared_to(target.global_position)
	else:
		target_dist = -1
		
	for weapon in weapons:
		var compare_index = weapon_index_map.get(weapon)
		
		# Uses ordering of weapons in map to determine strength
		if (compare_index > best_weapon_index):
			
			var compare_weapon = index_weapon_map.get(compare_index)
			
			# Checks if the weapon at the index has ammo
			if (has_ammo(compare_weapon)):
				# Checks if weapon has range to shoot enemy
				if target_dist - 15 <= compare_weapon.attack_range:
					best_weapon_index = compare_index
					
	rpc("_sync_switch_weapon", best_weapon_index)
	
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage, killer_name):
	
	# Calculates Damage To Bot Based On Armor
	var armor_resist = (0.75 * damage)
	var armor_damage = min(armor_resist, armor) 
	
	health -= damage - (damage * (armor_resist/100)) + (armor_resist - armor_damage)
	armor -= armor_damage
	
	if health <= 0:
		die()
		update_scoreboard.emit(killer_name)
	else:
		$Pain.play()
		
func die():
	rpc("_sync_die")

@rpc("any_peer", "call_local", "reliable")
func _sync_die():
	
	await get_tree().process_frame # Away frame so kill can be processed for other players
	
	health = 100
	armor = 0
	
	if current_weapon:
		current_weapon.visible = false
		current_weapon = null
	
	weapon_0.visible = true
	weapons = [weapon_0]
	
	base_state_machine.travel("RESET")
	weapon_state_machine.travel("RESET")
	
	respawn.emit(self)
	
func _on_navigation_timer_timeout() -> void:
	if target:
		if not is_instance_valid(target):
			target = null
		if !retreating:
			$NavigationAgent3D.target_position = target.global_position
	
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body != self and !retreating:
		target = body
		$NavigationAgent3D.target_position = target.global_position
	
func _build_weapon_maps():
	weapon_index_map = {
		weapon_0: 0, weapon_1: 1, weapon_2: 2, weapon_3: 3, weapon_4: 4
	}
	index_weapon_map = {
		0: weapon_0, 1: weapon_1, 2: weapon_2, 3: weapon_3, 4: weapon_4
	}
	
	weapon_anim_key_map = {
		weapon_0: "Knife",
		weapon_1: "Pistol",
		weapon_2: "Shotgun",
		weapon_3: "Auto",
		weapon_4: "Super Shotgun"
	}
	weapon_attack_anim_map = {
		weapon_0: "Melee Attack",
		weapon_1: "Pistol Shoot",
		weapon_2: "Shotgun Shoot",
		weapon_3: "Auto Shoot",
		weapon_4: "Super Shotgun Shoot"
	}
	
@rpc("any_peer", "call_local", "reliable")
func _sync_switch_state(falling: bool, moving: bool):
	if falling:
		base_state_machine.travel("Fall")
	elif moving:
		base_state_machine.travel("Walk")
	else:
		base_state_machine.travel("Idle")
		
@rpc("any_peer", "call_local", "reliable")
func weapon_attack_anim(weapon_index):
	var weapon = index_weapon_map.get(weapon_index)
	var anim_name = weapon_attack_anim_map.get(weapon)
	if anim_name:
		weapon_state_machine.travel(anim_name)
	
@rpc("any_peer", "call_local", "reliable")
func _sync_switch_weapon(weapon_index: int):
	if multiplayer.get_remote_sender_id() != 0:
		if multiplayer.get_remote_sender_id() != multiplayer_id:
			return
	var weapon = index_weapon_map.get(weapon_index, null)
	if weapon:
		switch_weapon(weapon)
		
func switch_weapon(new_weapon):
	if new_weapon in weapons and current_weapon != new_weapon and !is_switching_weapon:
		
		if current_weapon:
			# Makes sure switch does not happen while animation is playing
			if !weapon_state_machine.get_current_node().contains("Idle"):
				return
				
			is_switching_weapon = true
			unequip_weapon()
			
			await animation_tree.animation_finished
			
			equip_weapon(new_weapon)
			is_switching_weapon = false
			
		else:
			# No current weapon so no unequip animation to wait for
			equip_weapon(new_weapon)
		
func unequip_weapon():
	var idx = weapon_index_map.get(current_weapon, -1)
	if idx != -1:
		if is_multiplayer_authority():
			rpc("_sync_unequip_anim", idx)
		else:
			_sync_unequip_anim(idx)
	current_weapon.is_selected = false
	
func equip_weapon(weapon):
	var idx = weapon_index_map.get(weapon, -1)
	if idx != -1:
		if is_multiplayer_authority():
			rpc("_sync_equip_anim", idx)
		else:
			_sync_equip_anim(idx)
	current_weapon = weapon
	current_weapon.is_selected = true
	
@rpc("any_peer", "call_local", "reliable")
func _sync_unequip_anim(weapon_index: int):
	var weapon = index_weapon_map.get(weapon_index)
	var anim_key = weapon_anim_key_map.get(weapon)
	
	if not anim_key:
		return
	if anim_key == "Super Shotgun":
		anim_key = "Shotgun"
		
	weapon_state_machine.travel("Lower " + anim_key)
	var time = $Character_01/AnimationPlayer.get_animation("Raise " + anim_key).length
	await get_tree().create_timer(time).timeout
	weapon.visible = false
	
@rpc("any_peer", "call_local", "reliable")
func _sync_equip_anim(weapon_index: int):
	var weapon = index_weapon_map.get(weapon_index)
	var anim_key = weapon_anim_key_map.get(weapon)
	
	if not anim_key:
		return
	if anim_key == "Super Shotgun":
		anim_key = "Shotgun"
		
	weapon_state_machine.travel("Raise " + anim_key)
	weapon.visible = true
	
	await animation_tree.animation_finished
	
func add_new_weapon(new_weapon):
	# If new weapon then it adds, if not ammo is obtained
	match new_weapon:
		"Pistol":
			if weapon_1 in weapons:
				bullets += 12
			else:
				bullets += 6
				
				# Adds weapon
				weapons.append(weapon_1)
				
		"Shotgun":
			if weapon_2 in weapons:
				shells += 12
			else:
				shells += 6
				
				# Adds weapon
				weapons.append(weapon_2)
				
		"Super Shotgun":
			if weapon_4 in weapons:
				shells += 12
			else:
				shells += 6
				
				# Adds weapon
				weapons.append(weapon_4)
				
		"Automatic Gun":
			if weapon_3 in weapons:
				bullets += 50
			else:
				bullets += 25
				
				# Adds weapon
				weapons.append(weapon_3)
				
	# Switches to new best weapon
	switch_to_best_weapon()
	
# Checks if there is enough ammo and uses if needed
func has_ammo(weapon, using_ammo: bool =false):
	match weapon.ammo_type:
		"Bullets":
			if (bullets >= weapon.ammo_consumption):
				if (using_ammo):
					bullets -= weapon.ammo_consumption
				return true
			else:
				if (using_ammo):
					switch_to_best_weapon()
				return false
		"Shells":
			if (shells >= weapon.ammo_consumption):
				if (using_ammo):
					shells -= weapon.ammo_consumption
				return true
			else:
				if (using_ammo):
					switch_to_best_weapon()
				return false
		"N/A":
			return true # Infinite ammo weapons always have ammo
			
func _on_weapon_check_timer_timeout() -> void:
	switch_to_best_weapon()

func _on_aim_offset_timer_timeout() -> void:
	aim_offset = Vector3(
	randf_range(-aim_offset_amount, aim_offset_amount),
	randf_range(-aim_offset_amount, aim_offset_amount),
	randf_range(-aim_offset_amount, aim_offset_amount)
)

func _on_navigation_agent_3d_link_reached(_details: Dictionary) -> void:
	jump()

func _on_item_pickup_area_body_entered(body: Node3D) -> void:
	# Picks Up Object If It Is A Pickup
	if "weapon" in body:
		add_new_weapon(body.weapon)
	else:
		health += body.health_amount
		armor += body.armor_amount
		
		if body.ammo_type == "Bullets":
			bullets += body.ammo_amount
		else:
			shells += body.ammo_amount
	
	body.rpc("activate")
	
func _on_retreat_timer_timeout() -> void:
	retreating = false
	speed = abs(speed)
