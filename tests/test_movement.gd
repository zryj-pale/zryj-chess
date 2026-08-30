class_name TestMovement
extends RefCounted

# Move generation for every piece type, plus legal_moves filtering out moves
# that would expose the mover's own king (a pin).

static func run() -> TestSuite:
	var t := TestSuite.new("movement")
	var board := GameRules.initial_board() # 6x6, coords 1..6

	# Filler kings kept off every line/diagonal used below so they never
	# interfere with the piece under test.
	var filler_kings := [
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 6, "y": 1},
	]

	# --- Knight: 8 destinations from a center square on an empty board ---
	var knight_pieces := filler_kings + [{"type": "S", "color": "b", "x": 3, "y": 3}]
	t.case("knight has 8 moves from center", GameRules.pseudo_moves(knight_pieces, board, 2).size(), 8)

	# --- Bishop: diagonals to the board edge ---
	var bishop_pieces := filler_kings + [{"type": "G", "color": "b", "x": 3, "y": 3}]
	t.case("bishop reaches every empty diagonal square", GameRules.pseudo_moves(bishop_pieces, board, 2).size(), 9)

	# --- Rook: straight lines to the board edge ---
	var rook_pieces := filler_kings + [{"type": "W", "color": "b", "x": 3, "y": 3}]
	t.case("rook reaches every empty straight square", GameRules.pseudo_moves(rook_pieces, board, 2).size(), 10)

	# --- Queen: union of bishop + rook moves ---
	var queen_pieces := filler_kings + [{"type": "H", "color": "b", "x": 3, "y": 3}]
	t.case("queen combines rook and bishop moves", GameRules.pseudo_moves(queen_pieces, board, 2).size(), 19)

	# --- King: 8 adjacent squares, no check filtering at the pseudo level ---
	var king_pieces := filler_kings + [{"type": "K", "color": "b", "x": 3, "y": 3}]
	t.case("king has 8 adjacent moves", GameRules.pseudo_moves(king_pieces, board, 2).size(), 8)

	# --- Pawn: forward push, blocked push, and diagonal capture ---
	var pawn_open := filler_kings + [{"type": "P", "color": "b", "x": 3, "y": 4}]
	t.check("pawn can push forward into an empty square",
		GameRules.pseudo_moves(pawn_open, board, 2).has(Vector2i(3, 3)))

	var pawn_blocked := filler_kings + [
		{"type": "P", "color": "b", "x": 3, "y": 4},
		{"type": "P", "color": "c", "x": 3, "y": 3},
	]
	t.check("pawn cannot push into an occupied square",
		not GameRules.pseudo_moves(pawn_blocked, board, 2).has(Vector2i(3, 3)))

	var pawn_capture := filler_kings + [
		{"type": "P", "color": "b", "x": 3, "y": 4},
		{"type": "P", "color": "c", "x": 4, "y": 3},
	]
	t.check("pawn can capture diagonally into an enemy piece",
		GameRules.pseudo_moves(pawn_capture, board, 2).has(Vector2i(4, 3)))
	t.check("pawn cannot move diagonally into an empty square",
		not GameRules.pseudo_moves(pawn_capture, board, 2).has(Vector2i(2, 3)))

	# --- legal_moves filters out moves that would expose the mover's king (pin) ---
	var pinned_rook := [
		{"type": "K", "color": "b", "x": 3, "y": 1},
		{"type": "W", "color": "b", "x": 3, "y": 3},
		{"type": "W", "color": "c", "x": 3, "y": 6},
	]
	var legal := GameRules.legal_moves(pinned_rook, board, 1)
	t.check("pinned rook may still move along the pin line", legal.has(Vector2i(3, 4)))
	t.check("pinned rook may still capture the pinning piece", legal.has(Vector2i(3, 6)))
	t.check("pinned rook cannot step sideways off the pin line", not legal.has(Vector2i(4, 3)))
	t.check("pinned rook cannot step sideways the other way either", not legal.has(Vector2i(1, 3)))

	return t
