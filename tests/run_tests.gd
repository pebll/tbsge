extends SceneTree

var _fail_count := 0
var _pass_count := 0

func _initialize() -> void:
	# Make random-dependent logic deterministic across CI runs.
	seed(1337)

	var tests := [
		"res://tests/test_terrain_generation.gd",
		"res://tests/test_spawning.gd",
		"res://tests/test_moving.gd",
	]

	for path in tests:
		await _run_test_script(path)

	print("")
	print("==== TEST SUMMARY ====")
	print("passed: %d" % _pass_count)
	print("failed: %d" % _fail_count)
	print("======================")

	quit(0 if _fail_count == 0 else 1)

func _run_test_script(path: String) -> void:
	var script := load(path)
	if script == null:
		_fail_count += 1
		push_error("FAILED to load test script: %s" % path)
		return

	var inst = script.new()
	if inst == null:
		_fail_count += 1
		push_error("FAILED to instantiate test script: %s" % path)
		return

	if not inst.has_method("run"):
		_fail_count += 1
		push_error("Test script missing run(): %s" % path)
		return

	var result = await inst.run(self)
	var ok: bool = false
	if typeof(result) == TYPE_BOOL:
		ok = result
	if ok:
		_pass_count += 1
		print("PASS %s" % path)
	else:
		_fail_count += 1
		push_error("FAIL %s" % path)

