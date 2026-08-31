class_name CardHooks
extends RefCounted

# Generic hook dispatch for active cards. game_rules.gd and main.gd call the
# functions below and never mention a card id themselves; only this file
# (plus CardRegistry's data) knows which id implements which hook. Adding a
# card means adding/extending a branch here, not touching the call sites in
# move generation or turn handling.

## moves / capture / attacks: does an active card remove this piece from
## play entirely (indestructible_pawns: pawns can't move, attack or be
## captured)?
static func is_piece_neutralized(cards: Dictionary, piece: Dictionary) -> bool:
	if CardRegistry.any_has(cards, "indestructible_pawns") and str(piece.get("type", "")) == "P":
		return true
	return false

## blocked_squares: is this square currently off-limits to movement/attacks
## (duck_chess: the duck's square)?
static func is_square_blocked(cards: Dictionary, square: Vector2i, duck_position: Vector2i) -> bool:
	if CardRegistry.any_has(cards, "duck_chess") and square == duck_position:
		return true
	return false

## win_condition: has `mover` already won outright from the board state
## alone (racing_kings: a king reached the far edge)? Returns the winner
## color, or "" if no active card ends the game this way.
static func win_condition_winner(cards: Dictionary, pieces: Array, board: Array[Vector2i], mover: String) -> String:
	if CardRegistry.has(cards, mover, "racing_kings") and GameRules.reached_opposite_edge(pieces, board, mover):
		return mover
	return ""

## after_move: does the move that just landed require an extra input step
## before the turn can be considered finished (duck_chess: place the duck)?
static func needs_extra_step_after_move(cards: Dictionary) -> bool:
	return CardRegistry.any_has(cards, "duck_chess")

## after_move: does anything else need to happen once `mover`'s move (and any
## required extra step) has fully landed? `context` carries the state a card
## might need to re-check (pieces/board/duck position).
## Returns {"grant_tile_to": String}.
static func after_move(cards: Dictionary, mover: String, context: Dictionary) -> Dictionary:
	var result := {"grant_tile_to": ""}
	if CardRegistry.has(cards, mover, "check_adds_tile"):
		var pieces: Array = context.get("pieces", [])
		var board: Array = context.get("board", [])
		var duck_position: Vector2i = context.get("duck_position", Vector2i(-99, -99))
		var opponent := GameRules.other_color(mover)
		if GameRules.king_count(pieces, opponent) == 1 and GameRules.is_in_check(pieces, board, opponent, cards, duck_position):
			result["grant_tile_to"] = mover
	return result

## stalemate: `stalemated_color` has no legal move. Returns the winner color,
## or "" for a draw.
static func stalemate_winner(cards: Dictionary, stalemated_color: String) -> String:
	var other := GameRules.other_color(stalemated_color)
	var stalled_has := CardRegistry.has(cards, stalemated_color, "pat_win")
	var other_has := CardRegistry.has(cards, other, "pat_win")
	if stalled_has and other_has:
		return stalemated_color
	if other_has:
		return other
	if stalled_has:
		return stalemated_color
	return ""

## moves/capture: does this piece swap places with whatever it lands on -
## friend or foe - instead of capturing (knight_swap)? Global like
## indestructible_pawns: active for every knight once either player has it.
static func piece_swaps_on_contact(cards: Dictionary, piece: Dictionary) -> bool:
	return CardRegistry.any_has(cards, "knight_swap") and str(piece.get("type", "")) == "S"

## attacks: does this piece never threaten a king, i.e. never contributes to
## check (knight_swap: its knights can reposition freely but can't deliver
## check)?
static func piece_gives_no_check(cards: Dictionary, piece: Dictionary) -> bool:
	return piece_swaps_on_contact(cards, piece)

## moves: does the bishop bounce off board edges and indestructible pieces
## instead of stopping there (bouncing_bishop)?
static func bishop_bounces(cards: Dictionary) -> bool:
	return CardRegistry.any_has(cards, "bouncing_bishop")

## moves: castling options for the king at `king_index` (castling). No
## move-history is tracked and there's no once-per-game limit: any king and
## same-color rook sharing a row/column with at least one clear, unblocked
## square between them can castle. The king ends up adjacent to the rook's
## old square and the rook ends up adjacent to the king's old square, same
## relative arrangement as standard chess, generalized to any distance.
## Returns an Array of {rook_index, king_to, rook_to}.
static func castle_options(cards: Dictionary, pieces: Array, board: Array[Vector2i], king_index: int, duck: Vector2i = Vector2i(-99, -99)) -> Array:
	var options: Array = []
	if not CardRegistry.any_has(cards, "castling"):
		return options
	if king_index < 0 or king_index >= pieces.size():
		return options
	var king: Dictionary = pieces[king_index]
	if str(king["type"]) != "K":
		return options
	var color := str(king["color"])
	var king_pos := Vector2i(int(king["x"]), int(king["y"]))
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction in directions:
		var probe: Vector2i = king_pos + direction
		var gap := 0
		while probe in board:
			if is_square_blocked(cards, probe, duck):
				break
			var occupant := GameRules.piece_index_at(pieces, probe)
			if occupant != -1:
				var occ: Dictionary = pieces[occupant]
				if gap >= 1 and str(occ["type"]) == "W" and str(occ["color"]) == color:
					options.append({
						"rook_index": occupant,
						"king_to": probe - direction,
						"rook_to": king_pos + direction,
					})
				break
			gap += 1
			probe += direction
	return options

## moves: do pawns move one square in any of the 4 orthogonal directions
## instead of just forward (omni_pawns)? Captures stay forward-diagonal only.
static func pawns_move_omnidirectionally(cards: Dictionary) -> bool:
	return CardRegistry.any_has(cards, "omni_pawns")

## moves: can a pawn push two squares in whichever direction(s) it's
## otherwise allowed to move (double_step_pawns)? Composable with
## pawns_move_omnidirectionally - each is an independent modifier.
static func pawns_can_double_step(cards: Dictionary) -> bool:
	return CardRegistry.any_has(cards, "double_step_pawns")

## How many permanent "holes" (board_hole) does `color` start the match with?
## Per-owner, not global: only the player holding the card gets one.
static func starting_holes(cards: Dictionary, color: String) -> int:
	return 1 if CardRegistry.has(cards, color, "board_hole") else 0

## The highest board coordinate either color's active card allows
## (board_10x10 extends the normal 0..7 cap to 0..9).
static func board_max(cards: Dictionary) -> int:
	return 9 if CardRegistry.any_has(cards, "board_10x10") else 7
