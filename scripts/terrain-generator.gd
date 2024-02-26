extends Node2D
#const ConstraintTuple = preload("constraint-tuple.gd")

const LEFT : Vector2i = Vector2i(-1, 0)
const RIGHT : Vector2i = Vector2i(1, 0)
const DOWN : Vector2i = Vector2i(0, -1)
const UP : Vector2i = Vector2i(0, 1)
var DIRECTIONS : Array = [LEFT, RIGHT, DOWN, UP]
const EMPTY_TILE := Vector2i(-1,-1)
const LAYER_ZERO := 0

@onready
var inputMap = $InputTileMap
var outputSizeX = 0;
var outputSizeY = 0;
## Constraints is set of tile atlas coordinates (Vector2i) to an array of constraint rules. Array[ConstraintTuple] (use dict)


@onready
var testTuple := ConstraintTuple.new(LEFT, RIGHT, DOWN)
var testTuple2 := ConstraintTuple.new(LEFT, RIGHT, RIGHT)

# Called when the node enters the scene tree for the first time.
func _ready():
	print(testTuple.equals(testTuple2))
	parseInputTileMap(inputMap)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#TODO
	
func parseInputTileMap(map : TileMap):
	var tilesToConstraints : Dictionary
	var constraintTuples : Dictionary
	var rect = map.get_used_rect()
	
	for x in rect.size.x: # width
		for y in rect.size.y: # height
			var tileId = map.get_cell_atlas_coords(LAYER_ZERO, Vector2i(x,y))

			# initialize constraint rules array for tile type if one does not exist yet
			if !tilesToConstraints.has(tileId):
				constraintTuples = {}
				tilesToConstraints[tileId] = constraintTuples
			else:
				constraintTuples = tilesToConstraints.get(tileId)	
			
			for i in DIRECTIONS.size():
				var currentCell = Vector2i(x,y)
				var targetCell = Vector2i(x + DIRECTIONS[i].x, y + DIRECTIONS[i].y)				
				# if checking past map bounds, skip constraint generation
				if targetCell.x < 0 || targetCell.y < 0:
					continue
				
				# Sets don't exist in Godot, so we'll use a dict instead
				var targetTile = map.get_cell_atlas_coords(LAYER_ZERO, targetCell)	
				var constraint = { tileId : true, targetTile: true, DIRECTIONS[i] : true}
				if constraintTuples.size() == 0:
					constraintTuples = constraint
				else:
					constraintTuples.merge(constraint)
				
				tilesToConstraints[tileId] = constraintTuples
	return tilesToConstraints
	




	
