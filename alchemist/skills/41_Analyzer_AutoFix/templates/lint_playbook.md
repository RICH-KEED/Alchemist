# very_good_analysis Lint Playbook

Decide the bucket for each remaining `flutter analyze` issue, then act.
Baseline: `package:very_good_analysis/analysis_options.yaml` + the house
`analysis_options.yaml`. See `../../references/CONVENTIONS.md` §7 (DoD = zero issues).

**Buckets:** `AUTO` = `dart fix --apply` clears it (the loop already tried).
`GUIDED` = mechanical shape, but make one tiny local choice — fix inline, no behavior change.
`JUDGMENT` = implies a decision/API/architecture change — **do not auto-fix; escalate**.

## Auto-fixable (cleared by `dart format` + `dart fix --apply`)

| Lint rule | Auto? | The fix |
|---|---|---|
| `prefer_const_constructors` | AUTO | Add `const` to the constructor call |
| `prefer_const_constructors_in_immutables` | AUTO | Add `const` to the immutable's constructor |
| `prefer_const_declarations` | AUTO | `final` → `const` for compile-time constants |
| `prefer_const_literals_to_create_immutables` | AUTO | Add `const` to the literal collection |
| `require_trailing_commas` | AUTO | `dart format` inserts the trailing comma |
| `directives_ordering` | AUTO | Sort/group `import`/`export`/`part` directives |
| `cascade_invocations` | AUTO | Collapse repeated receiver into `..` cascade |
| `avoid_redundant_argument_values` | AUTO | Drop arguments equal to the parameter default |
| `unnecessary_const` | AUTO | Remove the redundant `const` |
| `unnecessary_new` | AUTO | Remove the `new` keyword |
| `unnecessary_this` | AUTO | Remove the redundant `this.` |
| `unnecessary_late` | AUTO | Remove `late` where eager init works |
| `unnecessary_string_interpolations` | AUTO | Unwrap `'${x}'` → `x` |
| `unnecessary_brace_in_string_interps` | AUTO | `'${x}'` → `'$x'` |
| `prefer_final_locals` | AUTO | `var` → `final` for never-reassigned locals |
| `prefer_final_fields` | AUTO | Mark never-reassigned private field `final` |
| `prefer_single_quotes` | AUTO | `"x"` → `'x'` |
| `sort_constructors_first` | AUTO | Move constructors above other members |
| `sort_unnamed_constructors_first` | AUTO | Unnamed constructor before named ones |
| `sort_child_properties_last` | AUTO | Put `child`/`children` last in the arg list |
| `prefer_const_constructors` (Widget) | AUTO | Add `const` to widget construction |
| `omit_local_variable_types` | AUTO | Drop the explicit local type (`final x = …`) |
| `unnecessary_lambdas` | AUTO | Replace `(x) => f(x)` with a tear-off `f` |
| `curly_braces_in_flow_control_structures` | AUTO | Add the missing `{ }` |

## Guided (mechanical, but make one small local choice)

| Lint rule | Bucket | What to do |
|---|---|---|
| `lines_longer_than_80_chars` | GUIDED | Wrap; if an unbreakable URL/string, an inline `// ignore` with reason is acceptable |
| `prefer_const_constructors` (needs `const` deps) | GUIDED | Make the leaf values `const` first, then add `const` |
| `unused_local_variable` / `unused_field` | GUIDED | Remove it — but confirm it isn't a forgotten use first |
| `unused_import` | GUIDED | Usually AUTO; if it's a side-effecting import, keep with a reason |
| `unawaited_futures` | GUIDED | `await` it, or wrap in `unawaited(...)` if fire-and-forget is intended |
| `cast_nullable_to_non_nullable` | GUIDED | Add a `!` only where you can prove non-null; else handle the null |
| `parameter_assignments` | GUIDED | Introduce a local instead of reassigning the parameter |
| `prefer_int_literals` (doubles) | GUIDED | `1.0` → `1` only where a `double` literal isn't required |

## Judgment-only — escalate, do NOT auto-fix

These look like lints but the correct fix is a decision. List each as
`severity • rule • file:line` in the report with a one-line "why it needs you".

| Lint rule | Why it needs a human |
|---|---|
| `avoid_dynamic_calls` / removing `dynamic` | Requires choosing the real type — an API/model design change |
| `public_member_api_docs` | Needs correct prose describing intent, not a placeholder stub |
| `use_build_context_synchronously` | Needs a `mounted` guard or a restructured async flow |
| `avoid_catches_without_on_clauses` | Which exception type to catch is domain knowledge |
| `avoid_catching_errors` | May hide a real bug; decide whether to catch or let it crash |
| `one_member_abstracts` | Abstraction shape — refactor only with intent |
| `prefer_mixin` | Architectural choice (mixin vs class) |
| `comment_references` | The referenced symbol may be wrong — verify the doc |
| `flutter_style_todos` | Reword the TODO and link an issue (per §7, TODOs resolved before DoD) |
| `deprecated_member_use` | Migrating off a deprecated API is a real change with test impact |
| Any `error`-severity diagnostic | A genuine compile/type bug — read and fix it, never suppress |
| Any `riverpod_*` (custom_lint) | Provider scope / `ref` misuse — correctness, not cosmetics |

## Suppression policy

`// ignore:` and `// ignore_for_file:` are **JUDGMENT** actions: each must carry a
one-line reason and be the genuine exception, not a shortcut. Generated files
(`*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.config.dart`, `*.mocks.dart`) are already
excluded in `analysis_options.yaml` — never add ignores there.
