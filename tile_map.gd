extends TileMap

enum Tile { OBSTACLE, START_POINT, END_POINT }

@onready var game_map: TileMap = $"."

const CELL_SIZE = Vector2i(64, 32)
const BASE_LINE_WIDTH = 3.0
const DRAW_COLOR = Color(1, 1, 1, 0.5)

var _astar = AStarGrid2D.new()

var _start_point = Vector2i()
var _end_point = Vector2i()
var _path = []

func _ready():
	# Configuração do AStarGrid2D
	_astar.region = game_map.get_used_rect()
	_astar.cell_size = CELL_SIZE
	_astar.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES

	# Atualiza o AStarGrid2D
	_astar.update()

	# Define as células sólidas com base no TileMap
	for i in range(_astar.region.position.x, _astar.region.end.x):
		for j in range(_astar.region.position.y, _astar.region.end.y):
			var pos = Vector2i(i, j)
			if get_cell_source_id(0, pos) != 1:
				_astar.set_point_solid(pos)

func _draw():
	if _path.size() == 0:
		return

	var last_point = map_to_local(_path[0])
	for index in range(1, _path.size()):
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
	if _path.size() > 0:
		_path.clear()
		queue_redraw()

func find_path(local_start_point, local_end_point):
	clear_path()

	_start_point = local_to_map(local_start_point)
	_end_point = local_to_map(local_end_point)
	_path = _astar.get_id_path(_start_point, _end_point)

	if _path.size() > 0:
		var new_path = []
		for i in range(_path.size() - 1):
			var current = _path[i]
			var next = _path[i + 1]
			new_path.append(current)

			# Verifica se os tiles são adjacentes e adiciona um ponto intermediário
			if abs(current.x - next.x) + abs(current.y - next.y) == 1:
				var mid_point = (current + next) / 2
				new_path.append(mid_point)
		
		new_path.append(_path[_path.size() - 1])  # Adiciona o último ponto
		_path = new_path

		queue_redraw()

	# Converte o caminho para posições locais
	var path_positions = []
	for cell_coords in _path:
		path_positions.append(map_to_local(cell_coords))

	return path_positions
