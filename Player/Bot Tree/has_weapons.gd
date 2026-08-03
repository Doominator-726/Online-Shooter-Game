@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if owner.weapons.size() >= 5 or get_tree().get_nodes_in_group("pickupWeapons").size() == 0:
		return SUCCESS
	else:
		owner.find_group_items("pickupWeapons")
		return FAILURE
