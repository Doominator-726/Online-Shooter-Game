@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if owner.armor > 70 or get_tree().get_nodes_in_group("pickupArmor").size() == 0:
		return SUCCESS
	else:
		owner.find_group_items("pickupArmor")
		return FAILURE
