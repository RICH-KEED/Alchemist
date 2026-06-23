# dartdoc conventions

How we write doc comments for public APIs in this app, and how we generate the
reference site. House stack: Dart 3, `dart doc` (dartdoc). The rule of thumb:
**document every public API; document the contract, not the implementation; skip
the obvious.** (CONVENTIONS §7.)

---

## The rules

1. **Use `///`** for doc comments (not `/** */`). Place them directly above the
   declaration — class, public member, top-level function, enum, typedef.
2. **First sentence = a complete summary.** dartdoc shows it alone in listings,
   so it must stand on its own. Start with a verb (third person) or noun phrase
   and end with a period.
   - `/// Fetches the signed-in user's profile.`
   - `/// A repository for user profiles.`
3. **Blank line after the summary**, then any further paragraphs. Markdown works.
4. **Link APIs in square brackets:** `[Profile]`, `[fetchProfile]`,
   `[ProfileRepository.refresh]`. dartdoc resolves and hyperlinks them. A broken
   link is a dartdoc warning — treat it as an error.
5. **Document the contract:** parameters, return value, nullability, side
   effects, and — per CONVENTIONS §5 — which `Failure`s a method can produce.
   Repositories return `Result<T>` and **never throw**; say so.
6. **Show examples** for non-obvious APIs with a fenced ` ```dart ` block.
7. **Reuse repeated text** with `{@template name} … {@endtemplate}` to define and
   `{@macro name}` to inject.
8. **Don't document the obvious, private members, or generated files**
   (`*.freezed.dart`, `*.g.dart`).

### Templates and macros

```dart
/// {@template profile_repository}
/// Reads and writes [Profile] data. All methods return a [Result] and never
/// throw across the layer boundary.
/// {@endtemplate}
abstract interface class ProfileRepository {
  /// {@macro profile_repository}
  ///
  /// Loads the current user's profile.
  Future<Result<Profile>> fetchProfile();
}
```

---

## Good vs bad

**Bad — restates the code, no contract, no summary value:**

```dart
/// profile
/// @param id the id
/// gets profile
Future<Profile> getProfile(String id) { ... }
```

Problems: no proper first sentence, restates the obvious, documents nothing
about failure/nullability, uses Javadoc-style `@param`, and the return type
(`Future<Profile>` that presumably throws) violates CONVENTIONS §5.

**Good — summary first, links, contract, example:**

```dart
/// Loads the profile for the user identified by [id].
///
/// Returns [Ok] with the [Profile] on success. Returns [Err] with a
/// [NotFoundFailure] when no profile exists for [id], or a [NetworkFailure]
/// on a transport error. Never throws.
///
/// ```dart
/// final result = await repo.getProfile(userId);
/// final name = switch (result) {
///   Ok(:final value) => value.displayName,
///   Err() => 'Unknown',
/// };
/// ```
Future<Result<Profile>> getProfile(String id);
```

**Bad — noise on a self-explanatory field:**

```dart
/// The name.
final String name;
```

Delete it. The name and type already say everything; an empty restatement only
rots. Document a field only when there's a non-obvious unit, range, or contract
(`/// Timeout in milliseconds; clamped to 1000–30000.`).

---

## Generating the docs

```bash
dart doc .            # generates static HTML into doc/api/
```

- Output lands in `doc/api/`; open `doc/api/index.html`. Don't commit it — it's
  a build artifact (gitignore `doc/api/`).
- In CI (skill 21_CICD) run `dart doc .` and fail the build on warnings so
  broken `[links]` and undocumented public members are caught in review.
- The analyzer's `public_member_api_docs` lint (enabled via `very_good_analysis`
  posture) flags public members that lack a doc comment — fix these as you go,
  don't batch them at the end.

---

## Quick checklist (per public API)

- [ ] Has a `///` comment.
- [ ] First sentence is a standalone summary ending in a period.
- [ ] Other APIs referenced with `[brackets]`, no broken links.
- [ ] States params, return, nullability, and possible `Failure`s.
- [ ] Has a `dart` example if behavior isn't obvious.
- [ ] Says nothing the signature already says.
