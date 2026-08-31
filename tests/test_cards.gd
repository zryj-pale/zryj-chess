class_name TestCards
extends RefCounted

# One suite per active card, exercising it through the same CardHooks entry
# points game_rules.gd and main.gd call, plus the incompatible-pair check.

static func run() -> TestSuite:
	var t := TestSuite.new("cards")
	var board := GameRules.initial_board() # 6x6, coords 1..6

	# --- indestructible_pawns: moves/capture/attacks hooks ---
	var cards_pawns := {"b": "indestructible_pawns", "c": ""}
	var pieces_pawns := [
		{"type": "P", "color": "b", "x": 3, "y": 3},
		{"type": "P", "color": "c", "x": 3, "y": 4},
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 1, "y": 1},
	]
	t.case("indestructible_pawns: white pawn has no pseudo-moves",
		GameRules.pseudo_moves(pieces_pawns, board, 0, cards_pawns).size(), 0)
	t.case("indestructible_pawns: applies to both colors once any player has it",
		GameRules.pseudo_moves(pieces_pawns, board, 1, cards_pawns).size(), 0)
	var rook_attacking_pawn := [
		{"type": "P", "color": "b", "x": 3, "y": 3},
		{"type": "W", "color": "c", "x": 3, "y": 1},
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 1, "y": 1},
	]
	t.check("indestructible_pawns: a shielded pawn cannot be captured",
		not GameRules.is_legal_move(rook_attacking_pawn, board, 1, Vector2i(3, 3), cards_pawns))

	# --- duck_chess: blocked_squares hook ---
	var cards_duck := {"b": "duck_chess", "c": ""}
	var duck_at := Vector2i(3, 3)
	var rook_pieces := [
		{"type": "W", "color": "b", "x": 3, "y": 1},
		{"type": "K", "color": "b", "x": 1, "y": 6},
		{"type": "K", "color": "c", "x": 1, "y": 1},
	]
	var rook_moves := GameRules.pseudo_moves(rook_pieces, board, 0, cards_duck, duck_at)
	t.check("duck_chess: the duck blocks the square it stands on",
		not rook_moves.has(Vector2i(3, 3)))
	t.check("duck_chess: the duck blocks squares beyond it too",
		not rook_moves.has(Vector2i(3, 4)))
	t.check("duck_chess: squares before the duck stay reachable",
		rook_moves.has(Vector2i(3, 2)))
	var rook_moves_no_card := GameRules.pseudo_moves(rook_pieces, board, 0, {"b": "", "c": ""}, duck_at)
	t.check("duck_chess: the same square only blocks while the card is active",
		rook_moves_no_card.has(Vector2i(3, 4)))

	# --- racing_kings: win_condition hook ---
	var cards_racing := {"b": "racing_kings", "c": ""}
	var king_at_edge := [{"type": "K", "color": "b", "x": 3, "y": 1}]
	t.case("racing_kings: a king on the far edge wins for its color",
		CardHooks.win_condition_winner(cards_racing, king_at_edge, board, "b"), "b")
	var king_mid_board := [{"type": "K", "color": "b", "x": 3, "y": 3}]
	t.case("racing_kings: no win from mid-board",
		CardHooks.win_condition_winner(cards_racing, king_mid_board, board, "b"), "")
	t.case("racing_kings: inactive without the card",
		CardHooks.win_condition_winner({"b": "", "c": ""}, king_at_edge, board, "b"), "")

	# --- check_adds_tile: after_move hook ---
	var cards_tile := {"b": "check_adds_tile", "c": ""}
	var checking_position := [
		{"type": "K", "color": "c", "x": 3, "y": 1},
		{"type": "W", "color": "b", "x": 3, "y": 5},
		{"type": "K", "color": "b", "x": 1, "y": 6},
	]
	var effects := CardHooks.after_move(cards_tile, "b", {
		"pieces": checking_position, "board": board, "duck_position": Vector2i(-99, -99)
	})
	t.case("check_adds_tile: grants the mover a tile when the opponent is checked",
		effects["grant_tile_to"], "b")
	var no_check_position := [
		{"type": "K", "color": "c", "x": 1, "y": 1},
		{"type": "W", "color": "b", "x": 3, "y": 5},
		{"type": "K", "color": "b", "x": 1, "y": 6},
	]
	var effects_no_check := CardHooks.after_move(cards_tile, "b", {
		"pieces": no_check_position, "board": board, "duck_position": Vector2i(-99, -99)
	})
	t.case("check_adds_tile: no tile without a check",
		effects_no_check["grant_tile_to"], "")

	# --- pat_win: stalemate hook ---
	t.case("pat_win: only the non-stalemated side has it -> they win",
		CardHooks.stalemate_winner({"b": "", "c": "pat_win"}, "b"), "c")
	t.case("pat_win: only the stalemated side has it -> they win anyway",
		CardHooks.stalemate_winner({"b": "pat_win", "c": ""}, "b"), "b")
	t.case("pat_win: both sides have it -> the stalemated side wins",
		CardHooks.stalemate_winner({"b": "pat_win", "c": "pat_win"}, "b"), "b")
	t.case("pat_win: neither side has it -> a draw",
		CardHooks.stalemate_winner({"b": "", "c": ""}, "b"), "")

	# --- incompatible-pair validation ---
	t.check("card compatibility: distinct cards are compatible with an empty ban list",
		CardRegistry.is_compatible("racing_kings", "duck_chess"))
	t.check("card compatibility: both sides picking the same card is always fine",
		CardRegistry.is_compatible("pat_win", "pat_win"))
	t.check("card compatibility: no card selected is always fine",
		CardRegistry.is_compatible("", "indestructible_pawns"))

	return t
