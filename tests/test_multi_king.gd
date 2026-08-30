class_name TestMultiKing
extends RefCounted

# A color with more than one king has no "the" king to check: is_in_check
# short-circuits to false for it, and its extra kings are ordinary,
# capturable pieces (only a color's last king is protected from capture).

static func run() -> TestSuite:
	var t := TestSuite.new("multi-king")
	var board := GameRules.initial_board() # 6x6, coords 1..6

	var pieces := [
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "b", "x": 6, "y": 6},
		{"type": "W", "color": "c", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 6, "y": 1},
	]
	t.case("white has two kings", GameRules.king_count(pieces, "b"), 2)
	t.check("a color with two kings is never reported in check",
		not GameRules.is_in_check(pieces, board, "b"))

	var rook_index := GameRules.piece_index_at(pieces, Vector2i(1, 6))
	t.check("a king is capturable while its color still has another king",
		GameRules.is_legal_move(pieces, board, rook_index, Vector2i(1, 1)))

	# Once only one king is left, that rule flips: it can never be captured.
	var single_king_pieces := [
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "W", "color": "c", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 6, "y": 1},
	]
	var lone_rook_index := GameRules.piece_index_at(single_king_pieces, Vector2i(1, 6))
	t.check("a color's last king can never be captured",
		not GameRules.is_legal_move(single_king_pieces, board, lone_rook_index, Vector2i(1, 1)))

	return t
