@tool
extends EditorExportPlugin

const Preflight = preload("res://addons/export_optimizer/src/preflight.gd")
const OPTION = "optimization/optimize"
const CONFIG_OPTION = "optimization/config_file"

var _preflight = Preflight.new()


func _get_name() -> String:
	# Godot sorts file hooks by name; consume replacements before its GDScript token exporter.
	return "ExportOptimizer"


func _get_export_options(_platform:EditorExportPlatform) -> Array[Dictionary]:
	return [
		{"option": {"name": OPTION, "type": TYPE_BOOL}, "default_value": false},
		{"option": {"name": CONFIG_OPTION, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE,
			"hint_string": "*.yaml,*.yml"}, "default_value": ""},
	]


func _export_begin(_features:PackedStringArray, _is_debug:bool, _path:String, _flags:int) -> void:
	_preflight.clear()
	if not get_option(OPTION):
		return
	var config := Preflight.Optimizer.Config.from_file(str(get_option(CONFIG_OPTION)))
	if not config.errors.is_empty():
		_preflight.errors.append_array(config.errors)
		_report()
		return
	var options:Dictionary = config.options
	var passes:Array = []
	if options.struct_mode != "off":
		passes.append(Preflight.Optimizer.StructPass)
	if options.inline_mode != "off":
		passes.append(Preflight.Optimizer.InlinePass)
	var sources:Dictionary = {}
	_collect(EditorInterface.get_resource_filesystem().get_filesystem(), sources)
	var classes:Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		classes[entry.class] = entry.path
	_preflight.prepare(sources, classes, passes, options)
	if _preflight.errors.is_empty():
		print("Export Optimizer: stats=" + JSON.stringify(_preflight.stats))
	if options.inline_mode != "off" and _preflight.errors.is_empty():
		print("Export Optimizer: inline calls applied=%d skipped=%d direct=%d expanded=%d substituted_args=%d captured_args=%d repeated_access_captures=%d" % [
			_preflight.stats.get("inline_calls", 0), _preflight.stats.get("inline_skipped", 0),
			_preflight.stats.get("inline_direct_calls", 0), _preflight.stats.get("inline_expanded_calls", 0),
			_preflight.stats.get("inline_substituted_args", 0), _preflight.stats.get("inline_captured_args", 0),
			_preflight.stats.get("inline_repeated_access_captures", 0)])
	_report()


func _report() -> void:
	var platform = get_export_platform()
	for warning in _preflight.warnings:
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_WARNING, "Export Optimizer", warning)
	for error in _preflight.errors:
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Export Optimizer", error)
	if not _preflight.errors.is_empty():
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Export Optimizer",
			"Optimization failed preflight. Exporting original code; no optimizations were applied.")


func _export_file(path:String, _type:String, _features:PackedStringArray) -> void:
	if _preflight.replacements.has(path):
		add_file(path, _encode(_preflight.replacements[path]), false)
		skip()


func _export_end() -> void:
	_preflight.clear()


func _collect(directory:EditorFileSystemDirectory, sources:Dictionary) -> void:
	for index in directory.get_file_count():
		var path = directory.get_file_path(index)
		if path.get_extension() == "gd":
			sources[path] = path
	for index in directory.get_subdir_count():
		_collect(directory.get_subdir(index), sources)


func _encode(source:PackedByteArray) -> PackedByteArray:
	# Binary-token encoding belongs here when supported, independently of source optimization.
	return source
