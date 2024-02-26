extends TileMap

const LAYER_0 = 0
var tileSet = tile_set
var timeSinceLastBlink = 0
var atlasCoordsAtInspectedCell
var currentCellCoords = Vector2i(0,0)
var currentTileAtlasCoords


# Called when the node enters the scene tree for the first time.
func _ready():
	var cells = get_used_cells(LAYER_0)
	atlasCoordsAtInspectedCell = get_cell_atlas_coords(LAYER_0, currentCellCoords)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	timeSinceLastBlink += delta * 1000
	if timeSinceLastBlink >= 500:
		blink(Vector2i(0,0))
		timeSinceLastBlink = 0

func blink(cellCoords : Vector2i):
	var emptyCell = Vector2i(-1,-1)
	if (get_cell_atlas_coords(LAYER_0, cellCoords) != emptyCell):
		set_cell(LAYER_0, cellCoords, 0, emptyCell)
	else:
		set_cell(LAYER_0, cellCoords, 0, atlasCoordsAtInspectedCell)
