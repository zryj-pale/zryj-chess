class_name GameRules
extends RefCounted

const WHITE := "b"
const BLACK := "c"
const KNIGHT := [Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1)]
const DIAGONAL := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const STRAIGHT := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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
	var occupant_index := piece_index_at(pieces, target)
	if occupant_index != -1:
		var occupant: Dictionary = pieces[occupant_index]
		if str(occupant["color"]) == str(moving["color"]):
			return false
		if str(occupant["type"]) == "P" and CardRegistry.any_has(cards, "indestructible_pawns"):
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

static func pseudo_moves(pieces: Array, board: Array[Vector2i], index: int, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index < 0 or index >= pieces.size():
		return result
	var piece: Dictionary = pieces[index]
	var start := _position(piece)
	var color := str(piece["color"])
	if str(piece["type"]) == "P" and CardRegistry.any_has(cards, "indestructible_pawns"):
		return result
	match str(piece["type"]):
		"S": result.append_array(_step_moves(pieces, board, start, color, KNIGHT, duck))
		"K":
			result.append_array(_step_moves(pieces, board, start, color, STRAIGHT, duck))
			result.append_array(_step_moves(pieces, board, start, color, DIAGONAL, duck))
		"G": result.append_array(_line_moves(pieces, board, start, color, DIAGONAL, duck))
		"W": result.append_array(_line_moves(pieces, board, start, color, STRAIGHT, duck))
		"H":
			result.append_array(_line_moves(pieces, board, start, color, STRAIGHT, duck))
			result.append_array(_line_moves(pieces, board, start, color, DIAGONAL, duck))
		"P":
			var direction := -1 if color == WHITE else 1
			var forward := start + Vector2i(0, direction)
			if forward in board and piece_index_at(pieces, forward) == -1 and forward != duck:
				result.append(forward)
			for dx in [-1, 1]:
				var capture := start + Vector2i(dx, direction)
				var target_index := piece_index_at(pieces, capture)
				if capture in board and target_index != -1 and str(pieces[target_index]["color"]) != color and not (str(pieces[target_index]["type"]) == "P" and CardRegistry.any_has(cards, "indestructible_pawns")):
					result.append(capture)
	return result

static func attack_squares(pieces: Array, board: Array[Vector2i], piece: Dictionary, cards: Dictionary = {}, duck: Vector2i = Vector2i(-99, -99)) -> Array[Vector2i]:
	if str(piece["type"]) == "P" and CardRegistry.any_has(cards, "indestructible_pawns"):
		return []
	if str(piece["type"]) != "P":
		return pseudo_moves(pieces, board, pieces.find(piece), cards, duck)
	var result: Array[Vector2i] = []
	var direction := -1 if str(piece["color"]) == WHITE else 1
	for dx in [-1, 1]:
		var target := _position(piece) + Vector2i(dx, direction)
		if target in board and target != duck:
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

static func stalemate_winner(cards: Dictionary, stalemated_color: String) -> String:
	var other := other_color(stalemated_color)
	var stalled_has := CardRegistry.has(cards, stalemated_color, "pat_win")
	var other_has := CardRegistry.has(cards, other, "pat_win")
	if stalled_has and other_has:
		return stalemated_color
	if other_has:
		return other
	if stalled_has:
		return stalemated_color
	return ""

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

static func _step_moves(pieces: Array, board: Array[Vector2i], start: Vector2i, color: String, directions: Array, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in directions:
		var target: Vector2i = start + direction
		var occupant := piece_index_at(pieces, target)
		if target in board and target != duck and (occupant == -1 or str(pieces[occupant]["color"]) != color):
			result.append(target)
	return result

static func _line_moves(pieces: Array, board: Array[Vector2i], start: Vector2i, color: String, directions: Array, duck: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in directions:
		var target: Vector2i = start + direction
		while target in board:
			if target == duck:
				break
			var occupant := piece_index_at(pieces, target)
			if occupant != -1:
				if str(pieces[occupant]["color"]) != color:
					result.append(target)
				break
			result.append(target)
			target += direction
	return result
