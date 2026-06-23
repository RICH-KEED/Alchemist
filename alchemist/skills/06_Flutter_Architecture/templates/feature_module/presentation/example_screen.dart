import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/example_controller.dart';
import '../domain/example_entity.dart';

// Shared state widgets live in `lib/core/widgets/` (stage 16): LoadingView,
// EmptyView, ErrorView. They are stubbed inline below until stage 16 lands.

/// Screen for the `example` feature.
///
/// Watches [exampleControllerProvider] and renders **all four** async states:
/// loading · data · empty · error (CONVENTIONS §4). No business logic here —
/// it only reads state and calls controller methods.
class ExampleScreen extends ConsumerWidget {
  /// Creates the [ExampleScreen].
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exampleControllerProvider);
    final controller = ref.read(exampleControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Examples')),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.when(
          // 1. loading
          loading: () => const Center(child: CircularProgressIndicator()),
          // 2. error
          error: (error, _) => _ErrorView(
            message: '$error',
            onRetry: controller.refresh,
          ),
          // 3 & 4. data vs. empty
          data: (examples) => examples.isEmpty
              ? const _EmptyView()
              : _ExampleList(
                  examples: examples,
                  onToggleFavorite: controller.toggleFavorite,
                ),
        ),
      ),
    );
  }
}

class _ExampleList extends StatelessWidget {
  const _ExampleList({
    required this.examples,
    required this.onToggleFavorite,
  });

  final List<ExampleEntity> examples;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: examples.length,
      itemBuilder: (context, index) {
        final example = examples[index];
        return ListTile(
          key: ValueKey(example.id),
          title: Text(example.title),
          trailing: IconButton(
            icon: Icon(
              example.isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            onPressed: () => onToggleFavorite(example.id),
          ),
        );
      },
    );
  }
}

// TODO(stage-16): replace with core/widgets/EmptyView.
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No examples yet.'));
  }
}

// TODO(stage-16): replace with core/widgets/ErrorView.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
