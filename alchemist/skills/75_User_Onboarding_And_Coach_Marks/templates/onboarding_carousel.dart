// lib/features/onboarding/presentation/onboarding_carousel.dart
//
// Auto-generated first-run intro flow (Responsibility 2): a tokenized PageView
// of value-prop pages with skip / next / done. Shown only when
// `!isCompleted(OnboardingIds.intro)` — wire that gate into the stage-07 router
// redirect so it precedes the home route on first launch (Responsibility 5).
//
// No external onboarding package: pages inherit the design system directly.
// (`introduction_screen` is a heavier alternative if you want its extras.)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/coach_marks/onboarding_state.dart';

// import '../../../app/theme/app_tokens.dart'; // AppTokens (stage 04)
const double _gap = 8;

/// One intro page. Generate these from `docs/PRD.md` value props +
/// `docs/UX.md` (Responsibility 1). Use illustrations from stage 10 assets.
class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon; // swap for Image.asset(Assets.images.*) from stage 10
}

const _defaultPages = <OnboardingPageData>[
  OnboardingPageData(
    title: 'Welcome',
    body: 'Everything you need, in one place.',
    icon: Icons.waving_hand_outlined,
  ),
  OnboardingPageData(
    title: 'Stay organized',
    body: 'Create, track, and never lose what matters.',
    icon: Icons.checklist_rounded,
  ),
  OnboardingPageData(
    title: 'Get started',
    body: 'It only takes a few seconds.',
    icon: Icons.rocket_launch_outlined,
  ),
];

/// First-run intro carousel. On completion (Done or Skip) it persists
/// [OnboardingIds.intro] and calls [onDone] (e.g. `context.go('/home')`).
class OnboardingCarousel extends ConsumerStatefulWidget {
  const OnboardingCarousel({
    required this.onDone,
    this.pages = _defaultPages,
    super.key,
  });

  final VoidCallback onDone;
  final List<OnboardingPageData> pages;

  @override
  ConsumerState<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends ConsumerState<OnboardingCarousel> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == widget.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(onboardingControllerProvider.notifier)
        .complete(OnboardingIds.intro);
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 240), // AppTokens.motion.medium
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish, // Skip == complete (no nagging)
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = widget.pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(_gap * 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 96, color: theme.colorScheme.primary),
                        const SizedBox(height: _gap * 4),
                        Text(page.title,
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: _gap * 1.5),
                        Text(page.body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            _Dots(count: widget.pages.length, index: _index),
            Padding(
              padding: const EdgeInsets.all(_gap * 2),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: _gap / 2),
          width: active ? _gap * 3 : _gap,
          height: _gap,
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(_gap),
          ),
        );
      }),
    );
  }
}
