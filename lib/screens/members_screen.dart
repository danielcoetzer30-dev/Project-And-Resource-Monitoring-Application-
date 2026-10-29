import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member_search.dart';
import '../models/squad.dart';
import '../models/squad_member.dart';
import '../state/auth_notifier.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/panel.dart';
import 'squads_screen.dart' show MemberRow;

/// Everyone in the organisation, with the squad each person is on.
///
/// Reads the same roster the Squads screen shows, so the two can never
/// disagree, and moving somebody uses the same control with the same rank
/// rule ([SquadRosterRules]). Opens on everyone, or on one squad when reached
/// from it.
///
/// A roster, not a scoreboard: a name, a role and a squad, and nothing about
/// what anyone does. See [SquadPlacement].
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, this.squadId});

  /// The squad to show first. Null shows everyone.
  final String? squadId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

/// Filter values: a squad id, [_all], or [_none] for people on no squad.
const _all = '*';
const _none = '';

class _MembersScreenState extends ConsumerState<MembersScreen> {
  late String _filter = widget.squadId ?? _all;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(squadRosterProvider);
    final actor = ref.watch(currentUserProvider);
    final squads =
        ref.watch(healthSnapshotProvider).value?.squads ?? const <Squad>[];
    final squadNames = {for (final s in squads) s.id: s.name};

    final everyone = <({RosterMember member, String squadId})>[
      for (final entry in roster.bySquad.entries)
        for (final member in entry.value)
          (member: member, squadId: entry.key),
      for (final member in roster.unplaced) (member: member, squadId: _none),
    ]..sort(
      (a, b) => a.member.displayName.toLowerCase().compareTo(
        b.member.displayName.toLowerCase(),
      ),
    );

    final visible = [
      for (final e in everyone)
        if ((_filter == _all || e.squadId == _filter) &&
            MemberSearch.matches(
              name: e.member.displayName,
              role: e.member.role.label,
              query: _query,
            ))
          e,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'A roster, not a scoreboard',
            child: Text(
              'This lists who is in the organisation and which squad they are '
              'on. Nothing about what anyone does is stored, scored or shown '
              'here.',
              style: AppType.bodyMuted,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              ChoiceChip(
                label: const Text('All members'),
                selected: _filter == _all,
                onSelected: (_) => setState(() => _filter = _all),
              ),
              for (final squad in squads)
                ChoiceChip(
                  label: Text(squad.name),
                  selected: _filter == squad.id,
                  onSelected: (_) => setState(() => _filter = squad.id),
                ),
              ChoiceChip(
                label: const Text('No squad'),
                selected: _filter == _none,
                onSelected: (_) => setState(() => _filter = _none),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            style: AppType.body,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name or role. * and ? work as wildcards.',
              hintStyle: AppType.bodyMuted,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
              filled: true,
              fillColor: Tokens.seam,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Tokens.space3,
                vertical: Tokens.space3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                borderSide: const BorderSide(color: Tokens.rule),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                borderSide: const BorderSide(color: Tokens.rule),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                borderSide: const BorderSide(color: Tokens.beacon, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: Tokens.space3),
          Text(
            visible.length == 1
                ? '1 member listed'
                : '${visible.length} members listed',
            style: AppType.data,
          ),
          const SizedBox(height: Tokens.space2),
          if (visible.isEmpty)
            Panel(
              child: Text(
                _query.trim().isEmpty
                    ? 'Nobody here yet. People appear when they sign in.'
                    : 'No one matches "${_query.trim()}". Try fewer letters, '
                          'or use * for any run of letters.',
                style: AppType.bodyMuted,
              ),
            )
          else
            Panel(
              child: Column(
                children: [
                  for (final e in visible)
                    MemberRow(
                      key: ValueKey(e.member.userId),
                      member: e.member,
                      actor: actor,
                      currentSquadId: e.squadId,
                      squads: squads,
                      subtitle: e.squadId.isEmpty
                          ? 'No squad'
                          : (squadNames[e.squadId] ?? 'Unknown squad'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
