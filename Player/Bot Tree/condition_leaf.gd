@tool
extends ConditionLeaf

func tick(_actor: Node, _blackboard: Blackboard) -> int:
	
	if owner.target and owner.target.visible:
		return FAILURE
	else:
		return SUCCESS
