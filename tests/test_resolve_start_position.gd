class_name TestResolveStartPosition
extends RefCounted

static func run() -> TestSuite:
	var t := TestSuite.new("resolve_start_position")

	# A layout that does NOT mutually check both single kings is returned
	# unchanged (no reshuffle triggered). Knights keep the geometry simple:
	# neither one is anywhere near attacking the far-corner enemy king.
	var white_calm := [["K", 1, 1], ["S", 4, 4]]
	var black_calm := [["K", 6, 6], ["S", 3, 3]]
	var rng_calm := RandomNumberGenerator.new()
	rng_calm.seed = 1
	var resolved_calm := GameRules.resolve_start_position(white_calm, black_calm, rng_calm)
	t.case("an already-safe layout is left untouched (white)", resolved_calm["white"], white_calm)
	t.case("an already-safe layout is left untouched (black)", resolved_calm["black"], black_calm)

	# A layout where both single kings mutually check each other must be
	# reshuffled until neither is in check: each side's rook sits one square
	# from the enemy king, along the same file.
	var white_check_setup := [["K", 3, 1], ["W", 3, 5]]
	var black_check_setup := [["K", 3, 6], ["W", 3, 2]]
	var rng_mutual := RandomNumberGenerator.new()
	rng_mutual.seed = 12345
	var resolved := GameRules.resolve_start_position(white_check_setup, black_check_setup, rng_mutual)
	var board := GameRules.initial_board()
	var final_pieces: Array = []
	for raw in resolved["white"]:
		final_pieces.append({"type": raw[0], "color": "b", "x": raw[1], "y": raw[2]})
	for raw in resolved["black"]:
		final_pieces.append({"type": raw[0], "color": "c", "x": raw[1], "y": raw[2]})
	t.check("reshuffled white king is no longer in check",
		not GameRules.is_in_check(final_pieces, board, "b"))
	t.check("reshuffled black king is no longer in check",
		not GameRules.is_in_check(final_pieces, board, "c"))
	t.case("reshuffle keeps the same piece count (white)", resolved["white"].size(), white_check_setup.size())
	t.case("reshuffle keeps the same piece count (black)", resolved["black"].size(), black_check_setup.size())

	return t
