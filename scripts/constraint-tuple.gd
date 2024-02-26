class_name ConstraintTuple
	# For the Even Simpler Tiled Model, define the format (current, target, direction). 
	# This defines a positive constraint that equivocates to: "Target" can be placed to the "direction" of "current"
	# CurrentTile and targetTile are atlasCoordinates on a Tilemap, but can be thought of as a tile type. E.g. STONE, WATER, GROUND.
	# A constraint tuple of ("WATER", "STONE", "LEFT"), would translate to a constraint that sotne can be placed to the left of water.
var current : Vector2i
var target : Vector2i
var direction : Vector2i
	
func _init(currentTile, targetTile, targetDirection):
	current = currentTile
	target = targetTile
	direction = targetDirection
		
# equals by value function for Tuple
func equals(tuple : ConstraintTuple) -> bool: 
	if tuple.current == current && tuple.target == target && tuple.direction == direction:
		return true
	else:
		return false
	
