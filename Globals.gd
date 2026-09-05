extends Node

# Detection Signals
signal detection_status_changed

# Ammo Signals
signal ammo_count_changed
signal ammo_type_changed
signal ammo_message(type, amount)

# Health/Armor Signals
signal player_health_changed(change)
signal player_armor_changed(change)

var pause_menu_open = false

# Multiplayer
var creating_server: bool = false
var username: String = "Default Username"

# Scoreboard
var scoreboard = []
signal populate_scoreboard()

# Death
signal death_status_change()

# Is an interactable object being selected
var is_object_detected: bool = false:
	
	set(value):
		
		is_object_detected = value
		detection_status_changed.emit()

# Is an enemy or other target within the range of fire
var is_shoot_target_detected: bool = false:
	
	set(value):
		
		is_shoot_target_detected = value
		detection_status_changed.emit()
		
		
# Player Stats
var player_position: Vector3
var player_health: int = 500:
	
	set(value):
		
		# Gets new health value that cannot exceed 100, if there is a new value, it updates UI and the value
		var new_value = min(value, 500)
		if new_value != player_health:
			
			player_health_changed.emit(new_value - player_health)
			player_health = new_value
			
var player_armor: int = 0:
	set(value):
		
		# Gets new armor value that cannot exceed 100, if there is a new value, it updates UI and the value
		var new_value = min(value, 100)
		if new_value != player_armor:
			
			player_armor_changed.emit(new_value - player_armor)
			player_armor = new_value
		
# Global variables for ammo, it represents the amount of ammo in the current weapon
var player_bullets: int = 50:
	
	set(value):
		
		if value > player_bullets:
			ammo_message.emit("Bullets", value - player_bullets)
		player_bullets = value
		ammo_count_changed.emit()

var player_shells: int = 24:
	
	set(value):
		
		if value > player_shells:
			ammo_message.emit("Shells", value - player_shells)
		player_shells = value
		ammo_count_changed.emit()
		
var player_ammo_type: String = " ":
	set(value):
		player_ammo_type = value
		ammo_type_changed.emit()
		
var is_alive: bool = true:
	set(value):
		is_alive = value
		death_status_change.emit()
