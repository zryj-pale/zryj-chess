class_name GameRules
extends RefCounted

const WHITE := "b"
const BLACK := "c"
const KNIGHT: Array[Vector2i] = [Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const STRAIGHT: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func other_color(color: String) -> String:
	return BLACK if color == WHITE else WHITE

static func king_count(pieces: Array, color: String) -> int:
	var count := 0
	for piece in pieces:
		if str(piece["type"]) == "K" and str(piece["color"]) == color:
			count += 1
	return count

static func is_in_check(pieces: Array, board: Array[Vector2i], color: String, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> bool:
	# Additional kings are normal capturable units. Only the final king is checked.
	if king_count(pieces, color) != 1:
		return false
	var king_pos := Vector2i.ZERO
	for piece in pieces:
		if str(piece["type"]) == "K" and str(piece["color"]) == color:
			king_pos = _position(piece)
			break
	for piece in pieces:
		if str(piece["color"]) != color and king_pos in attack_squares(pieces, board, piece, cards, duck):
			return true
	return false

static func legal_moves(pieces: Array, board: Array[Vector2i], index: int, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index < 0 or index >= pieces.size():
		return result
	for target in pseudo_moves(pieces, board, index, cards, duck):
		if is_legal_move(pieces, board, index, target, cards, duck):
			result.append(target)
	return result

static func has_legal_move(pieces: Array, board: Array[Vector2i], color: String, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> bool:
	for index in range(pieces.size()):
		if str(pieces[index]["color"]) == color and not legal_moves(pieces, board, index, cards, duck).is_empty():
			return true
	return false

static func is_legal_move(pieces: Array, board: Array[Vector2i], index: int, target: Vector2i, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> bool:
	if index < 0 or index >= pieces.size() or not target in pseudo_moves(pieces, board, index, cards, duck):
		return false
	var moving: Dictionary = pieces[index]
	var castle := find_castle_move(cards, pieces, board, index, target, duck)
	if not castle.is_empty():
		var simulated: Array = pieces.duplicate(true)
		simulated[index]["x"] = target.x
		simulated[index]["y"] = target.y
		var rook_index := piece_index_at(simulated, castle["rook_from"])
		simulated[rook_index]["x"] = castle["rook_to"].x
		simulated[rook_index]["y"] = castle["rook_to"].y
		return not is_in_check(simulated, board, str(moving["color"]), cards, duck)
	var occupant_index := piece_index_at(pieces, target)
	if occupant_index != -1:
		var occupant: Dictionary = pieces[occupant_index]
		if CardHooks.piece_swaps_on_contact(cards, moving):
			# Trade places instead of capturing - still illegal if it would
			# leave the mover's own king in check.
			var start := _position(moving)
			var simulated: Array = pieces.duplicate(true)
			simulated[index]["x"] = target.x
			simulated[index]["y"] = target.y
			simulated[occupant_index]["x"] = start.x
			simulated[occupant_index]["y"] = start.y
			return not is_in_check(simulated, board, str(moving["color"]), cards, duck)
		if str(occupant["color"]) == str(moving["color"]):
			return false
		if CardHooks.is_piece_neutralized(cards, occupant):
			return false
		# The last king is never captured; additional kings are ordinary pieces.
		if str(occupant["type"]) == "K" and king_count(pieces, str(occupant["color"])) <= 1:
			return false
	var simulated: Array = pieces.duplicate(true)
	if occupant_index != -1:
		simulated.remove_at(occupant_index)
		if occupant_index < index:
			index -= 1
	simulated[index]["x"] = target.x
	simulated[index]["y"] = target.y
	return not is_in_check(simulated, board, str(moving["color"]), cards, duck)

## Is `target` one of the king at `index`'s castling destinations right now
## (castling card)? Returns {} if not, else {"rook_from", "rook_to"} so the
## caller can also reposition the rook.
static func find_castle_move(cards: Dictionary, pieces: Array, board: Array[Vector2i], index: int, target: Vector2i, duck: Vector2i = Vector2i(-99, -99)) -> Dictionary:
	if index < 0 or index >= pieces.size() or str(pieces[index]["type"]) != "K":
		return {}
	for option in CardHooks.castle_options(cards, pieces, board, index, duck):
		if option["king_to"] == target:
			var rook: Dictionary = pieces[option["rook_index"]]
			return {"rook_from": _position(rook), "rook_to": option["rook_to"]}
	return {}

static func pseudo_moves(pieces: Array, board: Array[Vector2i], index: int, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index < 0 or index >= pieces.size():
		return result
	var piece: Dictionary = pieces[index]
	var start := _position(piece)
	var color := str(piece["color"])
	if CardHooks.is_piece_neutralized(cards, piece):
		return result
	match str(piece["type"]):
		"S":
			if CardHooks.piece_swaps_on_contact(cards, piece):
				result.append_array(_knight_swap_moves(board, start, cards, duck))
			else:
				result.append_array(_step_moves(pieces, board, start, color, KNIGHT, cards, duck))
		"K":
			result.append_array(_step_moves(pieces, board, start, color, STRAIGHT, cards, duck))
			result.append_array(_step_moves(pieces, board, start, color, DIAGONAL, cards, duck))
			for option in CardHooks.castle_options(cards, pieces, board, index, duck):
				result.append(option["king_to"])
		"G":
			if CardHooks.bishop_bounces(cards):
				result.append_array(_bouncing_diagonal_moves(pieces, board, start, color, cards, duck))
			else:
				result.append_array(_line_moves(pieces, board, start, color, DIAGONAL, cards, duck))
		"W": result.append_array(_line_moves(pieces, board, start, color, STRAIGHT, cards, duck))
		"H":
			result.append_array(_line_moves(pieces, board, start, color, STRAIGHT, cards, duck))
			result.append_array(_line_moves(pieces, board, start, color, DIAGONAL, cards, duck))
		"P":
			var direction := -1 if color == WHITE else 1
			var move_dirs: Array[Vector2i] = [Vector2i(0, direction)]
			if CardHooks.pawns_move_omnidirectionally(cards):
				move_dirs = STRAIGHT
			for move_dir in move_dirs:
				var step1: Vector2i = start + move_dir
				if step1 in board and piece_index_at(pieces, step1) == -1 and not CardHooks.is_square_blocked(cards, step1, duck):
					result.append(step1)
					if CardHooks.pawns_can_double_step(cards):
						var step2: Vector2i = start + move_dir * 2
						if step2 in board and piece_index_at(pieces, step2) == -1 and not CardHooks.is_square_blocked(cards, step2, duck):
							result.append(step2)
			for dx in [-1, 1]:
				var capture := start + Vector2i(dx, direction)
				var target_index := piece_index_at(pieces, capture)
				if capture in board and target_index != -1 and str(pieces[target_index]["color"]) != color and not CardHooks.is_piece_neutralized(cards, pieces[target_index]):
					result.append(capture)
	return result

static func attack_squares(pieces: Array, board: Array[Vector2i], piece: Dictionary, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> Array[Vector2i]:
	if CardHooks.is_piece_neutralized(cards, piece) or CardHooks.piece_gives_no_check(cards, piece):
		return []
	if str(piece["type"]) != "P":
		return pseudo_moves(pieces, board, pieces.find(piece), cards, duck)
	var result: Array[Vector2i] = []
	var direction := -1 if str(piece["color"]) == WHITE else 1
	for dx in [-1, 1]:
		var target := _position(piece) + Vector2i(dx, direction)
		if target in board and not CardHooks.is_square_blocked(cards, target, duck):
			result.append(target)
	return result

static func piece_index_at(pieces: Array, target: Vector2i) -> int:
	for index in range(pieces.size()):
		if _position(pieces[index]) == target:
			return index
	return -1

static func resolve_start_position(white: Array, black: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pieces: Array = []
	for raw_piece in white:
		pieces.append({"type": str(raw_piece[0]), "color": WHITE, "x": int(raw_piece[1]), "y": int(raw_piece[2])})
	for raw_piece in black:
		pieces.append({"type": str(raw_piece[0]), "color": BLACK, "x": int(raw_piece[1]), "y": int(raw_piece[2])})
	var board := initial_board()
	if king_count(pieces, WHITE) == 1 and king_count(pieces, BLACK) == 1 and is_in_check(pieces, board, WHITE) and is_in_check(pieces, board, BLACK):
		for _attempt in range(500):
			_shuffle_positions(pieces, board, rng)
			if not is_in_check(pieces, board, WHITE) and not is_in_check(pieces, board, BLACK):
				break
	return {"white": _wire_pieces(pieces, WHITE), "black": _wire_pieces(pieces, BLACK)}

static func starting_turn(white: Array, black: Array, coin_result: String) -> String:
	var pieces: Array = []
	for raw_piece in white:
		pieces.append({"type": str(raw_piece[0]), "color": WHITE, "x": int(raw_piece[1]), "y": int(raw_piece[2])})
	for raw_piece in black:
		pieces.append({"type": str(raw_piece[0]), "color": BLACK, "x": int(raw_piece[1]), "y": int(raw_piece[2])})
	var board := initial_board()
	if is_in_check(pieces, board, WHITE):
		return WHITE
	if is_in_check(pieces, board, BLACK):
		return BLACK
	return BLACK if coin_result == "reszka" else WHITE

static func initial_board() -> Array[Vector2i]:
	var board: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			board.append(Vector2i(x, y))
	return board

static func edge_row(board: Array[Vector2i], color: String) -> int:
	var target_y := board[0].y
	for square in board:
		if color == WHITE:
			target_y = min(target_y, square.y)
		else:
			target_y = max(target_y, square.y)
	return target_y

static func reached_opposite_edge(pieces: Array, board: Array[Vector2i], color: String) -> bool:
	if board.is_empty():
		return false
	var target_y := edge_row(board, color)
	for piece in pieces:
		if str(piece["color"]) == color and str(piece["type"]) == "K" and int(piece["y"]) == target_y:
			return true
	return false

static func _shuffle_positions(pieces: Array, board: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var positions: Array[Vector2i] = board.duplicate()
	for index in range(positions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp := positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = temp
	for index in range(pieces.size()):
		pieces[index]["x"] = positions[index].x
		pieces[index]["y"] = positions[index].y

static func _wire_pieces(pieces: Array, color: String) -> Array:
	var result: Array = []
	for piece in pieces:
		if str(piece["color"]) == color:
			result.append([piece["type"], piece["x"], piece["y"]])
	return result

static func _position(piece: Dictionary) -> Vector2i:
	return Vector2i(int(piece["x"]), int(piece["y"]))

static func _step_moves(pieces: Array, board: Array[Vector2i], start: Vector2i, color: String, directions: Array, cards: Dictionary, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in directions:
		var target: Vector2i = start + direction
		var occupant := piece_index_at(pieces, target)
		if target in board and not CardHooks.is_square_blocked(cards, target, duck) and (occupant == -1 or str(pieces[occupant]["color"]) != color):
			result.append(target)
	return result

static func _line_moves(pieces: Array, board: Array[Vector2i], start: Vector2i, color: String, directions: Array, cards: Dictionary, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in directions:
		var target: Vector2i = start + direction
		while target in board:
			if CardHooks.is_square_blocked(cards, target, duck):
				break
			var occupant := piece_index_at(pieces, target)
			if occupant != -1:
				if str(pieces[occupant]["color"]) != color:
					result.append(target)
				break
			result.append(target)
			target += direction
	return result

# knight_swap: every knight-offset square in bounds is a candidate, occupied
# or not - landing on an empty one is a normal move, landing on a piece
# (either color) is a swap, resolved in is_legal_move().
static func _knight_swap_moves(board: Array[Vector2i], start: Vector2i, cards: Dictionary, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in KNIGHT:
		var target: Vector2i = start + offset
		if target in board and not CardHooks.is_square_blocked(cards, target, duck):
			result.append(target)
	return result

# bouncing_bishop: reflects off the board's own edges and off indestructible
# pieces instead of stopping there; still stops (and captures if appropriate)
# on any ordinary piece. A generous step budget guards against a direction
# that never finds anything to stop it on an irregular (holed) board.
static func _bouncing_diagonal_moves(pieces: Array, board: Array[Vector2i], start: Vector2i, color: String, cards: Dictionary, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board.is_empty():
		return result
	var min_x := board[0].x
	var max_x := board[0].x
	var min_y := board[0].y
	var max_y := board[0].y
	for square in board:
		min_x = mini(min_x, square.x)
		max_x = maxi(max_x, square.x)
		min_y = mini(min_y, square.y)
		max_y = maxi(max_y, square.y)
	var max_steps := (max_x - min_x + max_y - min_y + 4) * 4
	for start_dir in DIAGONAL:
		var pos := start
		var dir: Vector2i = start_dir
		var steps := 0
		while steps < max_steps:
			steps += 1
			var next: Vector2i = pos + dir
			if next.x < min_x or next.x > max_x:
				dir.x = -dir.x
			if next.y < min_y or next.y > max_y:
				dir.y = -dir.y
			next = pos + dir
			if next.x < min_x or next.x > max_x or next.y < min_y or next.y > max_y:
				break
			if not (next in board) or CardHooks.is_square_blocked(cards, next, duck):
				break
			var occupant := piece_index_at(pieces, next)
			if occupant != -1:
				var occ: Dictionary = pieces[occupant]
				if CardHooks.is_piece_neutralized(cards, occ):
					dir = -dir
					continue
				if str(occ["color"]) != color:
					result.append(next)
				break
			result.append(next)
			pos = next
	return result
