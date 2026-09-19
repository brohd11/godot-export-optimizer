extends RefCounted
## Render every replacement before exposing any bytes to Godot's export callbacks.
## An invalid source or replay discards the whole batch, leaving the original program intact.

const Optimizer = preload("res://addons/export_optimizer/src/utils_remote.gd").Optimizer

var replacements:Dictionary = {}
var errors:Array = []
var warnings:Array = []
var stats:Dictionary = {}


func prepare(sources:Dictionary, classes:Dictionary, passes:Array = [Optimizer.StructPass], options:Dictionary = {}) -> void:
	clear()
	var context = Optimizer.Context.new()
	context.set_global_classes(classes)
	errors.append_array(context.configure(options))
	if not errors.is_empty():
		return
	var optimizer = Optimizer.new()
	var result = optimizer.prepare(sources, context, passes)
	stats = optimizer.stats.duplicate()
	errors.append_array(result.errors)
	warnings.append_array(result.warnings)
	if not errors.is_empty():
		return
	var pending:Dictionary = {}
	for key:String in optimizer.planned_files():
		var file = FileAccess.open(sources[key], FileAccess.READ)
		if file == null:
			errors.append("%s: could not read source" % sources[key])
			continue
		var source = file.get_as_text()
		var edited = optimizer.apply(key, Array(source.split("\n")))
		warnings.append_array(edited.get("warnings", []))
		for name:String in edited.get("stats", {}):
			stats[name] = stats.get(name, 0) + edited.stats[name]
		for error in edited.errors:
			errors.append("%s: %s" % [sources[key], error])
		var text = "\n".join(edited.lines)
		if text != source:
			pending[key] = text.to_utf8_buffer()
	if errors.is_empty():
		replacements = pending


func clear() -> void:
	replacements = {}
	errors = []
	warnings = []
	stats = {}
