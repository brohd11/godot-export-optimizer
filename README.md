# Export Optimizer

Enable **Export Optimizer** in Project Settings → Plugins. In Project → Export,
check **Optimization → Optimize**. It defaults off and applies to debug and release
exports. **Config File** optionally selects a YAML file; a blank path uses these defaults:

```yaml
structs: true
inline_functions: true
scalar_replacement: true
struct_read_types: typed_locals # off | typed_locals | as_casts
scalar_replacement_allow_ref_counted: false
struct_read_types_allow_ref_counted: false
inline_functions_allow_ref_counted: false
inline_functions_allow_variants: false
```

A config overrides only the keys it contains. Paths may be `res://` or relative to the
project root. See [optimizer.example.yaml](optimizer.example.yaml). Unknown keys, invalid
values, malformed YAML, and missing explicit files fail preflight and export original
code. Disabling Optimize skips config loading. Structs run before inlining; options
that depend on structs are inactive with a warning when `structs: false`.

Existing presets must enable Optimize again. The old Structs, Inline Functions, Scalar
Replacement, and Struct Read Types export settings are removed without migration.
Godot stores the enable switch and config path in `export_presets.cfg`.

Scalar replacement supports non-escaping locals with proven built-in value fields,
including `:=` fields, vectors, strings, and transforms. Aliases, whole-struct calls
or returns, lambda captures, dynamic fields, and coroutine lifetimes retain the Array
representation. Constructors must be single-line direct calls with supported parameters
and defaults. Calls that only become local after inlining are deferred.

`scalar_replacement_allow_ref_counted: true` and
`struct_read_types_allow_ref_counted: true` independently admit reference types in scalar
locals and field reads: Object/Node/RefCounted subclasses, custom classes, collections, packed arrays,
Callable, Signal, and nested structs. It can extend reference lifetimes and introduce
assignment/cast checks on freed objects. It does not relax escape or evaluation-order
checks, or change inline eligibility. Unknown and unrepresentable types remain skipped.
Scalar defaults also support null, literal collections, and empty built-in constructors;
effectful defaults remain excluded. Each mutable default is created independently.
Nested structs use their lowered Array type. Surviving typed-collection reads use Array
or Dictionary because existing struct lowering can erase element type metadata; scalar
locals retain their declared collection types. Incompatible lowered defaults are skipped.

Typed Locals captures safe reads before a statement. As Casts keeps each read at its
original position and restores its expression type with `as T`; the cast has runtime
cost. Writes and value-component writeback paths are never cast. Complex captures,
multiline statements, and inline lambda/semicolon statements are conservatively skipped.
Off retains the existing `:=` type repair. Export logs include applied and skipped counts.

The plugin uses `addons/addon_lib/gdscript_optimizer`; release packaging vendors the
shared optimizer dependencies through PluginExporter. YAMLParser 2.1.0 is an install
dependency declared by `require` in `plugin.cfg`; install it with the plugin.
The plugin requires Godot 4.6 or newer.

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

PluginExporter also supports these passes through the embedded `optimizer` block in
its `plugin_export.yml`, including an `enabled` master toggle. Its settings are independent
of project-export presets.

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
and scalar replacement, with inlining on/off and reference-type opt-in variants.
Reference allocation and field-read workloads accompany the value-type workloads. It checks equal results before measuring,
warms up each workload, rotates variant order, and saves generated sources, logs, raw
samples, and a Markdown report in a temporary directory. Use `--iterations`, `--samples`,
and `--output` to configure a run. `--release-runtime /path/to/template` measures a matching
release runtime; otherwise results are explicitly labeled as editor measurements.

Direct inlining supports single-return boolean/comparison expressions and String
`begins_with`, `ends_with`, `contains`, and `is_empty` predicates, including conditional
call sites. Arguments must be literals or locals; no conditional temporaries are introduced.
`inline_functions_allow_ref_counted` permits direct reference member/index access and
method calls without parameter lifetime protection. `inline_functions_allow_variants`
permits unchecked Variant substitution, removing signature checks/conversions; unknown
runtime values may include references. Known reference types still require their own opt-in.
Both flags default to false and leave existing template expansion rules unchanged.
The old `allow_ref_counted` key is rejected; replace it with the two struct flags above.
