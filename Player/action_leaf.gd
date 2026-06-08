@tool
extends ActionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	
	if owner.weapons.size() >= 3:
		return SUCCESS
	else:
		return RUNNING
