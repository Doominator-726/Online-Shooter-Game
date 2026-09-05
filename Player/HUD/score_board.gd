extends Control

var players = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update()
	
func _process(delta: float) -> void:
	update()
	
func update():
	for child in $Board.get_children():
		$Board.remove_child(child)
		child.queue_free()
		
	players = []
	
	for player in get_tree().get_nodes_in_group("player"):
		players.append(player)
	for bot in get_tree().get_nodes_in_group("bots"):
		players.append(bot)
	
	players.sort_custom(func(a, b): return a.kills > b.kills)
	
	for player in players:
		var tag = Label.new()
		tag.text = str(player.username) + ": " + str(player.kills)
		$Board.add_child(tag)
		
