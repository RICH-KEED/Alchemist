---
name: API Testing
description: Test the networking/data layer without hitting real servers — mock the dio client, parse DTOs from JSON fixtures, assert repository DTO→entity and error→Failure mapping, and pin contracts so a backend change breaks a test. Use after Backend_Integration (11) when the user says "test the API", "mock the network", "test my repository", or "pin the API contract".
when_to_use: Trigger on "write API/data-layer tests", "mock dio / the http client", "test DTO parsing", "test repository error handling", "pin/snapshot the API contract", or stage 12 of the pipeline. For end-to-end widget/golden/coverage gates use skill 20 instead; for the dio client & repositories under test see skill 11.
---

# API Testing

Stage 12 of the [24-stage pipeline](../../references/PIPELINE.md). You verify the **data layer** that skill 11 built — data sources, DTOs, repositories — **entirely against mocks**. No real socket ever opens. House style is non-negotiable: [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md).

**Exit gate:** *API tests green against a mock; contracts pinned.*

Stack for this stage: `flutter_test` · **mocktail** · `dio` · JSON fixtures under `test/fixtures/`. No live network, no `http_mock_adapter` required (it's an option, see below).

---

## What to test at this layer

Test the three units skill 11 produces, plus the resilience behavior skill 14 adds:

1. **Data source — request shape.** Given a mocked `Dio`, calling `fetchArticles()` issues the **right method, path, and query params**. Catches "someone renamed the endpoint" bugs.
2. **Data source — DTO parsing.** A real JSON fixture deserializes into the DTO with every field populated and correctly typed (dates parsed, nullables handled, lists non-empty).
3. **Repository — happy path.** DTO → domain entity mapping is correct and the call returns `Ok(entity)`. The domain object must never expose JSON or DTO types.
4. **Repository — every error path.** Make the mock **throw a `DioException`** of each kind and assert the exact `Failure` subtype lands in `Err`:

   | Thrown `DioException` | Expected `Failure` |
   |---|---|
   | `type: connectionTimeout` / `sendTimeout` / `receiveTimeout` | `TimeoutFailure` |
   | `type: badResponse`, status `401` | `UnauthorizedFailure` |
   | `type: badResponse`, status `404` | `NotFoundFailure` |
   | `type: badResponse`, status `500` | `NetworkFailure` (or `ServerFailure`) |
   | `type: connectionError` (no network) | `NetworkFailure` |
   | `FormatException` / bad JSON | `UnknownFailure` (or `ParseFailure`) |

   The mapping itself lives in skill 15; here you **prove** it. One test per row — exhaustive, not "spot check one".
5. **Resilience behavior (from skill 14).** If the client retries, assert the mock was called *N* times then succeeded; assert a bounded retry gives up with the right `Failure`; assert a cancellation token aborts. Test the *policy*, not wall-clock time — never `Future.delayed` real seconds.

---

## How to mock the network

Pick **one** approach per project and stay consistent:

### A. mocktail mock of `Dio` (default — least machinery)

```dart
class MockDio extends Mock implements Dio {}
```

Stub the verb you use and return a hand-built `Response`:

```dart
when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
    .thenAnswer((_) async => Response(
          data: jsonDecode(readFixture('articles/example_list.json')),
          statusCode: 200,
          requestOptions: RequestOptions(path: '/articles'),
        ));
```

For errors, `thenThrow(DioException(...))`. You control everything; nothing touches a socket.

### B. Fake `HttpClientAdapter` / `http_mock_adapter` (closer to the wire)

Swap `dio.httpClientAdapter` for a fake that matches paths and returns canned bodies. Use this when you want to exercise dio's *own* interceptors/serialization (e.g. verifying a header interceptor from skill 13, or retry from skill 14). More realistic, more setup. `http_mock_adapter`'s `DioAdapter` is the easy path:

```dart
final dio = Dio();
final adapter = DioAdapter(dio: dio);
adapter.onGet('/articles', (s) => s.reply(200, jsonDecode(readFixture('articles/example_list.json'))),
    queryParameters: {'page': 1});
```

Rule of thumb: **A** for data-source/repository unit tests (this stage's bulk); **B** when the thing under test is an interceptor or the dio pipeline itself.

---

## JSON fixtures

Keep canned payloads out of Dart string literals — store them as real `.json` files so they're diffable and reusable:

```
test/
└── fixtures/
    └── articles/
        ├── example_list.json    # GET /articles  → list DTO
        └── example_item.json     # GET /articles/:id → single DTO
```

Load them with a tiny reader (see `templates/fixture_reader.dart`):

```dart
final json = jsonDecode(readFixture('articles/example_list.json'));
```

Register the fixtures dir as a test asset if you read via `rootBundle`; the file-IO reader in the template needs no registration. Fixtures should be **real responses** captured from the backend (scrub secrets), not invented shapes — that's what makes them a contract.

---

## Pinning contracts (so a backend change breaks a test)

A fixture is a frozen copy of what the backend sent. Pin it three ways:

1. **Parse assertion.** `ExampleArticleDto.fromJson(fixture)` must not throw and must populate every field. If the backend drops `published_at`, parsing or a non-null assert fails. This is your cheapest contract test.
2. **Schema/shape expectations.** Assert the keys you depend on exist and have the right type: `expect(json['items'], isA<List>())`, `expect(json['items'][0]['id'], isA<String>())`. A renamed/retyped field fails loudly with a clear message.
3. **Golden round-trip.** `dto.toJson()` re-serialized should match the fixture's relevant keys (`expect(dto.toJson()['id'], json['id'])`). Catches asymmetric map/unmap bugs.

Treat the fixtures as the **pinned contract**. When the backend genuinely changes, the test fails → you update the fixture *and* the mapper together, deliberately. That's the point: no silent drift.

---

## Coverage expectations

- **100% of mapping code**: every DTO field, every `DioException` branch → `Failure` row above. These are pure functions; there's no excuse to miss a branch.
- Data source: request shape + success parse + at least one transport error.
- Repository: 1 happy + 1 test per `Failure` subtype it can emit.
- Don't chase coverage on generated `freezed`/`json_serializable` code — exclude it; assert behavior, not boilerplate.
- The overall coverage gate (lcov %, CI job) belongs to **skill 20** — here you just make the data-layer suite green and exhaustive.

---

## Templates

| File | Use |
|---|---|
| [`templates/fixtures/example_list.json`](templates/fixtures/example_list.json) | sample list payload matching the skill-11 DTO |
| [`templates/fixtures/example_item.json`](templates/fixtures/example_item.json) | sample single-item payload |
| [`templates/fixture_reader.dart`](templates/fixture_reader.dart) | load a fixture file's contents in tests |
| [`templates/data_source_test.dart`](templates/data_source_test.dart) | mock `Dio`, parse a fixture, assert path/query + DTO |
| [`templates/repository_test.dart`](templates/repository_test.dart) | happy path + every `DioException`→`Failure` path |

Copy fixtures into the app's `test/fixtures/`, the reader and tests into `test/` mirroring the source path (CONVENTIONS §3). Adjust the DTO/entity/repository names to match what skill 11 generated for the feature.

---

## Workflow

1. Confirm skill 11 produced a data source + repository + DTO for the feature, and skill 15's `Failure`/`Result` exists. If not, run those first.
2. Capture or copy real responses into `test/fixtures/<feature>/`.
3. Write data-source tests (request shape + parse) using mocked `Dio`.
4. Write repository tests: 1 happy path + 1 per `Failure` subtype, driving each via a thrown `DioException`.
5. If skill 14 added retry/timeout/cancellation, add policy tests (call counts, bounded give-up).
6. Run `flutter test test/...`. Green + every error branch covered = gate met.

**Hand off to skill 20** (Testing), which folds this suite into the full unit/widget/golden/integration run and enforces the coverage gate in CI.

See [`../../references/CONVENTIONS.md`](../../references/CONVENTIONS.md) for the stack and the `Result`/`Failure` contract.
