// Before/after accessibility fixes (skill 45).
//
// Each pair shows a common Flutter a11y bug (✗ Before) and the fix (✓ After).
// All snippets compile under flutter_test/material. Copy the *After* shape.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. Labeling an icon button
// ✗ Before: an IconButton with no label reads as nothing / just "button".
// ✓ After:  tooltip doubles as the semantic label (and gives a 48dp target).
// ─────────────────────────────────────────────────────────────────────────────

class DeleteButtonBefore extends StatelessWidget {
  const DeleteButtonBefore({super.key, required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.delete), onPressed: onDelete);
  }
}

class DeleteButtonAfter extends StatelessWidget {
  const DeleteButtonAfter({super.key, required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Delete item',
      icon: const Icon(Icons.delete),
      onPressed: onDelete,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Merging a composite tile
// ✗ Before: avatar + name + role read as three separate nodes (stutter).
// ✓ After:  MergeSemantics reads them as one node; decorative icon excluded.
// ─────────────────────────────────────────────────────────────────────────────

class ContactTileBefore extends StatelessWidget {
  const ContactTileBefore({super.key, required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(child: Icon(Icons.person)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(name), Text(role)],
        ),
      ],
    );
  }
}

class ContactTileAfter extends StatelessWidget {
  const ContactTileAfter({super.key, required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          // Avatar icon is decorative — hide it so the reader isn't noisy.
          const ExcludeSemantics(
            child: CircleAvatar(child: Icon(Icons.person)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(name), Text(role)],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Giving a custom tappable a button role + 48dp target
// ✗ Before: a bare GestureDetector has no semantic role and a tiny hit area.
// ✓ After:  InkWell + Semantics(button) + a 48dp minimum constraint.
// ─────────────────────────────────────────────────────────────────────────────

class ChipTapBefore extends StatelessWidget {
  const ChipTapBefore({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label),
      ),
    );
  }
}

class ChipTapAfter extends StatelessWidget {
  const ChipTapAfter({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Contrast-safe caption color
// ✗ Before: opacity-faded onSurface (~3:1) fails AA body contrast (4.5:1).
// ✓ After:  the onSurfaceVariant role is designed to meet contrast.
// ─────────────────────────────────────────────────────────────────────────────

class CaptionBefore extends StatelessWidget {
  const CaptionBefore({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.38)),
    );
  }
}

class CaptionAfter extends StatelessWidget {
  const CaptionAfter({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall!
          .copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Announcing an invisible state change + labeling a spinner
// ✗ Before: a silent spinner; a state change a screen-reader user never hears.
// ✓ After:  labeled spinner + SemanticsService.announce on the change.
// ─────────────────────────────────────────────────────────────────────────────

class LoadingBefore extends StatelessWidget {
  const LoadingBefore({super.key});

  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}

class LoadingAfter extends StatelessWidget {
  const LoadingAfter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Semantics(
      label: 'Loading',
      liveRegion: true,
      child: CircularProgressIndicator(),
    );
  }
}

/// Call after a non-visible change so TalkBack speaks it.
void announceDeleted(BuildContext context) {
  SemanticsService.announce('Item deleted', Directionality.of(context));
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Respecting reduce-motion
// ✗ Before: animation always runs, ignoring "Remove animations".
// ✓ After:  collapse to Duration.zero when the user disabled animations.
// ─────────────────────────────────────────────────────────────────────────────

class FadeInBefore extends StatelessWidget {
  const FadeInBefore({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 400),
      child: child,
    );
  }
}

class FadeInAfter extends StatelessWidget {
  const FadeInAfter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Fixing focus order
// ✗ Before: a FAB declared first in the tree is read before the list.
// ✓ After:  ordinal sort keys force the visual top-to-bottom reading order.
// ─────────────────────────────────────────────────────────────────────────────

class OrderedActions extends StatelessWidget {
  const OrderedActions({super.key, required this.primary, required this.fab});
  final Widget primary;
  final Widget fab;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Semantics(sortKey: const OrdinalSortKey(0), child: primary),
        Semantics(sortKey: const OrdinalSortKey(1), child: fab),
      ],
    );
  }
}
