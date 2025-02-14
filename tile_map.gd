extends TileMap

enum Tile { OBSTACLE, START_POINT, END_POINT }

@onready var game_map: TileMap = $"."  # Reference to the current TileMap

const CELL_SIZE = Vector2i(64, 32)
const BASE_LINE_WIDTH = 3.0
const DRAW_COLOR = Color.WHITE * Color(1, 1, 1, 0.5)

# Object for 2D grid pathfinding
var _astar = AStarGrid2D.new()

var _start_point = Vector2i()
var _end_point = Vector2i()
var _path = PackedVector2Array()

# List of tiles with ID 2 and ID 3 that should be treated specially
var _ignored_tiles = []

func _ready():
	# Configure AStarGrid2D
	_astar.region = game_map.get_used_rect()  # Define the grid region based on the TileMap
	_astar.cell_size = CELL_SIZE
	_astar.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN  # Configure the isometric layout
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES

	# Update AStarGrid2D
	_astar.update()

	# Define solid (non-walkable) cells based on the TileMap
	for i in range(_astar.region.position.x, _astar.region.end.x):
		for j in range(_astar.region.position.y, _astar.region.end.y):
			var pos = Vector2i(i, j)
			var tile_id = get_cell_source_id(0, pos)
			# Add tiles with ID 2 and ID 3 to the special list
			if tile_id == 2 or tile_id == 3:
				_ignored_tiles.append(pos)
			# Mark as solid if not walkable and not ID 2 or ID 3
			elif tile_id != 1:
				_astar.set_point_solid(pos)

func _draw():
	if _path.is_empty():
		return

	var last_point = map_to_local(_path[0])
	for index in range(1, len(_path)):
		var current_point = map_to_local(_path[index])
		draw_line(last_point, current_point, DRAW_COLOR, BASE_LINE_WIDTH, true)
		draw_circle(current_point, BASE_LINE_WIDTH * 1.0, DRAW_COLOR)
		last_point = current_point

func round_local_position(local_position):
	return map_to_local(local_to_map(local_position))

func is_point_walkable(local_position):
	var map_position = local_to_map(local_position)
	if _astar.is_in_boundsv(map_position):
		return not _astar.is_point_solid(map_position)
	return false

func clear_path():
	if not _path.is_empty():
		_path.clear()
		queue_redraw()

func find_path(local_start_point, local_end_point):
	clear_path()

	_start_point = local_to_map(local_start_point)
	_end_point = local_to_map(local_end_point)

	# Temporarily remove tiles with ID 2 and ID 3 from the calculation, except the end point
	for pos in _ignored_tiles:
		if pos != _end_point:
			_astar.set_point_solid(pos, true)

	# Check if the destination tile is a portal (ID 3)
	var tile_id = get_cell_source_id(0, _end_point)
	if tile_id == 3:
		# Define front and back points
		var front_point = _end_point + Vector2i(-1, 0)  # Adjust for front entrance
		var back_point = _end_point + Vector2i(1, 0)   # Adjust for back entrance

		# Check if the entrances are accessible
		var front_accessible = not _astar.is_point_solid(front_point)
		var back_accessible = not _astar.is_point_solid(back_point)

		# Determine which entrance to use based on accessibility
		var selected_point
		if front_accessible and back_accessible:
			selected_point = front_point if front_point.distance_to(_start_point) <= back_point.distance_to(_start_point) else back_point
		elif front_accessible:
			selected_point = front_point
		elif back_accessible:
			selected_point = back_point
		else:
			# No accessible entrance
			print("No accessible entrance for the portal!")
			return []

		# Generate the path to the selected point and then to the portal
		_path = _astar.get_id_path(_start_point, selected_point)
		_path.append(_end_point)

	else:
		# Generate the path normally for non-portal tiles
		_path = _astar.get_id_path(_start_point, _end_point)

	# Restore tiles with ID 2 and ID 3 as walkable
	for pos in _ignored_tiles:
		_astar.set_point_solid(pos, false)

	if not _path.is_empty():
		queue_redraw()

	# Convert the path to local positions
	var path_positions = []
	for cell_coords in _path:
		path_positions.append(map_to_local(cell_coords))

	return path_positions
