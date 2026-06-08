@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	
	if owner.target == null:
		return SUCCESS
	else:
		return FAILURE
