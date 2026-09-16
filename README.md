# Export Optimizer

Enable **Export Optimizer** in Project Settings → Plugins. In Project → Export,
enable **Optimization → Structs** for tagged data classes or **Optimization → Inline
Functions** for tagged static arithmetic helpers. Both options default off and apply
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

Use `#! inline` above a top-level `static func` with explicit built-in value
parameter/return types. Simple numeric expressions still use direct substitution.
Straight-line bodies with local declarations/assignments and a final return use
fresh typed argument locals when the call is the whole expression in a local
declaration, simple assignment, or return. Calls and property reads can supply
arguments; their evaluation order is preserved. The log reports direct/expanded
counts separately. Original function definitions remain available.

Collections, objects, Variant declarations, control flow, defaults, script-member
references inside imported bodies, and nested inlining remain deferred. See the
shared [optimizer documentation](../addon_lib/gdscript_optimizer/README.md) for the
supported types and syntax.
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
