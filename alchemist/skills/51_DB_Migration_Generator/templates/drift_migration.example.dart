import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — The freezed domain entity (source of truth)
// ─────────────────────────────────────────────────────────────────────────────
//
// This is the entity the DB layer is generated from. Every field here becomes
// a column; the Drift table is pluralized (Task → Tasks).
//
// Generated via:
//   flutter pub run build_runner build

part 'drift_migration_example.freezed.dart';
part 'drift_migration_example.g.dart';

enum TaskPriority { low, medium, high }

@freezed
class Task with _$Task {
  const factory Task({
    required int id,
    required String title,
    String? description,
    @Default(false) bool isCompleted,
    @Default(TaskPriority.medium) TaskPriority priority,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? dueAt,       // added in v2
    int? projectId,        // added in v3
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Drift table definitions (schema.dart)
// ─────────────────────────────────────────────────────────────────────────────
//
// One class per entity, inheriting from Table. Column types map Dart → SQL.
// Indexes go on foreign-key columns and frequently-filtered columns.

/// Drift table for [Task] domain entities.
///
/// Columns are typed; nullable fields match the freezed definition exactly.
/// The [priority] column uses an intEnum converter for storage efficiency.
@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_status', columns: {#isCompleted})
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => intEnum<TaskPriority>().withDefault(
        const Constant(TaskPriority.medium),
      )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueAt => dateTime().nullable()();      // v2 addition
  IntColumn get projectId => integer().nullable()();         // v3 addition

  @override
  Set<Column> get primaryKey => {id};
}

/// New entity added in v3. Each Task optionally belongs to one Project.
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().nullable()();              // hex string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — DAOs with typed queries (dao.dart)
// ─────────────────────────────────────────────────────────────────────────────
//
// Each DAO is a @DriftAccessor. Queries are typed; the DAO stays pure Drift.
// The repository (not shown here) maps Drift rows → domain entities.

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<int> insert(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> update(TaskDriftRow entry) => update(tasks).replace(entry);

  Future<int> delete(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> markCompleted(int id) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          isCompleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ── Reads ─────────────────────────────────────────────────────────────────

  Future<TaskDriftRow?> getById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TaskDriftRow>> getAll() => select(tasks).get();

  Future<List<TaskDriftRow>> getIncomplete() =>
      (select(tasks)..where((t) => t.isCompleted.equals(false))).get();

  Future<List<TaskDriftRow>> getByProject(int projectId) =>
      (select(tasks)..where((t) => t.projectId.equals(projectId))).get();

  /// Watches all tasks as a reactive stream — UI rebuilds on any change.
  Stream<List<TaskDriftRow>> watchAll() => select(tasks).watch();

  // ── Counts ────────────────────────────────────────────────────────────────

  Future<int> count() => tasks.count().getSingle();

  Future<int> countIncomplete() =>
      (tasks.count()..where((t) => t.isCompleted.equals(false))).getSingle();
}

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  Future<int> insert(ProjectsCompanion entry) => into(projects).insert(entry);

  Future<ProjectDriftRow?> getById(int id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<ProjectDriftRow>> getAll() => select(projects).get();
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Migrations (migrations.dart)
// ─────────────────────────────────────────────────────────────────────────────
//
// One function per version step. The strategy chains them in order.
// Each step is testable in isolation (see STEP 5 tests).

/// Applies every migration from whatever version the user's DB is at.
///
/// Schema versions:
///   v1 — baseline: Tasks table (id, title, description, isCompleted, priority,
///        createdAt, updatedAt)
///   v2 — add: Tasks.dueAt (nullable DateTime)
///   v3 — add: Projects table + Tasks.projectId (nullable int, FK → projects.id)
MigrationStrategy buildMigrationStrategy() {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      // Create all tables at the latest schema version.
      // For a fresh install this is the only migration that runs.
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Chain every step — the from/to window may span multiple versions
      // (e.g. user upgrading from v1 directly to v3).
      if (from < 2) await _migrateV1ToV2(m);
      if (from < 3) await _migrateV2ToV3(m);
      // if (from < 4) await _migrateV3ToV4(m);
      // … add future steps here
    },
    beforeOpen: (OpeningDetails details) async {
      // Optional: run integrity checks, re-index, etc. before the DB opens.
      if (details.wasCreated) {
        // Fresh install — nothing to do.
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// v1 → v2: add nullable due_at column to tasks.
Future<void> _migrateV1ToV2(Migrator m) async {
  // Nullable columns need no default — existing rows get NULL.
  await m.addColumn(tasks, tasks.dueAt);
}

/// v2 → v3: create Projects table + add project_id FK on tasks.
Future<void> _migrateV2ToV3(Migrator m) async {
  // 1. Create the new Projects table.
  await m.createTable(projects);

  // 2. Add foreign key on tasks (nullable — existing tasks have no project).
  await m.addColumn(tasks, tasks.projectId);

  // 3. Backfill any data migrations if needed (none for this step).
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — Database class wiring (database.dart)
// ─────────────────────────────────────────────────────────────────────────────
//
// The @DriftDatabase annotation wires tables + DAOs + migration strategy.
// This is the single entry point the repository depends on.

@DriftDatabase(
  tables: [Tasks, Projects],
  daos: [TasksDao, ProjectsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3; // Bump this when adding migrations!

  @override
  MigrationStrategy get migration => buildMigrationStrategy();
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5 — Round-trip tests (migration_test.dart)
// ─────────────────────────────────────────────────────────────────────────────
//
// Tests verify: insert → read-back equality, migration up preserves data,
// migration down (where reversible), and schema version is correct.

void main() {
  late AppDatabase db;

  // ── Current-schema round-trip ─────────────────────────────────────────────

  group('v3 schema — round-trip', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insert task → read back matches', () async {
      final dao = db.tasksDao;

      // Insert a full task with all v3 fields.
      final id = await dao.insert(
        TasksCompanion(
          title: const Value('Fix the OAuth redirect'),
          description: const Value('Broken on Android 12 when redirect_uri has a custom scheme'),
          isCompleted: const Value(false),
          priority: const Value(TaskPriority.high),
          dueAt: const Value(null),          // v2 field, optional
          projectId: const Value(null),       // v3 field, optional
        ),
      );

      final fetched = await dao.getById(id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Fix the OAuth redirect');
      expect(fetched.description, 'Broken on Android 12 when redirect_uri has a custom scheme');
      expect(fetched.isCompleted, false);
      expect(fetched.priority, TaskPriority.high);
      expect(fetched.dueAt, isNull);
      expect(fetched.projectId, isNull);
    });

    test('insert task with all optional fields set → read back matches', () async {
      final dao = db.tasksDao;
      final dueDate = DateTime(2026, 7, 1);

      final id = await dao.insert(
        TasksCompanion(
          title: const Value('Ship v2.3'),
          description: const Value('Release notes done, store metadata updated'),
          isCompleted: const Value(false),
          priority: const Value(TaskPriority.medium),
          dueAt: Value(dueDate),
          projectId: const Value(1),
        ),
      );

      final fetched = await dao.getById(id);
      expect(fetched, isNotNull);
      expect(fetched!.dueAt, dueDate);
      expect(fetched.projectId, 1);
    });

    test('insert project → read back matches', () async {
      final dao = db.projectsDao;

      final id = await dao.insert(
        ProjectsCompanion(
          name: const Value('Android App'),
          color: const Value('#FF6B35'),
        ),
      );

      final fetched = await dao.getById(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Android App');
      expect(fetched.color, '#FF6B35');
    });

    test('schema version is 3 after fresh creation', () async {
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      final raw = version.read<int>('user_version');
      expect(raw, 3);
    });

    test('getIncomplete returns only incomplete tasks', () async {
      final dao = db.tasksDao;
      await dao.insert(TasksCompanion(title: const Value('Task A'), isCompleted: const Value(false)));
      await dao.insert(TasksCompanion(title: const Value('Task B'), isCompleted: const Value(true)));
      await dao.insert(TasksCompanion(title: const Value('Task C'), isCompleted: const Value(false)));

      final incomplete = await dao.getIncomplete();
      expect(incomplete, hasLength(2));
      expect(incomplete.map((t) => t.title), containsAll(['Task A', 'Task C']));
    });

    test('markCompleted sets isCompleted and updates updatedAt', () async {
      final dao = db.tasksDao;
      final beforeInsert = DateTime.now();
      final id = await dao.insert(TasksCompanion(title: const Value('Bug report')));

      await dao.markCompleted(id);
      final fetched = await dao.getById(id);

      expect(fetched!.isCompleted, true);
      expect(fetched.updatedAt.isAfter(beforeInsert), true);
    });
  });

  // ── Migration step tests ──────────────────────────────────────────────────

  group('migration v1 → v2', () {
    test('existing tasks survive adding dueAt column', () async {
      // Open DB at schema version 1 with just the Tasks table (no dueAt).
      final v1Db = AppDatabase(NativeDatabase.memory());
      await v1Db.customStatement('PRAGMA user_version = 1');
      // Insert a v1-shaped task (manually — the DAO expects v3 schema).
      await v1Db.into(v1Db.tasks).insert(
            TasksCompanion(
              title: const Value('Survive migration'),
              isCompleted: const Value(false),
              priority: const Value(TaskPriority.low),
            ),
            mode: InsertMode.insert,
          );
      await v1Db.close();

      // Re-open at v3 — triggers v1→v2→v3 migrations.
      final latestDb = AppDatabase(NativeDatabase.memory());
      final rows = await latestDb.tasksDao.getAll();
      await latestDb.close();

      expect(rows, hasLength(1));
      expect(rows.first.title, 'Survive migration');
      // dueAt should be null (it was added as nullable in v2).
      expect(rows.first.dueAt, isNull);
    });
  });

  group('migration v2 → v3', () {
    test('existing tasks survive adding Projects table + projectId', () async {
      final dueAt = DateTime(2026, 8, 15);

      // Open at v2 — Tasks have dueAt but no projectId, no Projects table.
      final v2Db = AppDatabase(NativeDatabase.memory());
      await v2Db.customStatement('PRAGMA user_version = 2');
      await v2Db.into(v2Db.tasks).insert(
            TasksCompanion(
              title: const Value('Database refactor'),
              isCompleted: const Value(false),
              priority: const Value(TaskPriority.high),
              dueAt: Value(dueAt),
            ),
            mode: InsertMode.insert,
          );
      await v2Db.close();

      // Re-open at v3 — triggers v2→v3 migration.
      final latestDb = AppDatabase(NativeDatabase.memory());
      final tasks = await latestDb.tasksDao.getAll();
      final projects = await latestDb.projectsDao.getAll();
      await latestDb.close();

      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'Database refactor');
      // v2 field preserved.
      expect(tasks.first.dueAt, dueAt);
      // New v3 field defaults to null.
      expect(tasks.first.projectId, isNull);
      // Projects table was created but is empty.
      expect(projects, isEmpty);
    });
  });

  group('multi-version skip', () {
    test('v1 → v3 in one upgrade preserves data', () async {
      // User skipped v2 entirely — both migrations run in sequence.
      final oldDb = AppDatabase(NativeDatabase.memory());
      await oldDb.customStatement('PRAGMA user_version = 1');
      await oldDb.into(oldDb.tasks).insert(
            TasksCompanion(
              title: const Value('Ancient task'),
              isCompleted: const Value(true),
              priority: const Value(TaskPriority.medium),
            ),
            mode: InsertMode.insert,
          );
      await oldDb.close();

      final latestDb = AppDatabase(NativeDatabase.memory());
      final rows = await latestDb.tasksDao.getAll();
      final schemaVer =
          await latestDb.customSelect('PRAGMA user_version').getSingle();
      await latestDb.close();

      expect(rows, hasLength(1));
      expect(rows.first.title, 'Ancient task');
      expect(rows.first.dueAt, isNull);     // v2 addition
      expect(rows.first.projectId, isNull); // v3 addition
      expect(schemaVer.read<int>('user_version'), 3);
    });
  });

  // ── Default value tests ───────────────────────────────────────────────────

  group('default values', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('isCompleted defaults to false', () async {
      final id = await db.tasksDao.insert(
        TasksCompanion(title: const Value('Minimal task')),
      );

      final fetched = await db.tasksDao.getById(id);
      expect(fetched!.isCompleted, false);
    });

    test('priority defaults to medium', () async {
      final id = await db.tasksDao.insert(
        TasksCompanion(title: const Value('Default priority')),
      );

      final fetched = await db.tasksDao.getById(id);
      expect(fetched!.priority, TaskPriority.medium);
    });

    test('createdAt and updatedAt auto-populate', () async {
      final before = DateTime.now();
      final id = await db.tasksDao.insert(
        TasksCompanion(title: const Value('Timestamps check')),
      );

      final fetched = await db.tasksDao.getById(id);
      expect(fetched!.createdAt.isAfter(before), true);
      expect(fetched.updatedAt.isAfter(before), true);
    });
  });

  // ── Error cases ───────────────────────────────────────────────────────────

  group('error handling', () {
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('getById returns null for non-existent id', () async {
      final result = await db.tasksDao.getById(9999);
      expect(result, isNull);
    });

    test('delete non-existent id returns 0 changed rows', () async {
      final changed = await db.tasksDao.delete(9999);
      expect(changed, 0);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEMA HISTORY (documented snapshot for reference)
// ─────────────────────────────────────────────────────────────────────────────
//
// v1 (baseline):
//   CREATE TABLE tasks (
//     id          INTEGER PRIMARY KEY AUTOINCREMENT,
//     title       TEXT NOT NULL,
//     description TEXT,
//     is_completed INTEGER NOT NULL DEFAULT 0,
//     priority    INTEGER NOT NULL DEFAULT 1,  -- 0=low, 1=medium, 2=high
//     created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
//     updated_at  INTEGER NOT NULL DEFAULT (unixepoch())
//   );
//
// v2:
//   + ALTER TABLE tasks ADD COLUMN due_at INTEGER;  -- nullable DateTime
//
// v3:
//   + CREATE TABLE projects (
//       id         INTEGER PRIMARY KEY AUTOINCREMENT,
//       name       TEXT NOT NULL,
//       color      TEXT,
//       created_at INTEGER NOT NULL DEFAULT (unixepoch())
//     );
//   + ALTER TABLE tasks ADD COLUMN project_id INTEGER;  -- nullable FK → projects.id
//   + CREATE INDEX idx_tasks_project ON tasks(project_id);
//
// ─────────────────────────────────────────────────────────────────────────────
// QUICK-START: Copy this file, then replace:
//   1. Task / Tasks / tasks   → your entity / table / variable
//   2. Project / Projects / projects → your second entity (or remove)
//   3. TaskPriority → your enum
//   4. schemaVersion → highest version number
//   5. Migration steps → your version-to-version logic
//   6. Tests → your entity's field assertions
// ─────────────────────────────────────────────────────────────────────────────
