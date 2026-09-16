# Export Optimizer

Enable **Export Optimizer** in Project Settings → Plugins. In Project → Export,
enable **Optimization → Structs** for tagged data classes or **Optimization → Inline
Functions** for tagged static helpers. Both options default off and apply
to debug and release exports. When both are enabled, structs run first.
Godot stores it in `export_presets.cfg`.

The plugin uses `addons/addon_lib/gdscript_optimizer`; release packaging vendors the
shared dependencies through PluginExporter. It requires Godot 4.6 or newer.

Project scripts are analyzed together before any replacements are emitted. Only
files selected by Godot's export are replaced. Globals and resource paths survive,
and project source files are never edited. Analysis includes indexed scripts even
when the preset excludes them, so invalid tagged test code can disable optimization.

If preflight fails, the export log reports errors and **all original code** is
exported. Godot may still return a successful command-line exit code; this is not
a strict CI validation gate. Unsupported inline definitions/calls remain unchanged
with warnings. The log reports applied/skipped inline source-site counts.

Use `#! inline` above a top-level `static func` with explicit supported types.
Simple numeric expressions retain direct substitution. Larger templates choose direct
substitution or typed local capture per argument, using parameter reference counts,
argument shape, rebinding and mutation. Calls/getters/indexes evaluate once in order;
reference ownership and local lifetimes are preserved. Supported bodies include local
assignments and exhaustive terminal if/elif/else return trees.

Array/Dictionary, typed RefCounted-derived objects, tagged structs, and immutable value
default arguments are supported. With both passes enabled, inline analysis and cross-file
resolution use the in-memory struct output. Original definitions remain available.
The log reports direct/expanded sites, substituted/captured arguments, and repeated
access captures. See the shared [optimizer documentation](../addon_lib/gdscript_optimizer/README.md)
for exact types, syntax, and conservative fallback rules.

This option is currently exposed by project export only; PluginExporter continues
to select its existing struct pass.

Changed scripts are stored as `.gd` source in the package. Unchanged scripts follow
the preset's format. Binary-token output for changed scripts is deferred; the source
transform is independent of encoding. PCK encryption still applies when its filters
match the replacement `.gd` paths. A filter limited to `*.gdc` will miss those files.

The file hook is named `ExportOptimizer` to precede Godot's `GDScript` exporter. Other
plugins that replace these same files must not intercept them first.

Validation:

```sh
godot --headless --path . --script res://tests/export_optimizer/run_headless.gd
python3 tests/export_optimizer/export_smoke.py --godot /path/to/godot
```
