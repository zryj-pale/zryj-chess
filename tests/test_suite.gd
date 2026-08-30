class_name TestSuite
extends RefCounted

# Minimal headless test-suite helper. No editor or GUT dependency: each test
# file builds one of these, records case()/check() results, and
# tests/run_tests.gd aggregates every suite's summary() into a pass/fail
# report with a non-zero exit code on failure.

var suite_name := ""
var passed := 0
var failed := 0

func _init(name: String) -> void:
	suite_name = name

func check(label: String, condition: bool) -> void:
	case(label, condition, true)

func case(label: String, actual, expected) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		print("FAIL [%s] %s" % [suite_name, label])
		print("     got:      ", actual)
		print("     expected: ", expected)

func summary() -> Dictionary:
	return {"name": suite_name, "passed": passed, "failed": failed}
