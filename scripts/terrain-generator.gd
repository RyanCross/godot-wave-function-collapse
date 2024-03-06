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

# Called when the node enters the scene tree for the first time.
func _ready():
	var tilesToConstraints = parseInputTileMap(inputMap)
	var wave = initializeWave(tilesToConstraints, inputMap)
	
	print(wave)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func parseInputTileMap(map : TileMap):
	var tilesToConstraints : Dictionary
	var rect = map.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	
	for x in mapWidth: # width
		for y in mapHeight: # height

			var tileId = map.get_cell_atlas_coords(LAYER_ZERO, Vector2i(x,y))

			# initialize constraint rules array for tile type if one does not exist yet
			if !tilesToConstraints.has(tileId):
				var constraintTuples = {}
				tilesToConstraints[tileId] = constraintTuples
			
			for i in DIRECTIONS.size():
				var targetCell = Vector2i(x + DIRECTIONS[i].x, y + DIRECTIONS[i].y)			
				
				# if checking past map bounds, skip constraint generation
				if targetCell.x < 0 or targetCell.y < 0:
					continue
				if targetCell.x >= mapWidth or targetCell.y >= mapHeight:
					continue
				# Sets don't exist in Godot, so we'll use a dict instead
				var targetTile = map.get_cell_atlas_coords(LAYER_ZERO, targetCell)
				var constraint = { "local" : tileId, "allowed": targetTile, "direction" : DIRECTIONS[i]} 
				if tilesToConstraints.size() == 0:
					tilesToConstraints[constraint] = constraint
				else:
					tilesToConstraints[tileId].merge({constraint: true})

	return tilesToConstraints #TODO test addition of tiles
	
	# The output array is known as a "wave" with the dimensions of a coefficient matrix. 
	# The coefficient matrix is described in the algorithm as all possible states for an NxM region of pixels. 
	# For the even simpler tiled model, a region is one tile on the map, so the possibility state is simply the number of tiles
func calculateCoefficientMatrix(numTileTypesUsed: int):
	var coefficient = numTileTypesUsed
	print("Coefficient is:", coefficient)
	return coefficient

func initializeWave(tilesToConstraints: Dictionary, inputMap: TileMap):
	var rect = inputMap.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	
	var wave = createMatrix(mapWidth, mapHeight)
	var matrixCoefficient = calculateCoefficientMatrix(tilesToConstraints.size())
	wave.fill(matrixCoefficient)

	return wave
	
func createMatrix(width, height) -> Array[Variant]: 
	var matrix = Array()
	matrix.resize(width * height)
	return matrix

func idx2DtoIdx1D(x, y, width) -> int:
	var index = (x * width) + y
	return index

func getRandomIdx(waveSize) -> int:
	return randi() % (waveSize - 1)


