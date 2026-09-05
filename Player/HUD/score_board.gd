extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	for player in get_tree().get_nodes_in_group("player"):
		player.connect("update_scoreboard", update_scoreboard)
	for bot in get_tree().get_nodes_in_group("bots"):
		bot.connect("update_scoreboard", update_scoreboard)
		
	Globals.connect("populate_scoreboard", populate_scoreboard)
	populate_scoreboard()
	refresh_scoreboard()
	
func populate_scoreboard():
	rpc("_sync_populate_scoreboard")
	
@rpc("any_peer", "call_local")
func _sync_populate_scoreboard():
	Globals.scoreboard = []
	for player in get_tree().get_nodes_in_group("player"):
		Globals.scoreboard.append([player.username, 0])
	for bot in get_tree().get_nodes_in_group("bots"):
		Globals.scoreboard.append([bot.username, 0])
		
func update_scoreboard(killer_name):
	print("Update")
	for i in range(Globals.scoreboard.size()):
		var user = Globals.scoreboard[i]
		print(user[0])
		print(killer_name)
		if user[0] == killer_name:
			user[1] += 1
			if i < Globals.scoreboard.size() - 1:
				print("HEY")
				if Globals.scoreboard[i + 1][1] < user[1]:
					reorder_scoreboard()
			break
			
func reorder_scoreboard():
	Globals.scoreboard.sort_custom(func(a, b): return a[1] > b[1])
	refresh_scoreboard()
	
func refresh_scoreboard():
	
	print("Hey")
	for child in $Board.get_children():
		$Board.remove_child(child)
		child.queue_free()
		
	for user in Globals.scoreboard:
		var tag = Label.new()
		tag.text = str(user[0]) + ": " + str(user[1])
		$Board.add_child(tag)
		
