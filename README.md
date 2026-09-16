# Export Optimizer

Enable **Export Optimizer** in Project Settings → Plugins. In Project → Export,
enable **Optimization → Structs** for tagged data classes or **Optimization → Inline
Functions** for tagged static helpers. Both options default off and apply
to debug and release exports. When both are enabled, structs run first.
Godot stores it in `export_presets.cfg`.

With **Structs** enabled, **Scalar Replacement** removes eligible local struct
allocations, and **Struct Read Types** selects **Off**, **Typed Locals**, or **As
Casts** for surviving field reads. Both default off. They are independent of function
inlining; settings without Structs are inactive and produce a warning.

Scalar replacement supports non-escaping locals with proven built-in value fields,
including `:=` fields, vectors, strings, and transforms. Aliases, whole-struct calls
or returns, lambda captures, reference/dynamic fields, and coroutine lifetimes retain
the Array representation. Constructors must be single-line direct calls with supported
value parameters and literal/value-constructor defaults. Calls that only become local
after inlining are deferred.

Typed Locals captures safe reads before a statement. As Casts keeps each read at its
original position and restores its expression type with `as T`; the cast has runtime
cost. Writes and value-component writeback paths are never cast. Complex captures,
multiline statements, and inline lambda/semicolon statements are conservatively skipped.
Off retains the existing `:=` type repair. Export logs include applied and skipped counts.

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
python3 tests/export_optimizer/benchmark.py --godot /path/to/godot
```

The benchmark compares original objects, existing struct lowering, both read modes,
and scalar replacement, with inlining on/off. It checks equal results before measuring,
warms up each workload, rotates variant order, and saves generated sources, logs, raw
samples, and a Markdown report in a temporary directory. Use `--iterations`, `--samples`,
and `--output` to configure a run. `--release-runtime /path/to/template` measures a matching
release runtime; otherwise results are explicitly labeled as editor measurements.
