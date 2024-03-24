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
var inputMap = $InputMap

# Called when the node enters the scene tree for the first time.
func _ready():
	# Acquire Wave Function Collapse Inputs
	var waveSize = getWaveSize(inputMap)
	var parseResults = parseInputTileMap(inputMap)
	var tileFrequencies = parseResults.get("tilesToFrequencies")
	var tileConstraints = parseResults.get("tilesToConstraints")
	var tileWeights = getTileProbabilityWeights(tileFrequencies, waveSize)
	
	# Run Algorithm
	var wave = initializeWave(tileConstraints, inputMap)
	var lowestEntropyCells = processWave(wave, tileWeights)
	
	print(getShannonEntropyForCell(wave, tileWeights, 0))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
# How do we generate the constraints to remove after collapsing a tile?
func generateConstraintsToRemove():
	pass
	# TODO confirm direction is U/D/L/R on the tilemap grid in x,y coordinates
	# TODO create a function to return the inverseDirection (so that constraints generated are from the perspective of the neighboring tile)
	# TODO handle out of bounds
	# we have the collapsed tile choice: lets use 9,2 as an example.
	# { "allowed": 9,2,
	# "direction": dirFromNeighborToThisTile - so inverse dir of target neighbor: propagating left? dir is right., 
	# "local": the key for the constraint tuples we are looking at (tile type)
	# }
	# what im struggling with is lets say we generate a constraint for the neighbor to the left { allowed: (9,2), direction: (1, 0), local: (9,2) }
	# we're asking the constraint dictionary which is whats allowed for EACH tile type and saying HEY: can grounds be to the right of other grounds?
	# if not, remove the ENTRY entirely.
	# remember were working with whats allowed not was disallowed, so as soon as we know what MUST be possible, we can reach a consensus for neighbors and repeat.
	# 
	###
	# this might fit best as a recursive function? whats the base case?: if tileTypes.size() > 1 #check if 0 (contradiction), then stop.
	# Propagate(partialCon: {"allowed": (9,2), "direction": inverseDir([right])}, wave, cellToPropagatePos)

### 
# Invert a direction.. e.g. LEFT to RIGHT, DOWN to UP. 
# Used for generating constraint information from the perspective of a neighboring tile
###
func invertDirection(dir: Vector2i):
	return Vector2i(dir.x * -1, dir.y * -1)

###
#
###
func propagate(wave: Array, cellToPropagatePos: int, partialConstraint: Variant):
	var remainingTileChoices = wave[cellToPropagatePos]
	# base case 1: already collapsed, do not need to propagate further on this cell
	if(remainingTileChoices.keys().size() == 1):
		return 1
	# base case 2: there are no options left, contradiction reached.
	if(remainingTileChoices.keys().size() == 0):
		return -1
		
	# actual logic of removing constraints, updating wave
	var tileChoicesToRemove = []
	for tile in remainingTileChoices.keys():
		var constraint = partialConstraint;
		constraint["local"] = tile	
		# if allow rule (constraint) is not present, then this tile choice is now invalid
		if(!remainingTileChoices[tile].has(constraint)):
			tileChoicesToRemove.append(tile)
			# propagate here? at the point of reducing the problem space?, no we propagate at the point of collapse, as this is the only thing that generates a constraint
	
	#TODO if now collapsed... propagate, otherwise stop?
	# or rather, if number of choices has CHANGED, propagate?
	# left
	
	# right
	
	# up
	
	# down
	
	

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
	
	#TODO could speed this up by iterating as a 1D array
	for x in mapWidth: # width
		for y in mapHeight: # height

			var tileId = map.get_cell_atlas_coords(LAYER_ZERO, Vector2i(x,y))
			var i1D = idx2DToIdx1D(x, y, mapWidth)
			var i2D = idx1DToidx2D(i1D, mapWidth, mapHeight)
			
			# record frequency
			if tilesToFrequency.has(tileId):
				tilesToFrequency[tileId] += 1
			else:
				tilesToFrequency[tileId] = 1

			# initialize constraint rules dictionary for tile type if one does not exist yet
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
				var targetTileId = map.get_cell_atlas_coords(LAYER_ZERO, targetCell)
				var constraint = { "local" : tileId, "allowed": targetTileId, "direction" : DIRECTIONS[i]} 
				tilesToConstraints[tileId].merge({constraint: true})

	return {"tilesToConstraints": tilesToConstraints, "tilesToFrequencies": tilesToFrequency}
	
###
# The output array is known as a "wave" with the dimensions of a coefficient matrix. 
# The coefficient matrix is described in the algorithm as all possible states for an NxM region of pixels. 
# For the even simpler tiled model, a region is one tile on the map, so the possibility state is simply the number of tile types
###
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

func idx2DToIdx1D(x: int, y: int, width: int) -> int:
	var index = (x * width) + y
	return index

##### understand how 1d to 2d conversion works
func idx1DToidx2D(i: int, width: int, height: int) -> Vector2i:
	var x : int = floor(i / width)
	var y : int = i % width
	return Vector2i(x, y)
###
# Returns an array of tileId -> weight kvps, sorted by frequency (highest weight) in descending order
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

###
# Entropy is the measure of disorder or uncertainty, broadly, this method uses 
# the Shannon Entropy equation to calculate the entropy of a given cell in the wave.
### 
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

# Get array of all lowest entropy cells
func getLowestEntropyCells(wave: Array, tileWeights: Array) -> Array:	
		# what if no cells found?
		# what if start of process
	var lowestEntropyCells = []
	for i in wave.size():
		var cell = { "wavePos": i, "entropy": getShannonEntropyForCell(wave, tileWeights, i) }
		if lowestEntropyCells.size() == 0:
			lowestEntropyCells.append(cell)
		else:
			var lowestEntropy : float = lowestEntropyCells.back()["entropy"]
			if cell["entropy"] < lowestEntropy:
				# new lowest entropy found, wipe array
				lowestEntropyCells = []
				lowestEntropyCells.append(cell)
			elif cell["entropy"] == lowestEntropy:
				lowestEntropyCells.append(cell)
	
	return lowestEntropyCells
	
# Collapses the entire wave function (tile matrix), and returns either the resulting array, or the contradiction value: -1
# A contradiction means we've hit a point where not all cells can be collapsed into a valid layout, and thus the wave collapsing must begin anew
func processWave(wave: Array, tileWeights: Array):
	# step 1: collect cells with lowest entropy
	var lowestEntropyCells = getLowestEntropyCells(wave, tileWeights)
	if lowestEntropyCells.size() == 0:
		# done collapsing
		return wave;
		
	# step 2: select one at random
	var selectIdx = randi() % lowestEntropyCells.size()
	var cellPos = lowestEntropyCells[selectIdx]["wavePos"]
	# after selecting, reset lowestEntropyCells for next loop
	lowestEntropyCells = []
	
	# step 3: collapse that cell
	print("Collapsing Cell: ", cellPos)
	collapse(wave, tileWeights, cellPos)
		
	# step 4: propagate collapse
	
###
# Selects a tile at random from the cell's remaining choices using weighted 
# randomness based on frequency of tiles as they appeared in the input map. Returns 
# 0 if a selection could not be made due to error or reaching contradiction
###
func collapse(wave: Array, tileWeights: Array, cellPos: int):
	var availableTileChoices : Array = wave[cellPos].keys()
	var selection = 0
	
	# No choices available, contradiction reached
	if availableTileChoices.size() == 0:
		return 0
	
	# Create a copy of tileWeights, find all entries that are not present in tileChoices for the cell and remove them
	# This creates an array weights for the remaining choices that is still ordered most to least frequent
	var tileWeightsRemainingChoices = tileWeights.duplicate()
	var remainingChoicesWeightSum : float = 0
	for record in tileWeightsRemainingChoices:
		if availableTileChoices.find(record["tile"]) == -1:
			tileWeightsRemainingChoices.erase(record)
		else:
			remainingChoicesWeightSum += record["weight"]

	# Bound the limit of the random value the sum of the remaining choices
	var rval = randf_range(0, remainingChoicesWeightSum)
	var weightSum = 0;
	var i = 0;
	rval = 1
	for record in tileWeightsRemainingChoices:
		weightSum += record["weight"]
		if rval < weightSum or (rval <= weightSum and i == tileWeightsRemainingChoices.size() - 1): # weightSum is inclusive if last element
			var choiceIdx = availableTileChoices.find(record["tile"]) 
			assert(choiceIdx != -1, "Selected tile choice not found in available selection during collapse")
			selection = availableTileChoices[choiceIdx]
			break			
		i += 1
		
	assert(selection != 0, "No tile was selected after iterating through choices")
	return selection
