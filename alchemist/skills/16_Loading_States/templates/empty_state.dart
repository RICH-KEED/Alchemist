// core/widgets/empty_state.dart
//
// A reusable, helpful empty state. Owned by skill 16 (Loading_States).
// An empty state is NOT an error — it is a successful result with zero items.
// A premium empty state explains the cause and offers a primary action; it is
// never a blank screen.

import 'package:flutter/material.dart';

// Skill 04 design tokens. `context.tokens` resolves AppTokens from the theme.
//   import 'package:app/app/theme/app_tokens.dart';

/// A friendly empty placeholder: illustration/icon slot, title, supporting
/// message, and an optional primary action (CTA).
///
/// ```dart
/// EmptyState(
///   icon: Icons.search_off,
///   title: 'No results',
///   message: 'Try a different search term.',
///   actionLabel: 'Clear filters',
///   onAction: controller.clearFilters,
/// );
/// ```
///
/// Provide [illustration] for a bespoke graphic (preferred for marquee
/// surfaces); otherwise [icon] renders a tonal circle badge.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon,
    this.illustration,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  }) : assert(
          icon != null || illustration != null,
          'Provide an icon or an illustration so the state is not blank.',
        );

  final String title;

  /// One short sentence: the cause and/or what the user can do next.
  final String? message;

  /// Icon rendered inside a tonal circle when no [illustration] is given.
  final IconData? icon;

  /// A bespoke graphic that replaces the icon badge.
  final Widget? illustration;

  /// Primary CTA label. With [onAction], renders a [FilledButton].
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional lower-emphasis action (renders a [TextButton]).
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Spacing values mirror AppTokens (sm 8, md 16, lg 24, xl 32). Swap for
    // `context.tokens.spacing.*` in the host app.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 44,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
