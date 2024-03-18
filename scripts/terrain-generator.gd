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
	
	# Acquire Wave Function Collapse Inputs
	var waveSize = getWaveSize(inputMap)
	var parseResults = parseInputTileMap(inputMap)
	print(parseResults.keys())
	var tileFrequencies = parseResults.get("tilesToFrequencies")
	var tileConstraints = parseResults.get("tilesToConstraints")
	var tileWeights = getTileProbabilityWeights(tileFrequencies, waveSize)
	
	# Run Algorithm
	var wave = initializeWave(tileConstraints, inputMap)
	
	print(getShannonEntropyForCell(wave, tileWeights, 0))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func getWaveSize(map: TileMap) -> int:
	var rect = map.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	return mapWidth * mapHeight
	
	
func parseInputTileMap(map : TileMap):
	var tilesToConstraints : Dictionary 
	var tilesToFrequency : Dictionary = {} # the number of times each tile type (atlasCoords) appears on the map
	var rect = map.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	
	for x in mapWidth: # width
		for y in mapHeight: # height

			var tileId = map.get_cell_atlas_coords(LAYER_ZERO, Vector2i(x,y))
			# record frequency
			if tilesToFrequency.has(tileId):
				tilesToFrequency[tileId] += 1
			else:
				tilesToFrequency[tileId] = 1

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

	return {"tilesToConstraints": tilesToConstraints, "tilesToFrequencies": tilesToFrequency}
	
	# The output array is known as a "wave" with the dimensions of a coefficient matrix. 
	# The coefficient matrix is described in the algorithm as all possible states for an NxM region of pixels. 
	# For the even simpler tiled model, a region is one tile on the map, so the possibility state is simply the number of tile types
func calculateCoefficient(numTileTypesUsed: int):
	var coefficient = numTileTypesUsed
	print("Coefficient is:", coefficient)
	return coefficient

func initializeWave(tilesToConstraints: Dictionary, inputMap: TileMap):
	var rect = inputMap.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	
	var wave = createMatrix(mapWidth, mapHeight)
	var matrixCoefficient = calculateCoefficient(tilesToConstraints.size())
	wave.fill(tilesToConstraints)

	return wave
	
func createMatrix(width: int, height: int) -> Array[Variant]: 
	var matrix = Array()
	matrix.resize(width * height)
	return matrix

func idx2DtoIdx1D(x: int, y: int, width: int) -> int:
	var index = (x * width) + y
	return index

func getRandomIdx(waveSize: int) -> int:
	return randi() % waveSize

###
# Returns an array of tileId -> weight kvps, sorted from highest weight (most frequent) to lowest weight (least frequent)
###
func getTileProbabilityWeights(tileFrequencies: Dictionary, waveSize: int) -> Array:
	var tileWeights = []
	for key in tileFrequencies:
		var value : float = tileFrequencies[key]
		var weight : float = snappedf(value / float(waveSize), .01)
		var tile = { "tile": key, "weight": weight }
		tileWeights.append(tile)
	
	# sort weights such that highest weight is first
	tileWeights.sort_custom(func(a, b): return a["weight"] > b["weight"])
	#TODO add weights and throw error if != 100
	return tileWeights

# Entropy is the measure of disorder or uncertainty, broadly, this method uses the Shannon Entropy equation to calculate the entropy of a given cell in the wave.
func getShannonEntropyForCell(wave: Array, tileWeights: Array, cellIdx) -> float:
	# get the sum of weights of all remaining tile types
	var weightSum : float
	var weightSumLogWeights : float
	for remainingTileChoice in wave[cellIdx]:
			var weightMapping = tileWeights.filter(
				(func(tile): 
					return tile["tile"] == remainingTileChoice))[0]
			var weight = weightMapping["weight"]
			weightSum += weight
			weightSumLogWeights += weight * log(weight)
	
	var shannon_entropy_for_cell : float = log(weightSum) - (weightSumLogWeights / weightSum)
	print("Cell remaining choices WeightSum", cellIdx, ": ", weightSum)
	print("Cell ", cellIdx, " entropy: ", shannon_entropy_for_cell)
	
	return shannon_entropy_for_cell
