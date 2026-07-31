extends Control

var level_scene = preload("res://Level/level.tscn")

func _on_host_button_up() -> void:
	Globals.creating_server = true
	Globals.username = $TextEdit.text
	get_tree().change_scene_to_packed(level_scene)
	
func _on_join_button_up() -> void:
	Globals.creating_server = false
	Globals.username = $TextEdit.text
	get_tree().change_scene_to_packed(level_scene)
