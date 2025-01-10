extends TileMap

enum Tile { OBSTACLE, START_POINT, END_POINT }

@onready var game_map: TileMap = $"."  # Referência ao TileMap atual

const CELL_SIZE = Vector2i(64, 32)
const BASE_LINE_WIDTH = 3.0
const DRAW_COLOR = Color.WHITE * Color(1, 1, 1, 0.5)

# Objeto para pathfinding em grades 2D
var _astar = AStarGrid2D.new()

var _start_point = Vector2i()
var _end_point = Vector2i()
var _path = PackedVector2Array()

# Lista de tiles com ID 2 que devem ser tratados de forma especial
var _ignored_tiles = []

func _ready():
	# Configura o AStarGrid2D
	_astar.region = game_map.get_used_rect()  # Define a região da grade baseada no TileMap
	_astar.cell_size = CELL_SIZE
	_astar.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN  # Configura o layout isométrico
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES

	# Atualiza o AStarGrid2D
	_astar.update()

	# Define as células sólidas (não andáveis) com base no TileMap
	for i in range(_astar.region.position.x, _astar.region.end.x):
		for j in range(_astar.region.position.y, _astar.region.end.y):
			var pos = Vector2i(i, j)
			var tile_id = get_cell_source_id(0, pos)
			# Adiciona tiles com ID 2 à lista especial
			if tile_id == 2:
				_ignored_tiles.append(pos)
			# Marca como sólido se não for andável e não for ID 2 ou ID 3
			elif tile_id != 1 and tile_id != 3:
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

	# Remove temporariamente os tiles com ID 2 do cálculo, exceto o ponto final
	for pos in _ignored_tiles:
		if pos != _end_point:
			_astar.set_point_solid(pos, true)

	# Verifica se o tile de destino é um portal (ID 3)
	var tile_id = get_cell_source_id(0, _end_point)
	if tile_id == 3:
		# Define pontos frontais e traseiros
		var front_point = _end_point + Vector2i(-1, 0)  # Ajuste para entrada pela frente
		var back_point = _end_point + Vector2i(1, 0)   # Ajuste para entrada por trás

		# Verifica se as entradas estão acessíveis
		var front_accessible = not _astar.is_point_solid(front_point)
		var back_accessible = not _astar.is_point_solid(back_point)

		# Determina qual entrada usar com base na acessibilidade
		var selected_point
		if front_accessible and back_accessible:
			selected_point = front_point if front_point.distance_to(_start_point) <= back_point.distance_to(_start_point) else back_point
		elif front_accessible:
			selected_point = front_point
		elif back_accessible:
			selected_point = back_point
		else:
			# Nenhuma entrada acessível
			print("Nenhuma entrada acessível para o portal!")
			return []

		# Gera o caminho até o ponto selecionado e depois ao portal
		_path = _astar.get_id_path(_start_point, selected_point)
		_path.append(_end_point)

	else:
		# Gera o caminho normalmente para tiles que não são portais
		_path = _astar.get_id_path(_start_point, _end_point)

	# Restaura os tiles com ID 2 como andáveis
	for pos in _ignored_tiles:
		_astar.set_point_solid(pos, false)

	if not _path.is_empty():
		queue_redraw()

	# Converte o caminho para posições locais
	var path_positions = []
	for cell_coords in _path:
		path_positions.append(map_to_local(cell_coords))

	return path_positions
