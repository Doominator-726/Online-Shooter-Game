extends StaticBody3D

@export var item: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	respawn_item()
	$"Respawn Timer".connect("timeout", respawn_item)
	
func respawn_item():
	rpc("_sync_respawn_item")
	
@rpc("any_peer", "call_local", "reliable")
func _sync_respawn_item():
	
	if $Spawn.get_child_count() == 0:
		var spawned_item = item.instantiate()
		$Spawn.add_child(spawned_item)
		
