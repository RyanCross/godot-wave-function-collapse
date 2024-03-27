extends Node2D

const LEFT : Vector2i = Vector2i(-1, 0)
const RIGHT : Vector2i = Vector2i(1, 0)
const DOWN : Vector2i = Vector2i(0, -1)
const UP : Vector2i = Vector2i(0, 1)
const DIRECTIONS : Array = [LEFT, RIGHT, DOWN, UP]
const EMPTY_TILE := Vector2i(-1,-1)
const LAYER_ZERO := 0

var mapWidth : int
var mapHeight : int
@onready
var inputMap = $InputMap

# Called when the node enters the scene tree for the first time.
func _ready():
	# Acquire Wave Function Collapse Inputs
	var mapBounds = getMapBounds2D(inputMap)
	var waveSize = mapBounds["width"] * mapBounds["height"]
	var parseResults = parseInputTileMap(inputMap, mapBounds)
	var tileFrequencies = parseResults.get("tilesToFrequencies")
	var tileConstraints = parseResults.get("tilesToConstraints")
	var tileWeights = getTileProbabilityWeights(tileFrequencies, waveSize)
	
	# Run Algorithm
	var wave = initializeWave(tileConstraints, inputMap, mapBounds)
	var lowestEntropyCells = processWave(wave, tileWeights, mapBounds)
	
	print(getShannonEntropyForCell(wave, tileWeights, 0))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

### 
# Invert a direction.. e.g. LEFT to RIGHT, DOWN to UP. 
# Used for generating constraint information from the perspective of a neighboring tile
###
func invertDirection(dir: Vector2i):
	return Vector2i(dir.x * -1, dir.y * -1)

###
# Builds the "allowed" and "direction" portions of a tile constraint to be propagated to a tile,
# leaving "local" to be whatever neighboring tile option we happen to be checking.  The direction 
# rule is always from the PERSPECTIVE of the cell we are passing the constraint to. This means the 
# direction is the inverted direction of collapsed tile (current cell) -> neighbor to propagate to.
###
func buildPartialConstraint(collapsedCellsTileChoice: Vector2i, directionOfNeighbor: Vector2i):
	return { "allowed": collapsedCellsTileChoice, "direction": invertDirection(directionOfNeighbor)}

###
#	Ex call: Propagate(partialCon: {"allowed": (9,2), "direction": inverseDir([right])}, wave, cellToPropagatePos)
#   Recursively generates constraints for the current cell and propagates any collapses as a result 
#   of constriant checking to neighboring cells. This results in the wave's entropy (available choices 
#   for each cell) lowering any time a new cell is collapsed.
###
func propagate(wave: Variant, cellToPropagatePos: int, partialConstraint: Variant, mapBounds: Dictionary):
	# base case 1: a propagation call has resulted in a contradiction
	if typeof(wave) == TYPE_INT and wave == -1:
		return wave
	
	var remainingTileChoices = wave[cellToPropagatePos]
	# base case 2: already collapsed, do not need to propagate further on this cell
	if(typeof(remainingTileChoices) == TYPE_VECTOR2I):
		return wave
		
	elif(typeof(remainingTileChoices) == TYPE_DICTIONARY):	
		# actual logic of removing constraints, updating wave
		var tileChoicesToKeep = []
		
		for tile in remainingTileChoices.keys():
			var constraint = partialConstraint.duplicate(true);
			constraint["local"] = tile
			# if allow rule (constraint) is not present, then this tile choice is now invalid
			if(remainingTileChoices[tile].has(constraint)):
				tileChoicesToKeep.append(tile)
		
		# base case 3: there are no options left for this cell, contradiction reached.
		if(tileChoicesToKeep.size() == 0):
			wave = -1
			return wave
		# base case 4: there is more than one option remaining, we are done propagating down this path
		if(tileChoicesToKeep.size() > 1):
			return wave
		# recursion case 1: a new cell has been collapsed
		if(tileChoicesToKeep.size() == 1):
			var collapsedCellTile = tileChoicesToKeep[0]
			wave[cellToPropagatePos] = collapsedCellTile
			var pos2D = idx1DToidx2D(cellToPropagatePos, mapBounds.width)
			var neighbors2d = getNeighborCoordinates2D(pos2D)
			var neighbors1d = getNeighborCoordinates1D(pos2D, mapBounds.width)
			
			### continue propagating as long as within tileMap bounds and contradiction not reached
			if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["left"], mapBounds):
				partialConstraint = buildPartialConstraint(collapsedCellTile, LEFT)
				wave = propagate(wave, neighbors1d["left"], partialConstraint, mapBounds)
		
			if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["right"], mapBounds):
				partialConstraint = buildPartialConstraint(collapsedCellTile, RIGHT)
				wave = propagate(wave, neighbors1d["right"], partialConstraint, mapBounds)
	
			if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["up"], mapBounds):
				partialConstraint = buildPartialConstraint(collapsedCellTile, UP)
				wave = propagate(wave, neighbors1d["up"], partialConstraint, mapBounds)
	
			if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["down"], mapBounds):
				partialConstraint = buildPartialConstraint(collapsedCellTile, DOWN)
				wave = propagate(wave, neighbors1d["down"], partialConstraint, mapBounds)
	else:
		assert(false, "An unexpected error occurred during propagation")

func getWaveSize(map: TileMap) -> int:
	var rect = map.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	return mapWidth * mapHeight

func getMapBounds2D(map: TileMap) -> Dictionary:
	var rect = map.get_used_rect()
	var mapWidth = rect.size.x
	var mapHeight = rect.size.y 
	return { "width": mapWidth, "height": mapHeight }

###
# Returns a record containing the neighboring coordinate positions relative to the position passsed.
# Does not check if they are valid coordinates, use isWithin Bounds for that.
###
func getNeighborCoordinates2D(pos : Vector2i) -> Dictionary:
	return { "left": pos + LEFT, "right": pos + RIGHT, "up": pos + UP, "down": pos + DOWN }

func getNeighborCoordinates1D(pos: Vector2i, mapWidth : int) -> Dictionary:
	var neighbors2d = getNeighborCoordinates2D(pos)
	var nLeft := idx2DToIdx1D(neighbors2d.left.x, neighbors2d.left.y, mapWidth)
	var nRight :=  idx2DToIdx1D(neighbors2d.right.x, neighbors2d.right.y, mapWidth)
	var nUp :=  idx2DToIdx1D(neighbors2d.up.x, neighbors2d.up.y, mapWidth)
	var nDown :=  idx2DToIdx1D(neighbors2d.down.x, neighbors2d.down.y, mapWidth)
	
	return { "left": nLeft, "right": nRight, "up": nUp, "down": nDown }

	

#TODO should make this soft constraint of: sample tile maps lower bound of 0 in either dir, a hard one somehow, this will only work if filled cells start at 0,0
###
# Returns true if coordinate is within the bounds of wave (output tile map), false otherwise
###
func isWithinBounds(pos2D : Vector2i, mapBounds : Dictionary) -> bool:
	var LOWER_BOUNDS_XY = -1
	var UPPER_BOUNDS_X = mapBounds["width"]
	var UPPER_BOUNDS_Y = mapBounds["height"]
	
	if pos2D.x <= LOWER_BOUNDS_XY or pos2D.x >= UPPER_BOUNDS_X:
		return false
	if pos2D.y <= LOWER_BOUNDS_XY or pos2D.y >= UPPER_BOUNDS_Y:
		return false
	return true
	
func parseInputTileMap(map : TileMap, mapBounds: Dictionary):
	var tilesToConstraints : Dictionary 
	var tilesToFrequency : Dictionary = {} # the number of times each tile type (atlasCoords) appears on the map
	var mapWidth = mapBounds["width"]
	var mapHeight = mapBounds["height"]
	
	#TODO could speed this up by iterating as a 1D array
	for x in mapWidth: # width
		for y in mapHeight: # height

			var tileId = map.get_cell_atlas_coords(LAYER_ZERO, Vector2i(x,y))
			var i1D = idx2DToIdx1D(x, y, mapWidth)
			var i2D = idx1DToidx2D(i1D, mapWidth)
			
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
				var constraint = { "allowed" : targetTileId, "direction" : DIRECTIONS[i], "local" : tileId, } 
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

func initializeWave(tilesToConstraints: Dictionary, inputMap: TileMap, mapBounds: Dictionary):
	var mapWidth = mapBounds["width"]
	var mapHeight = mapBounds["height"]
	
	var wave = createMatrix(mapWidth, mapHeight)
	var matrixCoefficient = calculateCoefficient(tilesToConstraints.size())
	wave.fill(tilesToConstraints)

	return wave
	
func createMatrix(width: int, height: int) -> Array[Variant]: 
	var matrix = Array()
	matrix.resize(width * height)
	return matrix

func idx2DToIdx1D(x: int, y: int, width: int) -> int:
	var index = (y * width) + x
	return index

func idx1DToidx2D(i: int, width: int) -> Vector2i:
	var x : int = i % width
	var y : int = floor(i / width)
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
		# if element in wave is a VECTOR2i and not a Dictionary, it is already collapsed and should be skipped
		if (typeof(wave[i]) == TYPE_VECTOR2I):
			continue
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
func processWave(wave: Variant, tileWeights: Array, mapBounds: Dictionary):
	var isWaveFunctionCollapsed := false
	# TODO wrap this in a loop, where looping ends when wave = -1 or wave function completed collapsed
	# step 1: collect cells with lowest entropy
	var lowestEntropyCells = getLowestEntropyCells(wave, tileWeights)
	if lowestEntropyCells.size() == 0:
		# END CONDITION: Collapsing all elements successful and finished.
		return wave;
		
	# step 2: select a cell from those of the lowest entropy at random
	var selectIdx = randi() % lowestEntropyCells.size()
	var cellPos : int = lowestEntropyCells[selectIdx]["wavePos"]
	# after selecting, reset lowestEntropyCells for next loop
	lowestEntropyCells = []
	
	# step 3: collapse that cell
	print("Collapsing Cell: ", cellPos)
	var tileSelection : Variant = collapse(wave, tileWeights, cellPos)
	if	typeof(tileSelection) == TYPE_INT and tileSelection == -1:
		#TODO break once looping	   
		print("break, contraditiction found")
	
	wave[cellPos] = tileSelection 
	var pos2d = idx1DToidx2D(cellPos, mapBounds.width)
	var neighbors2d := getNeighborCoordinates2D(pos2d)
	var neighbors1d := getNeighborCoordinates1D(pos2d, mapBounds.width)
	
	# Propagate collapse information as constraints to check, where appropriate
	if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["left"], mapBounds):
		var partialConstraint = buildPartialConstraint(tileSelection, LEFT)
		wave = propagate(wave, neighbors1d["left"], partialConstraint, mapBounds)
		
	if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["right"], mapBounds):
		var partialConstraint = buildPartialConstraint(tileSelection, RIGHT)
		wave = propagate(wave, neighbors1d["right"], partialConstraint, mapBounds)
	
	if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["up"], mapBounds):
		var partialConstraint = buildPartialConstraint(tileSelection, UP)
		wave = propagate(wave, neighbors1d["up"], partialConstraint, mapBounds)
	
	if typeof(wave) != TYPE_INT and isWithinBounds(neighbors2d["down"], mapBounds):
		var partialConstraint = buildPartialConstraint(tileSelection, DOWN)
		wave = propagate(wave, neighbors1d["down"], partialConstraint, mapBounds)
	
	if typeof(wave) == TYPE_INT:
		print("Contradiction reached")
		return -1

	
	
	
	# TODO implement a check bounds function
	# TODO step 4: propagate collapse in each neighboring direction, checking bounds
	#func buildPartialConstraint(collapsedCellsTileChoice: Vector2i, directionOfNeighbor: Vector2i):
	#return { "allowed": collapsedCellsTileChoice, "direction": invertDirection(directionOfNeighbor)}
	
	
	# TODO loop this, handle logic for "iteration"

###
# Selects a tile at random from the cell's remaining choices using weighted 
# randomness based on frequency of tiles as they appeared in the input map. Returns 
# 0 if a selection could not be made due to error or reaching contradiction
###
func collapse(wave: Array, tileWeights: Array, cellPos: int):
	var availableTileChoices : Array = wave[cellPos].keys()
	var selection = -1
	
	# No choices available, contradiction reached
	if availableTileChoices.size() == 0:
		return selection
	
	# Create a copy of tileWeights, find all entries that are not present in tileChoices for the cell and remove them
	# This creates an array of weights for the remaining choices that is still ordered most to least frequent
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
		

	return selection
