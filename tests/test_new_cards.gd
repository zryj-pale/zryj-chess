class_name TestNewCards
extends RefCounted

# Covers the 5 rule-engine cards added after the original five:
# knight_swap, bouncing_bishop, castling, double_step_pawns, omni_pawns.
# board_hole and board_10x10 are exercised in main.gd (no pure GameRules
# surface of their own beyond CardHooks.starting_holes()/board_max()).

static func run() -> TestSuite:
	var t := TestSuite.new("new cards")
	var board := GameRules.initial_board() # 6x6, coords 1..6

	# --- knight_swap ---
	var cards_swap := {"b": "knight_swap", "c": ""}
	var swap_pieces := [
		{"type": "S", "color": "b", "x": 3, "y": 3},
		{"type": "P", "color": "c", "x": 4, "y": 5},
		{"type": "P", "color": "b", "x": 5, "y": 4},
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("knight_swap: can target an enemy piece's square",
		GameRules.is_legal_move(swap_pieces, board, 0, Vector2i(4, 5), cards_swap))
	t.check("knight_swap: can target an own piece's square too",
		GameRules.is_legal_move(swap_pieces, board, 0, Vector2i(5, 4), cards_swap))
	var check_setup := [
		{"type": "K", "color": "c", "x": 4, "y": 3},
		{"type": "S", "color": "b", "x": 3, "y": 1},
		{"type": "K", "color": "b", "x": 1, "y": 1},
	]
	t.check("knight_swap: this knight cannot deliver check",
		not GameRules.is_in_check(check_setup, board, "c", cards_swap))
	t.check("without the card, the same knight would check",
		GameRules.is_in_check(check_setup, board, "c", {}))

	# --- bouncing_bishop ---
	var cards_bounce := {"b": "bouncing_bishop", "c": ""}
	var bishop_pieces := [
		{"type": "G", "color": "b", "x": 2, "y": 1},
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	var bounced := GameRules.pseudo_moves(bishop_pieces, board, 0, cards_bounce)
	var unbounced := GameRules.pseudo_moves(bishop_pieces, board, 0, {})
	t.check("bouncing_bishop: reaches more squares than a normal bishop",
		bounced.size() > unbounced.size())
	var cards_bounce_and_indestructible := {"b": "bouncing_bishop", "c": "indestructible_pawns"}
	var blocked_pieces := [
		{"type": "G", "color": "b", "x": 1, "y": 1},
		{"type": "P", "color": "c", "x": 3, "y": 3},
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	var past_the_pawn := GameRules.pseudo_moves(blocked_pieces, board, 0, cards_bounce_and_indestructible)
	t.check("bouncing_bishop: cannot land on an indestructible piece",
		not past_the_pawn.has(Vector2i(3, 3)))
	t.check("bouncing_bishop: bounces off it and reaches squares beyond",
		past_the_pawn.has(Vector2i(2, 2)))

	# --- castling ---
	var cards_castle := {"b": "castling", "c": ""}
	var castle_pieces := [
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "W", "color": "b", "x": 5, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("castling: king gets a long-distance castle move toward the rook",
		GameRules.legal_moves(castle_pieces, board, 0, cards_castle).has(Vector2i(4, 1)))
	t.case("castling: reports the rook's matching move",
		GameRules.find_castle_move(cards_castle, castle_pieces, board, 0, Vector2i(4, 1)),
		{"rook_from": Vector2i(5, 1), "rook_to": Vector2i(2, 1)})
	var no_rook_pieces := [
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("castling: no option without an aligned rook",
		not GameRules.legal_moves(no_rook_pieces, board, 0, cards_castle).has(Vector2i(4, 1)))
	var adjacent_pieces := [
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "W", "color": "b", "x": 2, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("castling: no gap between king and rook means no castle option",
		GameRules.find_castle_move(cards_castle, adjacent_pieces, board, 0, Vector2i(1, 1)).is_empty())

	# --- double_step_pawns ---
	var cards_double := {"b": "double_step_pawns", "c": ""}
	var pawn_pieces := [
		{"type": "P", "color": "b", "x": 3, "y": 4},
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("double_step_pawns: can push two squares",
		GameRules.pseudo_moves(pawn_pieces, board, 0, cards_double).has(Vector2i(3, 2)))
	t.check("without the card, only one square",
		not GameRules.pseudo_moves(pawn_pieces, board, 0, {}).has(Vector2i(3, 2)))
	var blocked_two_step := [
		{"type": "P", "color": "b", "x": 3, "y": 4},
		{"type": "P", "color": "c", "x": 3, "y": 3},
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	t.check("double_step_pawns: can't jump over a piece one square ahead",
		not GameRules.pseudo_moves(blocked_two_step, board, 0, cards_double).has(Vector2i(3, 2)))

	# --- omni_pawns ---
	var cards_omni := {"b": "omni_pawns", "c": ""}
	var omni_pieces := [
		{"type": "P", "color": "b", "x": 3, "y": 3},
		{"type": "P", "color": "c", "x": 4, "y": 3},
		{"type": "K", "color": "b", "x": 1, "y": 1},
		{"type": "K", "color": "c", "x": 6, "y": 6},
	]
	var omni_moves := GameRules.pseudo_moves(omni_pieces, board, 0, cards_omni)
	t.check("omni_pawns: can move backward",
		omni_moves.has(Vector2i(3, 4)))
	t.check("omni_pawns: can still move forward",
		omni_moves.has(Vector2i(3, 2)))
	t.check("omni_pawns: cannot capture sideways (forward-diagonal only)",
		not GameRules.is_legal_move(omni_pieces, board, 0, Vector2i(4, 3), cards_omni))

	return t
