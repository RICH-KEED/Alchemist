---
name: DB Migration Generator
description: From domain entities — generate Drift schema definitions, DAOs with typed queries, forward migrations with round-trip tests, and diff old vs. new schema. Use when adding or changing persistent models, creating a new schema version, reviewing migration safety, or generating a full Drift data layer from freezed entities.
when_to_use: Trigger on "generate a migration for this entity", "add a new table to the schema", "I changed the Task model — update the DB", "diff the schema", "create a DAO for this entity", "write the round-trip test for this migration", "bump the schema version", or "wire up Drift for this feature". Runs after the domain entity exists (freezed + json_serializable) and before the repository layer. Pairs with stage 06 (architecture) for initial scaffolding and stage 12 (API testing) for contract testing patterns.
---

# DB Migration Generator (Roadmap #51)

Turn a **freezed domain entity** into a complete, safe, and versioned Drift data layer: table definition, typed DAO, forward migrations, round-trip tests, and a schema diff when modifying an existing schema. Every migration is test-backed and never loses data.

House style: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) (stack: Drift, freezed entities, feature-first layout). When this skill and that file disagree, that file wins.

**Output artifact:** `lib/features/<feature>/data/db/` (schema, DAO, migrations, database wiring) + test mirror + `docs/schema_diff_vN_to_vN+1.md`.

---

## 1. Five-step workflow

Run in order for each domain entity. Complete compilable reference: [`templates/drift_migration.example.dart`](templates/drift_migration.example.dart).

| Step | What | Output |
|---|---|---|
| **1. Read entity** | Parse freezed class — fields, types, nullable, defaults | Field map: `dart → sql` |
| **2. Generate table** | `class X extends Table` per entity; typed columns; indexes on FKs | `schema.dart` |
| **3. Generate DAO** | Typed queries: insert/update/delete/getById/getAll + filtered | `dao.dart` |
| **4. Generate migration** | `onCreate` for baseline; discrete `onUpgrade` steps N→N+1 | `migrations.dart` |
| **5. Generate round-trip test** | Build DB → insert → read → assert; test each migration step | `migration_test.dart` |

If the entity already has a table and you're modifying it, skip to steps 4–5 and also produce a schema diff (§4).

---

## 2. Drift conventions

- One `extends Table` class per entity. Class name is **plural** (`Task` → `Tasks`).
- Every freezed field → one typed column (snake_case). FKs and frequently-filtered columns get `@TableIndex`.
- Primary key: `integer().autoIncrement()`. Timestamps: `withDefault(currentDateAndTime)`.

### Type mapping

| Dart | Drift | SQL | Dart | Drift | SQL |
|---|---|---|---|---|---|
| `String` / `?` | `text()` / `.nullable()` | `TEXT` | `bool` / `?` | `boolean()` / `.nullable()` | `INTEGER` |
| `int` / `?` | `integer()` / `.nullable()` | `INTEGER` | `DateTime` / `?` | `dateTime()` / `.nullable()` | `INTEGER` |
| `double` / `?` | `real()` / `.nullable()` | `REAL` | `Uint8List` | `blob()` | `BLOB` |
| `enum Foo` | `intEnum<Foo>()` or `textEnum<Foo>()` | `INTEGER/TEXT` | nested object | normalize into separate table (FK) | — |

Schema version: start at 1, bump monotonically via `MigrationStrategy`. Never skip or decrement.

---

## 3. Migration generation

**Structure:**

```dart
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async => await m.createAll(),
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) await _migrateV1ToV2(m);
    if (from < 3) await _migrateV2ToV3(m);
  },
);
```

**Available operations:**

| Operation | API | Reversible? |
|---|---|---|
| Add column | `m.addColumn(table, column)` | Always |
| Create table | `m.createTable(table)` | `m.deleteTable(name)` |
| Rename column | `m.renameColumn(table, old, new)` | Yes (swap) |
| Data migration | `m.update` / `customStatement` | Manual reverse script |

**Safety rules (non-negotiable):**

- **Never drop a column.** Mark it deprecated; drop in the next major version.
- **Never lose data.** New non-nullable columns MUST have a default: `m.addColumn(table, column.withDefault(...))`. If replacing a column, copy old data first.
- **Test each step in isolation** — round-trip tests (§5) cover every migration.

**Example:**

```dart
Future<void> _migrateV1ToV2(Migrator m) async {
  await m.addColumn(tasks, tasks.dueAt);                        // nullable → no default
}
Future<void> _migrateV2ToV3(Migrator m) async {
  await m.createTable(projects);
  await m.addColumn(tasks, tasks.projectId.copyWith(             // FK → needs default
    defaultValue: const Constant(0)));
}
```

---

## 4. Schema diff

When modifying an existing schema, produce a diff document flagging additive vs. breaking changes:

```markdown
# Schema diff: v2 → v3

## Tables       | ## Columns (tasks)
tasks     ✅    | title       TEXT    no  ✅
projects  ➕    | due_at      INTEGER yes ✅ (v2)
                | project_id  INTEGER no  ➕  FK → projects.id, default: 0

## Impact: 2 additive, 0 breaking, no data migration needed, reversible ✅
```

**Breaking changes** require human review: column type alteration requiring data migration, column removal, or index changes altering query plans.

---

## 5. Round-trip tests

**Per-version test pattern:**

```dart
test('round-trip: insert and read task (v3)', () async {
  final db = AppDatabase(NativeDatabase.memory());
  final id = await db.tasksDao.insert(TasksCompanion(
    title: const Value('Fix login'), isCompleted: const Value(false),
  ));
  final fetched = await db.tasksDao.getById(id);
  expect(fetched!.title, 'Fix login');
  expect(fetched.isCompleted, false);
  await db.close();
});
```

**Migration-up test (data preserved across upgrade):**

```dart
test('migrate v2 → v3 preserves data', () async {
  var db = AppDatabase(NativeDatabase.memory());
  await db.customStatement('PRAGMA user_version = 2');
  await db.into(db.tasks).insert(/* v2-shaped row */);
  await db.close();

  db = AppDatabase(NativeDatabase.memory());   // triggers v2→v3 upgrade
  final rows = await db.select(db.tasks).get();
  expect(rows, hasLength(1));
  await db.close();
});
```

**Test checklist:**

- [ ] Insert + read-back for every entity at current version
- [ ] Nullable fields: insert null → read back null
- [ ] Default values: omit column → read back default
- [ ] Each migration step: open at N, insert data, upgrade to N+1, verify preserved
- [ ] Multi-version skip: open at N-2, upgrade to current, data intact
- [ ] Schema version: `PRAGMA user_version` matches expected
- [ ] Error cases: getById on missing id returns null; delete missing returns 0

---

## 6. Integration with freezed entities

**Mapping rules:**

1. Freezed class name → pluralized table name (`Task` → `Tasks`).
2. Every field → column (both snake_case). `@Default` → `withDefault(...)`.
3. `JsonKey` noted but Drift uses Dart names, not JSON keys.
4. Nested entities → FK to separate table, never embedded JSON.
5. Enums → `intEnum<Foo>()` or `textEnum<Foo>()`.

**Boundaries:**

- **Do not modify** the freezed entity — it is the source of truth.
- **DAOs return Drift data classes** — the repository (not the DAO) maps them to domain entities.
- **Every schema change** gets a discrete version bump — never batch unrelated changes.

**Repository mapping (not in the DAO):**

```dart
Task toDomain(TaskDriftRow r) => Task(
  id: r.id, title: r.title, description: r.description,
  isCompleted: r.isCompleted, priority: TaskPriority.fromValue(r.priority),
  createdAt: r.createdAt, updatedAt: r.updatedAt,
  dueAt: r.dueAt, projectId: r.projectId == 0 ? null : r.projectId,
);
```

---

## 7. File layout

```
lib/features/<feature>/data/db/
├── schema.dart          # Table definitions
├── dao.dart             # @DriftAccessor DAOs
├── migrations.dart      # MigrationStrategy + per-step functions
└── database.dart        # @DriftDatabase(tables, daos) + schemaVersion + migration strategy

test/features/<feature>/data/db/
└── migration_test.dart
```

---

## 8. Quick-start

1. [ ] `lib/features/<feature>/data/db/` exists
2. [ ] `schema.dart` — one `extends Table` per entity, typed columns, `@TableIndex` on FKs
3. [ ] `dao.dart` — insert/update/delete/getById/getAll + filtered + watch
4. [ ] `migrations.dart` — `onCreate` + `onUpgrade` chain; one function per version step
5. [ ] `database.dart` — `@DriftDatabase` wiring with `schemaVersion` and `migration`
6. [ ] `migration_test.dart` — all checklist items from §5 green
7. [ ] `flutter analyze` clean; `flutter test` green
8. [ ] Schema diff doc if modifying an existing schema

Full compilable reference: [`templates/drift_migration.example.dart`](templates/drift_migration.example.dart).
