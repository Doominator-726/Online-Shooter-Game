extends CharacterBody3D

@export var username = "Player Username"

const JUMP_VELOCITY = 5.5

# Stats
@export var speed: float = 4.0
@export var damage: int = 10
@export var health: int = 100
@export var armor: int = 0

@export var bullets: int = 50
@export var shells: int = 24

# Weapons [Listed Here By Strength Rather Than In Accordance With Num Keys]
@onready var weapon_0 = get_node("Head/Knife")
@onready var weapon_1 = get_node("Head/Pistol")
@onready var weapon_2 = get_node("Head/Shotgun")
@onready var weapon_3 = get_node("Head/Automatic Gun")
@onready var weapon_4 = get_node("Head/Super Shotgun")

@onready var current_weapon = null
@onready var weapons = [weapon_0, weapon_1]

var weapon_index_map: Dictionary = {}
var index_weapon_map: Dictionary = {}
var is_switching_weapon: bool = false

var target = null
var target_dist: float
var retreating: bool = false

@onready var shoot_raycast = get_node("Head/Shoot_Raycast")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var multiplayer_id: int

# How each target position for shots will be offset to introduce inaccuracy
var aim_offset = Vector3(0, 0, 0)
const aim_offset_amount: float = 0.25 

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
	else:
		# Doesn't use navigation agent when in air, allowing jumps
		navigate(delta)
		
	move_and_slide()
	
func navigate(_delta):
	
	if target:
		
		var target_pos = $NavigationAgent3D.get_next_path_position()
		var direction = (target_pos - global_position).normalized()
		
		print(target_pos)
		
		direction.y = 0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if !retreating:
			$Head.look_at(target.global_position + aim_offset)
		
		if target is CharacterBody3D:
			if current_weapon and current_weapon.can_shoot:
				
				# Checks that animations are finished and that there's enough ammo. If latter is true, then func uses it
				if can_attack() and has_ammo(current_weapon, true):
					current_weapon.shoot_weapon(target, true)
				
func can_attack():
	
	# Check if bot is too close to player and needs to strafe back
	var enemy_dist = global_position.distance_squared_to(target.global_position)
	if enemy_dist < 1:
		if current_weapon != weapon_0:
			retreating = true
			print("Strafe Back")
			$NavigationAgent3D.target_position = global_position - velocity
	else:
		retreating = false
		
	# Check if target is in line of sight
	var raycast_target = shoot_raycast.get_collider()
	var in_sight = raycast_target and raycast_target.get_collision_layer_value(2)
	if !in_sight:
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
		print("Best Item")
		$NavigationAgent3D.target_position = target.global_position
		
func switch_to_best_weapon():
	
	var best_weapon_index = 0
	
	if target:
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
				if target_dist - 10 <= compare_weapon.attack_range:
					best_weapon_index = compare_index
			
	rpc("_sync_switch_weapon", best_weapon_index)
	
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage_taken: int):
	health -= damage_taken
	if health <= 0:
		die()

func die():
	rpc("_sync_die")

@rpc("authority", "call_local", "reliable")
func _sync_die():
	queue_free()
	
func _on_navigation_timer_timeout() -> void:
	if target and !retreating:
		print("Nav Timer")
		$NavigationAgent3D.target_position = target.global_position
	
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body != self:
		target = body
		print("Body Detect")
		$NavigationAgent3D.target_position = target.global_position
	
func _build_weapon_maps():
	weapon_index_map = {
		weapon_0: 0, weapon_1: 1, weapon_2: 2, weapon_3: 3, weapon_4: 4
	}
	index_weapon_map = {
		0: weapon_0, 1: weapon_1, 2: weapon_2, 3: weapon_3, 4: weapon_4
	}
	
@rpc("any_peer", "call_local", "reliable")
func _sync_switch_weapon(weapon_index: int):
	if multiplayer.get_remote_sender_id() != 0:
		if multiplayer.get_remote_sender_id() != multiplayer_id:
			return
	var weapon = index_weapon_map.get(weapon_index, null)
	if weapon:
		switch_weapon(weapon)
		
func switch_weapon(new_weapon):
	if new_weapon in weapons and current_weapon != new_weapon and !$"Weapon Animations".is_playing() and !is_switching_weapon:
		is_switching_weapon = true
		if current_weapon:
			unequip_weapon()
			# Wait for unequip animation to finish before equipping
			$"Weapon Animations".animation_finished.connect(func(_anim_name):
				equip_weapon(new_weapon)
				is_switching_weapon = false
			, CONNECT_ONE_SHOT)
		else:
			# No current weapon so no unequip animation to wait for
			equip_weapon(new_weapon)
			is_switching_weapon = false
		
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
	match weapon_index:
		0: 
			$"Weapon Animations".play("Lower Knife")
		1: 
			$"Weapon Animations".play("Lower Pistol")
		2: 
			$"Weapon Animations".play("Lower Shotgun")
		3: 
			$"Weapon Animations".play("Lower Automatic Gun")
		4: 
			$"Weapon Animations".play("Lower Super Shotgun")

@rpc("any_peer", "call_local", "reliable")
func _sync_equip_anim(weapon_index: int):
	match weapon_index:
		0: 
			$"Weapon Animations".play_backwards("Lower Knife")
		1: 
			$"Weapon Animations".play_backwards("Lower Pistol")
		2: 
			$"Weapon Animations".play_backwards("Lower Shotgun")
		3: 
			$"Weapon Animations".play_backwards("Lower Automatic Gun")
		4: 
			$"Weapon Animations".play_backwards("Lower Super Shotgun")
	
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

func _on_navigation_agent_3d_link_reached(details: Dictionary) -> void:
	jump()

func _on_item_pickup_area_body_entered(body: Node3D) -> void:
	# Picks Up Object If It Is A Pickup
	if "weapon" in body:
		add_new_weapon(body.weapon)
	body.rpc("activate")
	
