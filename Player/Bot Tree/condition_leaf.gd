@tool
extends ConditionLeaf

func tick(actor: Node, blackboard: Blackboard) -> int:
	
	if owner.target and owner.target.visible:
		return FAILURE
	else:
		return SUCCESS
