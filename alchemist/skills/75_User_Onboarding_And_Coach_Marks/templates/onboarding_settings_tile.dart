// lib/features/settings/presentation/onboarding_settings_tile.dart
//
// Replay-from-Settings entry (Responsibility 6). Lets the user re-watch the
// intro and/or coach-mark tours. Clearing a flag makes its surface eligible to
// auto-start again the next time it's visited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/coach_marks/onboarding_state.dart';

/// A Settings tile that replays onboarding. Drop into your Settings list.
class OnboardingSettingsTile extends ConsumerWidget {
  const OnboardingSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.school_outlined),
      title: const Text('Show app tour again'),
      subtitle: const Text('Replay onboarding and feature tips'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _confirmAndReplay(context, ref),
    );
  }

  Future<void> _confirmAndReplay(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<_ReplayChoice>(
      context: context,
      builder: (context) => const _ReplaySheet(),
    );
    if (choice == null) return;

    final controller = ref.read(onboardingControllerProvider.notifier);
    switch (choice) {
      case _ReplayChoice.intro:
        await controller.reset(OnboardingIds.intro);
      case _ReplayChoice.tours:
        await controller.reset(OnboardingIds.homeTour);
        await controller.reset(OnboardingIds.checkoutTour);
      case _ReplayChoice.everything:
        await controller.resetAll();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Onboarding will show again next time.')),
    );
    // Tip: if you want it immediately, navigate to the intro/home route here.
  }
}

enum _ReplayChoice { intro, tours, everything }

class _ReplaySheet extends StatelessWidget {
  const _ReplaySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Replay…'), dense: true),
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Welcome intro'),
            onTap: () => Navigator.pop(context, _ReplayChoice.intro),
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Feature tips (coach marks)'),
            onTap: () => Navigator.pop(context, _ReplayChoice.tours),
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Everything'),
            onTap: () => Navigator.pop(context, _ReplayChoice.everything),
          ),
        ],
      ),
    );
  }
}
