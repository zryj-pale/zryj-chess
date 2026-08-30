class_name TestCheckMateStalemate
extends RefCounted

static func run() -> TestSuite:
	var t := TestSuite.new("check/mate/stalemate")
	var board := GameRules.initial_board() # 6x6, coords 1..6

	# --- Plain check ---
	var check_pieces := [
		{"type": "K", "color": "c", "x": 3, "y": 1},
		{"type": "W", "color": "b", "x": 3, "y": 6},
		{"type": "K", "color": "b", "x": 1, "y": 1},
	]
	t.check("rook on the same file gives check", GameRules.is_in_check(check_pieces, board, "c"))
	t.check("the checking side is not itself in check", not GameRules.is_in_check(check_pieces, board, "b"))

	# --- Checkmate: rook checks along the back rank, queen covers every escape ---
	var mate_pieces := [
		{"type": "K", "color": "c", "x": 1, "y": 1},
		{"type": "H", "color": "b", "x": 3, "y": 2},
		{"type": "W", "color": "b", "x": 6, "y": 1},
	]
	t.check("mated king is in check", GameRules.is_in_check(mate_pieces, board, "c"))
	t.check("mated king has no legal move", not GameRules.has_legal_move(mate_pieces, board, "c"))

	# --- Stalemate: king boxed in but not in check ---
	var stalemate_pieces := [
		{"type": "K", "color": "c", "x": 1, "y": 1},
		{"type": "H", "color": "b", "x": 3, "y": 2},
		{"type": "K", "color": "b", "x": 5, "y": 5},
	]
	t.check("stalemated king is not in check", not GameRules.is_in_check(stalemate_pieces, board, "c"))
	t.check("stalemated king has no legal move", not GameRules.has_legal_move(stalemate_pieces, board, "c"))

	# --- Neither: a king with a free square is not mated or stalemated ---
	var free_pieces := [
		{"type": "K", "color": "c", "x": 3, "y": 3},
		{"type": "K", "color": "b", "x": 1, "y": 1},
	]
	t.check("a king with open squares has a legal move", GameRules.has_legal_move(free_pieces, board, "c"))

	return t
