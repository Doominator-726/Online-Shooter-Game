@tool
extends ConditionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	if owner.health > 85 or get_tree().get_nodes_in_group("pickupHealth").size() == 0:
		return SUCCESS
	else:
		owner.find_group_items("pickupHealth")
		return FAILURE
