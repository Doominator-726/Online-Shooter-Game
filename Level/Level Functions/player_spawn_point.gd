extends Marker3D

var occupied = false

func _on_area_3d_body_entered(_body: Node3D) -> void:
	occupied = true
	
func _on_area_3d_body_exited(_body: Node3D) -> void:
	$"Cooldown Timer".start()
	
# Reactivates spawn
func _on_cooldown_timer_timeout() -> void:
	if $Area3D.get_overlapping_bodies().size() == 0:
		occupied = false
	else:
		$"Cooldown Timer".start()
		
