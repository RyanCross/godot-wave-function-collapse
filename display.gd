extends Camera2D

@export var tilemap : TileMap

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	#set_anchor_mode(Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT)
	#var zoom_vector = get_camera_zoom_to_tilemap()
	#set_zoom(zoom_vector)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func get_camera_zoom_to_tilemap():
	var viewport_size = get_viewport().size
	var tilemap_info = get_tilemap_info()
	var level_size = Vector2i(tilemap_info.tile_size * tilemap_info.size)
	
	### get the aspect ratios
	var viewport_aspect_ratio = float(viewport_size[0] / viewport_size[1]) # 0 is x, 1 is y
	var level_aspect = float(level_size.x / level_size.y)
	
	
	# Whats displayed in viewport is controlled by zoom vector
	var new_zoom
	if level_aspect > viewport_aspect_ratio:
		new_zoom = float(viewport_size[1] / level_size.y)
	else:
		new_zoom = float(viewport_size[0] / level_size.x)
				
	return Vector2i(new_zoom, new_zoom)
		
func update_camera():
	var zoom_vector = get_camera_zoom_to_tilemap()
	set_zoom(zoom_vector)
	

func get_tilemap_info():
	var tile_size = tilemap.get_tileset().tile_size
	var tilemap_rect = tilemap.get_used_rect()
	var tilemap_size = Vector2i(tilemap_rect.end.x - tilemap_rect.position.x,
								tilemap_rect.end.y - tilemap_rect.position.y
		)
	return { "size": tilemap_size, "tile_size": tile_size }
