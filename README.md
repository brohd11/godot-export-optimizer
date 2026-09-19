# Export Optimizer

Enable **Export Optimizer** in Project Settings → Plugins. In Project → Export,
check **Optimization → Optimize**. It defaults off and applies to debug and release
exports. **Config File** optionally selects a YAML file; a blank path uses these defaults:

```yaml
struct_mode: tagged # auto | tagged | off
inline_mode: tagged # auto | tagged | off
aggressive: false
debug_tags: false
```

`tagged` considers explicitly tagged definitions; `auto` discovers eligible definitions;
`off` disables the pass even for tagged definitions. `#! struct; off` and `#! inline; off`
exclude individual definitions from discovery. Missing settings inherit the defaults above.
Unknown keys and invalid values are errors; there are no legacy configuration aliases.

A config path may be `res://` or relative to the project root. A blank path uses defaults.
See [optimizer.example.yaml](optimizer.example.yaml). The Optimize master switch remains
independent; disabling it skips config loading. Struct optimization precedes inlining.

Auto mode discovers supported data classes (including simple field-assignment constructors)
and top-level static helpers. Conservative mode requires proven value types. Aggressive
mode admits reference/Variant types and relaxes inline conversion and lifetime protection.
It does not bypass unsupported struct uses, syntax, or expansion limits. Unsuitable auto
candidates stay unchanged without disabling unrelated optimization.

Struct optimization includes scalar replacement and typed-local field reads. There are no
separate toggles and no field-read cast mode. Scalar replacement still requires nonescaping
locals with representable fields/defaults. Typed captures require safe statement positions.
Aggressive reference captures can extend lifetimes or change runtime checks.

`#! inline; substitute` explicitly permits unchecked argument substitution, including
skipping, repeating, or reordering effects. Without it, aggressive inlining rejects unproven
call/getter/index arguments before nested rewriting. A plain inline tag only selects a helper.
Conditional helpers expand as `if`/`elif`/`else`, reusing the destination or at most one result
local; conditional calls embedded in larger expressions stay calls. Static members retain
their defining scope through the receiver, such as `Utils.Keys.TYPE_DELIM`.

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

Aggressive or explicitly substituting helpers also support references and collections.
Immutable value defaults are supported in both policies. With both passes enabled, inline analysis and cross-file
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

The benchmark compares original objects and tagged/auto optimization with inlining and
aggressiveness varied. It checks equal results, rotates timed variants, and saves generated
sources, logs, raw samples, and a report. Use `--iterations`, `--samples`, and `--output`.
`--release-runtime` selects a matching release runtime; otherwise timings use the editor.

See the shared [optimizer documentation](../addon_lib/gdscript_optimizer/README.md) for
supported syntax, evaluation rules, defaults, and diagnostic counters.

`debug_tags: true` adds searchable `# optimizer-inline;`, `# optimizer-struct;`,
`# optimizer-scalar-replacement;`, and `# optimizer-struct-read;` comments beside
successful transformations. Inline comments record the helper, mode, tag arguments,
nesting depth, and source site. This defaults off and does not change runtime behavior.
