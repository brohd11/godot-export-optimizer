extends SceneTree

func _init() -> void:
	var failures := 0
	for suite in ["preflight", "config"]:
		var result = load("res://addons/export_optimizer/export_ignore/test/%s_test.gd" % suite).run_tests()
		print("\n".join(result.output))
		failures += result.result
	quit(0 if failures == 0 else 1)
