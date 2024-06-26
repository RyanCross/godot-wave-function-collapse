extends Node2D

const LEFT : Vector2i = Vector2i(-1, 0)
const RIGHT : Vector2i = Vector2i(1, 0)
const DOWN : Vector2i = Vector2i(0, -1)
const UP : Vector2i = Vector2i(0, 1)
const DIRECTIONS : Array = [LEFT, RIGHT, DOWN, UP]
const EMPTY_TILE := Vector2i(-1,-1)
const LAYER_ZERO := 0

@export
var inputMap : TileMap
@export
var seed : String
@export
var useSeed : bool = false

var mapWidth : int
var mapHeight : int

# Called when the node enters the scene tree for the first time.
func _ready():

	var rng = setupRandomness(useSeed, seed)
	# Acquire Wave Function Collapse Inputs
	var mapBounds = getMapBounds2D(inputMap)
	var waveSize = mapBounds["width"] * mapBounds["height"]
	var parseResults = parseInputTileMap(inputMap, mapBounds)
	var tileFrequencies = parseResults.get("tilesToFrequencies")
	var tileConstraints = parseResults.get("tilesToConstraints")
	var tileWeights = getTileProbabilityWeights(tileFrequencies, waveSize)
	
	# Run Algorithm
	var wave = waveFunctionCollapse(tileWeights, tileConstraints, inputMap, mapBounds, rng)
	while(typeof(wave) == TYPE_INT and wave == -1):
		print("Contradiction reached, retrying...")
		wave = waveFunctionCollapse(tileWeights, tileConstraints, inputMap, mapBounds, rng)
		
	### TODO set up a timeout function
	### TODO replay functiion for capturing good outputs
	print(wave)
	await get_tree().create_timer(2.0).timeout
	
	# Display Results Logic
	var outputMap : TileMap = createOutputMap(inputMap)
	inputMap.set_visible(false)
	await add_child(outputMap)
	drawMap(wave, outputMap, mapBounds)

func setupRandomness(useSeed: bool, seed: String) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	
	if useSeed:	
		if seed.is_empty():
			print("No seed supplied, using default seed")
			seed = "test"
		print("Seed: ", seed)
		rng.seed = hash(seed)
	else:
		rng.randomize()
	
	return rng

###
# Creates a map to draw the output of the wave function, containing the same tileset and drawn in the same position
###
func createOutputMap(inputMap: TileMap) -> TileMap:
	# TODO
	# get tileset from input map
	# set position to 0,0
	var outputMap : TileMap = TileMap.new()
	outputMap.set_position(Vector2i(0,0))
	outputMap.set_tileset(inputMap.get_tileset())
	
	return outputMap

func drawMap(wave: Array, outputMap: TileMap, mapBounds: Dictionary): 
	for i in wave.size():
		# wait to make the generation look nice
		await get_tree().create_timer(.01).timeout
		var tileAtlasCoords : Vector2i = wave[i]
		var cellPosition = idx1DToidx2D(i, mapBounds.width)
		outputMap.set_cell(LAYER_ZERO, cellPosition, 0, tileAtlasCoords)
		
	

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
		var tileChoicesToKeep = {}
		
		for tile in remainingTileChoices.keys():
			var constraint = partialConstraint.duplicate(true);
			constraint["local"] = tile
			# if allow rule (constraint) is not present, then this tile choice is now invalid
			if(remainingTileChoices[tile].has(constraint)):
				# update cell to only keep options that weren't eliminated by checking constraint
				tileChoicesToKeep.merge({tile : remainingTileChoices[tile]})
			
		wave[cellToPropagatePos] = tileChoicesToKeep
		
		# base case 3: there are no options left for this cell, contradiction reached.
		if(wave[cellToPropagatePos].size() == 0):
			print("Contradiction reached at cell", cellToPropagatePos)
			wave = -1
			return wave
		# base case 4: there is more than one option remaining, we are done propagating down this path
		if(wave[cellToPropagatePos].size() > 1):
			return wave
		# recursion case 1: a new cell has been collapsed
		if(wave[cellToPropagatePos].size() == 1):
			var collapsedCellTile = tileChoicesToKeep.keys()[0] # get the tile atlas coords of the remaining tileToConstraint dict 
			print(cellToPropagatePos, " collapsed through propagation")
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
			
		return wave
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
	print("Wave Matrix Coefficient:", coefficient)
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
		var weight : float = value / float(waveSize)
		var weightSnapped : float = snappedf(weight, .001)
		assert(weight != 0, "weight of tile cannot be 0")
		var tile = { "tile": key, "weight": weightSnapped }
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
	var weightSum : float = 0
	var weightSumLogWeights : float = 0
	for remainingTileChoice in wave[cellIdx]:
			var weightMapping = tileWeights.filter(
				(func(tile): 
					return tile["tile"] == remainingTileChoice))[0]
			var weight = weightMapping["weight"]
			weightSum += weight
		#	print("weight Z:", weight)
		#	print("log of weight: ", log(weight))
			weightSumLogWeights += weight * log(weight)
	

	var shannon_entropy_for_cell : float = log(weightSum) - (weightSumLogWeights / weightSum)

	return shannon_entropy_for_cell

# Get array of all lowest entropy cells
func getLowestEntropyCells(wave: Array, tileWeights: Array) -> Array:	
	var arr0 = wave[0]
	var arr1 = wave[1]
	var arr20 = wave[20]
	var arr200 = wave [200]
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
			#print(float(lowestEntropy))
			#print(cell["entropy"])
			if cell["entropy"] < lowestEntropy:
				# new lowest entropy found, wipe array
				lowestEntropyCells = []
				lowestEntropyCells.append(cell)
			elif float(cell["entropy"]) == float(lowestEntropy):
				lowestEntropyCells.append(cell)
	
	return lowestEntropyCells
	
# Collapses the entire wave function (tile matrix), and returns either the resulting array, or the contradiction value: -1
# A contradiction means we've hit a point where not all cells can be collapsed into a valid layout, and thus the wave collapsing must begin anew
func waveFunctionCollapse(tileWeights: Array, tileConstraints: Dictionary, inputMap: TileMap, mapBounds: Dictionary, rng: RandomNumberGenerator):
	var wave = initializeWave(tileConstraints, inputMap, mapBounds)
	
	while (typeof(wave) != TYPE_INT):
		# step 1: collect cells with lowest entropy
		var lowestEntropyCells = getLowestEntropyCells(wave, tileWeights)
		if lowestEntropyCells.size() == 0:
			# END CONDITION: Collapsing all elements of wavesuccessful and finished.
			return wave
			
		# step 2: select a cell from those of the lowest entropy at random
		var selectIdx = rng.randi() % lowestEntropyCells.size()
		var cellPos : int = lowestEntropyCells[selectIdx]["wavePos"]
		# after selecting, reset lowestEntropyCells for next loop
		lowestEntropyCells = []
		
		# step 3: collapse that cell
		print("Collapsing Cell: ", cellPos)
		var tileSelection : Variant = collapse(wave, tileWeights, cellPos, rng)
		if typeof(tileSelection) == TYPE_INT and tileSelection == -1:
			print("break, contradiction found")
			return -1;

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
			assert(wave == -1, "Wave type int but not negative 1")
			return wave

	
	
	
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
func collapse(wave: Array, tileWeights: Array, cellPos: int, rng: RandomNumberGenerator):
	var availableTileChoices : Array = wave[cellPos].keys()
	var selection = -1
	
	# No choices available, contradiction reached
	if availableTileChoices.size() == 0:
		return selection
	
	# Create a copy of tileWeights, find all entries that are not present in tileChoices for the cell and remove them
	# This creates an array of weights for the remaining choices that is still ordered most to least frequent
	var availableChoicesWeights = []
	var choicesWeightSum : float = 0
	
	# get tileWeights sort afterwards
	for record in tileWeights:
		if availableTileChoices.find(record["tile"]) != -1:
			availableChoicesWeights.append(record)
			choicesWeightSum += snappedf(record["weight"], .001)
	
	availableChoicesWeights.sort_custom(func(a, b): return a["weight"] > b["weight"])
			
	# Bound the limit of the random value the sum of the remaining choices
	var rval : float = rng.randf_range(0, choicesWeightSum)
	var weightSum : float = 0;
	var i = 0;
	for record in availableChoicesWeights:
		weightSum += record["weight"]
		if rval <= weightSum: # weightSum is inclusive if last element
			var choiceIdx = availableTileChoices.find(record["tile"]) 
			assert(choiceIdx != -1, "Selected tile choice not found in available selection during collapse")
			selection = availableTileChoices[choiceIdx]
			break			
		i += 1
		

	return selection
