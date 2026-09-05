extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene
@export var bot_scene: PackedScene

var taken_names = []

func _ready() -> void:
	
	if Globals.creating_server:
		create_server()
	else:
		join_server()
		
func create_server() -> void:
	peer.create_server(1027)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	
	populate_bots(0)
	add_player()
	
func join_server() -> void:
	peer.create_client("127.0.0.1", 1027)
	multiplayer.multiplayer_peer = peer
	
func add_player(id = 1):
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	player.connect("respawn", respawn_player)
	
	var spawn = await find_unoccupied_spawn()
	
	# Place player at spawn
	add_child(player)
	await get_tree().process_frame
	player.rpc_id(id, "set_posrot", spawn.global_position, spawn.global_rotation)
	player.rpc_id(id, "set_username", player.username, taken_names)
	
	taken_names.append(player.username)
	
func populate_bots(num = 0):
	for i in range(num):
		add_bot(i)
		
func add_bot(num):
	if not multiplayer.is_server():
		return
		
	var bot = bot_scene.instantiate()
	bot.name = "Bot_" + str(randi())
	bot.username = "Bot_" + str(num)
	
	taken_names.append(bot.username)
	
	bot.connect("respawn", respawn_player)
	var spawn = await find_unoccupied_spawn()
	
	add_child(bot)
	await get_tree().process_frame
	
	bot.global_position = spawn.global_position
	bot.global_rotation = spawn.global_rotation
	
	await get_tree().process_frame
	
func respawn_player(player):
	rpc("sync_respawn", player)
	
@rpc("any_peer", "call_local")
func sync_respawn(player):
	# (Also used to respawn bots)
	
	var spawn = await find_unoccupied_spawn()
	
	player.global_position = spawn.global_position
	player.global_rotation = spawn.global_rotation
	
func find_unoccupied_spawn():
	
	# Search all spawn points.
	var spawn_found = false
	while !spawn_found:
		for spawn in get_tree().get_nodes_in_group("Player Spawns"):
			if !spawn.occupied:
				spawn.occupied = true
				return spawn
				
		# If no spawn available, wait and repeat
		await get_tree().create_timer(1.0).timeout
		
func exit_game(id):
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)
	
func del_player(id):
	rpc("_del_player", id)
	
@rpc("any_peer", "call_local")
func _del_player(id):
	get_node(str(id)).queue_free()
	
