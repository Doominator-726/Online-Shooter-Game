extends CanvasLayer

func _ready():
	
	# Connects signals for updating the crosshair
	Globals.connect('detection_status_changed', change_icon)
	
	# Updates signals relating to ammo displays
	Globals.connect('ammo_count_changed', update_ammo_count)
	Globals.connect('ammo_type_changed', update_ammo_type)
	Globals.connect('ammo_message', display_ammo_message)
	
	# Updates signals related to health and armor
	Globals.connect('player_health_changed', update_player_health)
	Globals.connect('player_armor_changed', update_player_armor)
	
	# Connect Button Sounds
	for button in $"Pause Menu/Options".get_children():
		button.connect("mouse_entered", $"Button Hover Sound".play)
		button.connect("button_down", $"Button Select Sound".play)
	
	# Updates these before game begins so a change does not need to happen for them to be set right
	update_ammo_count()
	update_ammo_type()
	update_player_health()
	
func change_icon():
	# Changes cursor based on detection
	if Globals.is_object_detected:
		$"Combat Hud/Cursor".texture = load("res://Graphics/UI/Combat/Item_Pickup.png")
	elif Globals.is_shoot_target_detected:
		$"Combat Hud/Cursor".texture = load("res://Graphics/UI/Combat/Enemy_Detect.png")
	else:
		$"Combat Hud/Cursor".texture = load("res://Graphics/UI/Combat/Normal.png")
		
func update_ammo_count():
	
	# Updates ammo count based on ammo type
	match Globals.player_ammo_type:
		"Bullets":
			$"Combat Hud/Player Stats/Ammo/Ammo Count".text = str(Globals.player_bullets)
		"Shells":
			$"Combat Hud/Player Stats/Ammo/Ammo Count".text = str(Globals.player_shells)
		_:
			$"Combat Hud/Player Stats/Ammo/Ammo Count".text = " "

func update_ammo_type():
	$"Combat Hud/Player Stats/Ammo/Ammo Title".text = Globals.player_ammo_type
	update_ammo_count()
func update_player_health(change=0):
	$"Combat Hud/Player Stats/Health/Health Count".text = str(Globals.player_health + change)
	if change > 0: display_message("Got " + str(change) + " Health")
func update_player_armor(change=0):
	$"Combat Hud/Player Stats/Armor/Armor Count".text = str(Globals.player_armor + change)
	if change > 0: display_message("Got " + str(change) + " Armor")
	
func _unhandled_input(_event):
	
	if Input.is_action_just_pressed("Pause"):
		# Pauses Game
		switch_pause_menu()

func display_message(text):
	$"Combat Hud/Message/messageLabel".text = text
	$"Combat Hud/Message/displayTimer".start()
	
func display_ammo_message(type, amount):
	display_message("Picked up " + str(amount) + " " + type)
	
func _on_player_real_life_weapon_message(weapon):
	display_message("Picked up " + weapon)
	
func _on_display_timer_timeout():
	$"Combat Hud/Message/messageLabel".text = ""
	
func _on_main_menu_button_up():
	("Quit")
	get_tree().quit()
	
func _on_quit_game_button_up():
	get_tree().quit()
	
func switch_pause_menu():
	
	Globals.pause_menu_open = !Globals.pause_menu_open
	
	# Pauses/Unpauses game depending on if it is already paused or unpaused
	$"Combat Hud".visible = !$"Combat Hud".visible
	$"Pause Menu".visible = !$"Pause Menu".visible
	
	if $"Pause Menu".visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
