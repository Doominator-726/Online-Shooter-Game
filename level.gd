extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene
@export var bot_scene: PackedScene

func _on_host_pressed() -> void:
	peer.create_server(1027)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player()
	$CanvasLayer.hide()
	
	#add_bot(Vector3(-12.54, -0.989, 8.976))
	#add_bot(Vector3(1.453, -3.412, 0))
	
func _on_join_pressed() -> void:
	peer.create_client("127.0.0.1", 1027)
	multiplayer.multiplayer_peer = peer
	$CanvasLayer.hide()
	
func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)
	
func add_bot(spawn_pos: Vector3):
	if not multiplayer.is_server():
		return
		
	var bot = bot_scene.instantiate()
	bot.name = "Bot_" + str(randi())
	
	add_child(bot)
	await get_tree().process_frame
	
	bot.global_position = spawn_pos
	
func exit_game(id):
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)
	
func del_player(id):
	rpc("_del_player", id)
	
@rpc("any_peer", "call_local")
func _del_player(id):
	get_node(str(id)).queue_free()
