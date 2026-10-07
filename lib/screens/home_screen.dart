import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One place the home screen can send the user.
///
/// The shell owns this list and builds its navigation bar from the same
/// entries, so a section's name and icon are written once and cannot drift
/// apart between the bar and the home screen.
class HomeDestination {
  const HomeDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.selectedIcon,
  });

  final String title;

  /// One plain sentence on what the user will find there.
  final String description;

  final IconData icon;
  final IconData selectedIcon;
}

/// Where the app opens: a neutral starting point, not a data view.
///
/// It deliberately shows no scores, counts, states or signals. Someone opening
/// the app should choose what to look at, rather than have a health reading
/// land on them first. That also means this screen needs no data, so it renders
/// instantly, with or without a connection.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.destinations,
    required this.onOpen,
  });

  final List<HomeDestination> destinations;

  /// Called with the index into [destinations] that the user chose.
  final ValueChanged<int> onOpen;

  /// A single readable column. Four tiles do not need the width of a desktop
  /// window, and a stretched tile is harder to scan.
  static const _maxWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Tokens.space4),
                Text('Where would you like to start?', style: AppType.display),
                const SizedBox(height: Tokens.space2),
                Text(
                  'Pick a view to get started. Nothing asks you to type in '
                  'progress: it all comes from the tools your squads already '
                  'use.',
                  style: AppType.bodyMuted,
                ),
                const SizedBox(height: Tokens.space5),
                for (var i = 0; i < destinations.length; i++) ...[
                  if (i > 0) const SizedBox(height: Tokens.space3),
                  _DestinationTile(
                    destination: destinations[i],
                    onTap: () => onOpen(i),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.onTap});

  final HomeDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${destination.title}. ${destination.description}',
      child: Material(
        color: Tokens.seam,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: const BorderSide(color: Tokens.rule, width: Tokens.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(
              children: [
                // Slate, not a signal colour: these icons name a place, they
                // do not report a state.
                Icon(destination.icon, size: 24, color: Tokens.slate),
                const SizedBox(width: Tokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(destination.title, style: AppType.heading),
                      const SizedBox(height: Tokens.space1),
                      Text(destination.description, style: AppType.bodyMuted),
                    ],
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                // Beacon is the app's "tappable" colour.
                const Icon(Icons.chevron_right, size: 24, color: Tokens.beacon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
