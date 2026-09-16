@tool
extends EditorExportPlugin

const Preflight = preload("res://addons/export_optimizer/src/preflight.gd")
const OPTION = "optimization/structs"

var _preflight = Preflight.new()


func _get_name() -> String:
	# Godot sorts file hooks by name; consume replacements before its GDScript token exporter.
	return "ExportOptimizer"


func _get_export_options(_platform:EditorExportPlatform) -> Array[Dictionary]:
	return [{"option": {"name": OPTION, "type": TYPE_BOOL}, "default_value": false}]


func _export_begin(_features:PackedStringArray, _is_debug:bool, _path:String, _flags:int) -> void:
	_preflight.clear()
	if not get_option(OPTION):
		return
	var sources:Dictionary = {}
	_collect(EditorInterface.get_resource_filesystem().get_filesystem(), sources)
	var classes:Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		classes[entry.class] = entry.path
	_preflight.prepare(sources, classes)
	var platform = get_export_platform()
	for warning in _preflight.warnings:
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_WARNING, "Struct optimizer", warning)
	for error in _preflight.errors:
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Struct optimizer", error)
	if not _preflight.errors.is_empty():
		platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Struct optimizer",
			"Struct optimization failed preflight. Exporting original code; no optimizations were applied.")


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
