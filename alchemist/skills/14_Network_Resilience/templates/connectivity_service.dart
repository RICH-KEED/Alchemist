// core/network/connectivity_service.dart
//
// Online/offline awareness for the whole app, exposed as Riverpod providers.
// Owned by skill 14 (Network_Resilience).
//
// pubspec.yaml:
//   dependencies:
//     connectivity_plus: ^6.0.0
//     riverpod_annotation: ^2.3.0
//   dev_dependencies:
//     riverpod_generator: ^2.4.0
//     build_runner: ^2.4.0
//
// Then: `dart run build_runner build -d` to generate connectivity_service.g.dart
//
// IMPORTANT: connectivity_plus reports the TRANSPORT (wifi/mobile/none), not
// real reachability — a captive portal or dead backend still reads as "online".
// Treat this as a fast hint; the retry interceptor and circuit breaker remain
// the source of truth for whether requests actually succeed.
//
// See ../../../references/CONVENTIONS.md §6 (Riverpod contract).

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Coarse connectivity state for the UI and resilience layer.
enum ConnectivityStatus {
  /// At least one transport (wifi/mobile/ethernet/vpn) is available.
  online,

  /// No transport at all — definitely offline.
  offline;

  bool get isOnline => this == ConnectivityStatus.online;
  bool get isOffline => this == ConnectivityStatus.offline;
}

/// Maps a raw list of [ConnectivityResult]s to our coarse status.
/// `connectivity_plus` v6 returns a LIST (a device can have several transports).
ConnectivityStatus statusFromResults(List<ConnectivityResult> results) {
  final hasTransport = results.any((r) => r != ConnectivityResult.none);
  return hasTransport ? ConnectivityStatus.online : ConnectivityStatus.offline;
}

/// Wraps the `connectivity_plus` singleton so it can be overridden in tests.
@riverpod
Connectivity connectivity(ConnectivityRef ref) => Connectivity();

/// A live stream of [ConnectivityStatus]. Emits on every transport change.
///
/// Watch this anywhere you need to react to going offline/online:
/// ```dart
/// final status = ref.watch(connectivityStatusProvider).valueOrNull;
/// if (status?.isOffline ?? false) showOfflineBanner();
/// ```
@riverpod
Stream<ConnectivityStatus> connectivityStatus(
  ConnectivityStatusRef ref,
) async* {
  final connectivity = ref.watch(connectivityProvider);

  // Seed with the current value so consumers don't wait for the first change.
  yield statusFromResults(await connectivity.checkConnectivity());

  yield* connectivity.onConnectivityChanged.map(statusFromResults);
}

/// A synchronous-ish boolean view, defaulting to `true` (optimistic) until the
/// first reading arrives — avoids flashing an offline banner on cold start.
@riverpod
bool isOnline(IsOnlineRef ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(
    data: (s) => s.isOnline,
    orElse: () => true,
  );
}
