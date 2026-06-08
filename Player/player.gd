extends CharacterBody3D

# God Mode
@export var god_mode = false

# Movement
var speed = 7.5
@onready var prev_step_pos = global_position
var is_airborne: bool = false
const JUMP_VELOCITY = 5.5
const SENSITIVITY = 0.003

# Head Bobbing
const BOBBING_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
var bob_time = 0.0

# Animation Tree
@onready var animation_tree: AnimationTree = $Character_01/AnimationTree

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Head
@onready var camera = $Head/Camera3D
@onready var subviewport_camera = $"CanvasLayer/SubViewportContainer/SubViewport/Subviewport Camera"
@onready var head = $Head

# Raycasts
@onready var interact_raycast = $Head/Camera3D/Interact_Raycast
@onready var shoot_raycast = $Head/Camera3D/Shoot_Raycast

# Weapons
@onready var weapon_0 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Knife")
@onready var weapon_1 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Pistol")
@onready var weapon_2 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Automatic Gun")
@onready var weapon_3 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Shotgun")
@onready var weapon_4 = get_node("Character_01/GeneralSkeleton/BoneAttachment3D/Super Shotgun")

@onready var current_weapon = null
@onready var weapons = [weapon_0, weapon_1]

var weapon_index_map: Dictionary = {}
var index_weapon_map: Dictionary = {}

# Multiplayer
var multiplayer_id: int

# Animations
@onready var base_state_machine = $Character_01/AnimationTree.get("parameters/BaseStateMachine/playback")
@onready var weapon_state_machine = $Character_01/AnimationTree.get("parameters/WeaponStateMachine/playback")

# Signals
signal weapon_message(weapon)
signal player_death

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	multiplayer_id = name.to_int()
	
func _ready():
	
	camera.current = is_multiplayer_authority()
	subviewport_camera.current = is_multiplayer_authority()
	
	_build_weapon_maps()
	
	if not is_multiplayer_authority(): return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Connects All of The Weapon Pickup Signals When The Game Starts
	for weapon in get_tree().get_nodes_in_group("pickupWeapons"):
		weapon.connect("add_weapon", add_new_weapon)
		
	weapon_0.set_to_hud_visibility()
	weapon_1.set_to_hud_visibility()
	weapon_2.set_to_hud_visibility()
	weapon_3.set_to_hud_visibility()
	weapon_4.set_to_hud_visibility()
		
	switch_weapon(current_weapon)

func _unhandled_input(event):
	
	if not is_multiplayer_authority(): return
	
	# Mouse Aiming
	if event is InputEventMouseMotion and !Globals.pause_menu_open:
		rotate_y(-event.relative.x * SENSITIVITY)
		
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
		
func _process(_delta):
	if not is_multiplayer_authority(): return
	subviewport_camera.set_global_transform(camera.get_global_transform())
	
func _physics_process(delta):
	
	if not is_multiplayer_authority(): return
	
	Globals.player_position = global_position
	
	# Headbob
	bob_time += delta * velocity.length() * float(is_on_floor())
	
	var x_transform = cos(bob_time * BOBBING_FREQUENCY / 2) * BOB_AMPLITUDE
	var y_transform = sin(bob_time * BOBBING_FREQUENCY) * BOB_AMPLITUDE
	
	camera.transform.origin = Vector3(x_transform, y_transform, 0)
	
	# Footsteps
	if is_on_floor() and (velocity.x != 0) and (velocity.z != 0):
		if prev_step_pos.distance_to(global_position) > 2:
			$"Step Sound".play()
			prev_step_pos = global_position
			
	if Globals.pause_menu_open:
		velocity = Vector3.ZERO
		return

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("Quit"):
		$"../".exit_game(multiplayer_id)
		get_tree().quit()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if is_airborne:
			$"Ground Impact".play()
			is_airborne = false
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		is_airborne = true
		
		# Floats determine air control and force of inhertia
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
		
		# Use gravity
		velocity.y -= gravity * delta
		
	# Move and Slide
	move_and_slide()
	
	# Add the gravity and assign animations
	var moving: bool = (Vector3i(velocity) != Vector3i.ZERO)
	var falling: bool = not is_on_floor()
		
	# Switching states
	if is_multiplayer_authority():
		rpc("_sync_switch_state", falling, moving)
	else:
		_sync_switch_state(falling, moving)
		
	# Crouching
	if Input.is_action_just_pressed("Crouch"):
		$AnimationPlayer.play("Crouch")
	elif Input.is_action_just_released("Crouch"):
		$AnimationPlayer.play_backwards("Crouch")
		
	# Flashlight
	if Input.is_action_just_pressed("Flashlight"):
		$Head/Camera3D/Flashlight.visible = !$Head/Camera3D/Flashlight.visible
		$Flashlight.play()
	
	# Handles Weaponary 
	if Input.is_action_just_pressed("weapon_zero"):
		rpc("_sync_switch_weapon", 0)
	elif Input.is_action_just_pressed("weapon_one"):
		rpc("_sync_switch_weapon", 1)
	elif Input.is_action_just_pressed("weapon_two"):
		rpc("_sync_switch_weapon", 2)
	elif Input.is_action_just_pressed("weapon_three"):
		rpc("_sync_switch_weapon", 3)
	elif Input.is_action_just_pressed("weapon_four"):
		rpc("_sync_switch_weapon", 4)
	
	# If there is an activatable object, it updates the UI
	var object = interact_raycast.get_collider()
	if object and "activate" in object:
		
		if object.touch_activation:
			Globals.is_object_detected = true
		
			# If the interact action is used, the object is activated/picked up
			if Input.is_action_just_pressed("Interact"):
				
				# Picks Up Object If It Is A Pickup
				if "pick_up" in object:
					object.pick_up()
				object.rpc("activate")
				
	else:
		Globals.is_object_detected = false
	
	if current_weapon:
		# Checks if there is a target in range to shoot
		var shoot_target = shoot_raycast.get_collider()
		var target_shootable = shoot_target and ("take_damage" in shoot_target or ("shot_activation" in shoot_target and shoot_target.shot_activation))
	
		if target_shootable:
		
			# Checks for enemy first since square 
			var target_dist = shoot_raycast.global_position.distance_squared_to(shoot_raycast.get_collision_point())
			Globals.is_shoot_target_detected = (target_dist < current_weapon.attack_range)
			
		else:
			Globals.is_shoot_target_detected = false
		
		# Checks for shooting
		if Input.is_action_pressed("Shoot"):
			
			# Checks that animations are finished and that there's enough ammo
			if current_weapon.can_shoot and use_ammo():
				current_weapon.shoot_weapon(shoot_target, Globals.is_shoot_target_detected)
				
				var using_melee_weapon = current_weapon == weapon_0
				if is_multiplayer_authority():
					rpc("weapon_attack_anim", using_melee_weapon)
				else:
					weapon_attack_anim(using_melee_weapon)
					
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage):
	
	if !god_mode:
		
		# Calculates Damage To Player Based On Armor
		var armor_resist = (0.75 * damage)
		var armor_damage = min(armor_resist, Globals.player_armor) 
		
		Globals.player_health -= damage - (damage * (armor_resist/100)) + (armor_resist - armor_damage)
		Globals.player_armor -= armor_damage
		
		if Globals.player_health < 0:
			player_death.emit()
		else:
			$Pain.play()
			
			
func _build_weapon_maps():
	weapon_index_map = {
		weapon_0: 0, weapon_1: 1, weapon_2: 2, weapon_3: 3, weapon_4: 4
	}
	index_weapon_map = {
		0: weapon_0, 1: weapon_1, 2: weapon_2, 3: weapon_3, 4: weapon_4
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
func weapon_attack_anim(is_melee):
	if (is_melee):
		weapon_state_machine.travel("Melee Attack")
		
@rpc("any_peer", "call_local", "reliable")
func _sync_switch_weapon(weapon_index: int):
	
	# Return if not server so other players don't equip weapon
	if not is_multiplayer_authority(): return
	
	var weapon = index_weapon_map.get(weapon_index)
	if weapon:
		switch_weapon(weapon)
		
func switch_weapon(new_weapon):
	
	# If you switch to a new weapon you have, it will unequip the current one and equip a new one
	# Also makes sure switch does not happen while animation is playing
	if new_weapon in weapons and current_weapon != new_weapon:
		
		if current_weapon:
			if weapon_state_machine.get_current_node() != "Knife Idle":
				return
			unequip_weapon()
			await $Character_01/AnimationTree.animation_finished
		equip_weapon(new_weapon)
		
func unequip_weapon():
	var idx = weapon_index_map.get(current_weapon, -1)
	if idx != -1:
		if is_multiplayer_authority():
			rpc("_sync_unequip_anim", idx)
		else:
			_sync_unequip_anim(idx)
	current_weapon.is_selected = false
	print("DONE")
	
func equip_weapon(weapon):
	var idx = weapon_index_map.get(weapon, -1)
	if idx != -1:
		if is_multiplayer_authority():
			rpc("_sync_equip_anim", idx)
		else:
			_sync_equip_anim(idx)
	Globals.player_ammo_type = weapon.ammo_type
	current_weapon = weapon
	current_weapon.is_selected = true
	
@rpc("any_peer", "call_local", "reliable")
func _sync_unequip_anim(weapon_index: int):
	
	weapon_state_machine.travel("Lower Knife")
	await $Character_01/AnimationTree.animation_finished
	index_weapon_map.get(weapon_index).visible = false
	
@rpc("any_peer", "call_local", "reliable")
func _sync_equip_anim(weapon_index: int):
	
	weapon_state_machine.travel("Raise Knife")
	index_weapon_map.get(weapon_index).visible = true
	
func add_new_weapon(new_weapon):
	# If new weapon then it switches, if not ammo is obtained
	match new_weapon:
		"Pistol":
			if weapon_1 in weapons:
				Globals.player_bullets += 12
			else:
				Globals.player_bullets += 6
				
				# Adds weapon and switches too it
				weapons.append(weapon_1)
				switch_weapon(weapon_1)
				
		"Shotgun":
			if weapon_3 in weapons:
				Globals.player_shells += 12
			else:
				Globals.player_shells += 6
				
				# Adds weapon and switches too it
				weapons.append(weapon_3)
				switch_weapon(weapon_3)
				
		"Super Shotgun":
			if weapon_4 in weapons:
				Globals.player_shells += 12
			else:
				Globals.player_shells += 6
				
				# Adds weapon and switches too it
				weapons.append(weapon_4)
				switch_weapon(weapon_4)
		"Automatic Gun":
			if weapon_2 in weapons:
				Globals.player_bullets += 50
			else:
				Globals.player_bullets += 25
				
				# Adds weapon and switches too it
				weapons.append(weapon_2)
				switch_weapon(weapon_2)
				
	weapon_message.emit(new_weapon)
	
# Checks if there is enough ammo and uses it if so
func use_ammo():
	match current_weapon.ammo_type:
		"Bullets":
			if (Globals.player_bullets - current_weapon.ammo_consumption >= 0):
				Globals.player_bullets -= current_weapon.ammo_consumption
				return true
			else:
				return false
		"Shells":
			if (Globals.player_shells - current_weapon.ammo_consumption >= 0):
				Globals.player_shells -= current_weapon.ammo_consumption
				return true
			else:
				return false
		"N/A":
			return true
			
