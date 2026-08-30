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
