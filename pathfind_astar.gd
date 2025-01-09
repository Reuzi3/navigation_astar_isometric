extends TileMap

enum Tile { OBSTACLE, START_POINT, END_POINT }

@onready var game_map: TileMap = $"."

const CELL_SIZE = Vector2i(64, 32)
const BASE_LINE_WIDTH = 3.0
const DRAW_COLOR = Color.WHITE * Color(1, 1, 1, 0.5)

# The object for pathfinding on 2D grids.
var _astar = AStarGrid2D.new()

var _start_point = Vector2i()
var _end_point = Vector2i()
var _path = PackedVector2Array()

func _ready():
	# Configure AStarGrid2D
	_astar.region = game_map.get_used_rect()  # Define a região da grade baseada no TileMap
	_astar.cell_size = CELL_SIZE
	_astar.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN  # Configura o layout isométrico
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	
	# Atualiza o AStarGrid2D
	_astar.update()
	
	# Define as células sólidas (obstáculos) com base no TileMap
	for i in range(_astar.region.position.x, _astar.region.end.x):
		for j in range(_astar.region.position.y, _astar.region.end.y):
			var pos = Vector2i(i, j)
			if get_cell_source_id(0, pos) == Tile.OBSTACLE:
				_astar.set_point_solid(pos)

func _draw():
	if _path.is_empty():
		return

	var last_point = map_to_local(_path[0])
	for index in range(1, len(_path)):
		var current_point = map_to_local(_path[index])
		draw_line(last_point, current_point, DRAW_COLOR, BASE_LINE_WIDTH, true)
		draw_circle(current_point, BASE_LINE_WIDTH * 2.0, DRAW_COLOR)
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
		erase_cell(0, _start_point)
		erase_cell(0, _end_point)
		queue_redraw()

func find_path(local_start_point, local_end_point):
	clear_path()

	_start_point = local_to_map(local_start_point)
	_end_point = local_to_map(local_end_point)
	_path = _astar.get_id_path(_start_point, _end_point)

	if not _path.is_empty():
		set_cell(0, _start_point, 0, Vector2i(Tile.START_POINT, 0))
		set_cell(0, _end_point, 0, Vector2i(Tile.END_POINT, 0))

	queue_redraw()

	# Convert path to local positions
	var path_positions = []
	for cell_coords in _path:
		path_positions.append(map_to_local(cell_coords))

	return path_positions
