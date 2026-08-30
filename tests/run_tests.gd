extends SceneTree

# Headless test runner, no editor and no GUT dependency required. Run from a
# terminal with:
#
#   godot --headless --path <project> --script res://tests/run_tests.gd
#
# Exit code is the number of failed cases (0 = all green), so it plugs
# straight into CI or a pre-commit check.

func _init() -> void:
	var suites: Array[TestSuite] = [
		TestMovement.run(),
		TestCheckMateStalemate.run(),
		TestMultiKing.run(),
		TestResolveStartPosition.run(),
		TestCards.run(),
	]

	var total_passed := 0
	var total_failed := 0
	for suite in suites:
		var result := suite.summary()
		total_passed += int(result["passed"])
		total_failed += int(result["failed"])
		print("%-24s %d passed, %d failed" % [result["name"], result["passed"], result["failed"]])

	print("----")
	print("TOTAL: %d passed, %d failed" % [total_passed, total_failed])
	quit(1 if total_failed > 0 else 0)
