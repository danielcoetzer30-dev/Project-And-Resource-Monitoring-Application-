import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/exceptions.dart';
import '../data/project_repository.dart';
import '../models/app_user.dart';
import '../models/squad.dart';
import '../models/squad_member.dart';
import '../state/auth_notifier.dart';
import '../state/providers.dart';
import '../theme/health_state_style.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/panel.dart';
import '../widgets/status_pill.dart';

/// Capacity per squad, and who is on each one.
///
/// The capacity half of this screen is unchanged in intent: "the Platform
/// squad is over capacity" is answerable and "who on the Platform squad is
/// slowest" is not, because no per-person figure is stored anywhere to answer
/// it with.
///
/// The roster half was added on 21 October 2026 and does change what this
/// screen exposes. A list of names beside a squad's metrics narrows those
/// metrics to the people named, which is the trade the team made deliberately
/// and which `lib/models/squad_member.dart` sets out in full. Nothing here
/// shows a figure against a person.
class SquadsScreen extends ConsumerWidget {
  const SquadsScreen({super.key, required this.snapshot});

  /// Handed in by the shell, which already holds the only subscription to the
  /// project stream. Watching it a second time here would be a second
  /// listener for the same data.
  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(squadRosterProvider);
    final user = ref.watch(currentUserProvider);

    final squads = snapshot.squads;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      children: [
        Panel(
          title: 'How this is measured',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Tokens.slate),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  'Every figure on this screen is a squad total. No activity '
                  'is stored, scored or shown against a person — not to you, '
                  'and not to management. The rosters below say who is on a '
                  'squad, never what they did.',
                  style: AppType.bodyMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        for (final squad in squads) ...[
          _SquadCard(squad: squad, roster: roster, actor: user, squads: squads),
          const SizedBox(height: Tokens.space3),
        ],
        if (roster.unplaced.isNotEmpty) ...[
          const SizedBox(height: Tokens.space2),
          _UnplacedCard(roster: roster, actor: user, squads: squads),
        ],
      ],
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({
    required this.squad,
    required this.roster,
    required this.actor,
    required this.squads,
  });

  final Squad squad;
  final SquadRoster roster;
  final AppUser? actor;

  /// Every squad, so the move sheet has somewhere to offer.
  final List<Squad> squads;

  @override
  Widget build(BuildContext context) {
    final trendDown = squad.velocityTrend < 0;
    final members = roster.of(squad.id);

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.seam,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(squad.name, style: AppType.heading),
                    const SizedBox(height: Tokens.space1),
                    Text(
                      '${squad.headcount} people  ·  '
                      '${squad.activeProjectCount} active '
                      '${squad.activeProjectCount == 1 ? 'project' : 'projects'}',
                      style: AppType.bodyMuted,
                    ),
                  ],
                ),
              ),
              StatusPill(state: squad.state),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          _CapacityBar(squad: squad),
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              Text(
                squad.capacityLabel,
                style: AppType.metricSmall.copyWith(color: squad.state.color),
              ),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text('of capacity committed', style: AppType.bodyMuted),
              ),
              Icon(
                trendDown ? Icons.south_east : Icons.north_east,
                size: 14,
                color: trendDown ? Tokens.ember : Tokens.jade,
              ),
              const SizedBox(width: Tokens.space1),
              Text(
                '${(squad.velocityTrend * 100).round().abs()}%',
                style: AppType.dataStrong,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          const Divider(height: 1, color: Tokens.rule),
          const SizedBox(height: Tokens.space3),
          _Roster(squad: squad, members: members, actor: actor, squads: squads),
        ],
      ),
    );
  }
}

/// Who is on one squad.
///
/// The headcount above is stated by the team and the roster is maintained by
/// hand, so the two can disagree. Said plainly rather than reconciled
/// silently: a squad of five with three people on the roster means somebody
/// has not been placed, and capacity is being measured against a roster figure
/// that no longer matches who is actually there.
class _Roster extends ConsumerWidget {
  const _Roster({
    required this.squad,
    required this.members,
    required this.actor,
    required this.squads,
  });

  final Squad squad;
  final List<RosterMember> members;
  final AppUser? actor;
  final List<Squad> squads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mismatch = members.isNotEmpty && members.length != squad.headcount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('ON THIS SQUAD', style: AppType.label),
              ),
            ),
            Text('${members.length}', style: AppType.dataStrong),
          ],
        ),
        if (mismatch) ...[
          const SizedBox(height: Tokens.space2),
          Text(
            'The stated headcount is ${squad.headcount}. Capacity is '
            'measured against the hours the squad stated, not against this '
            'list.',
            style: AppType.data.copyWith(color: Tokens.brass),
          ),
        ],
        const SizedBox(height: Tokens.space2),
        if (members.isEmpty)
          Text('Nobody placed on this squad yet.', style: AppType.bodyMuted)
        else
          for (final member in members)
            _MemberRow(
              member: member,
              actor: actor,
              currentSquadId: squad.id,
              squads: squads,
            ),
      ],
    );
  }
}

/// The people in the organisation who are on no squad.
///
/// Shown rather than hidden. Somebody who joined and was never placed is the
/// thing this screen is for: their work is being read from a source and
/// attributed to whichever squad that source belongs to, and nothing on the
/// dashboard says they are unaccounted for.
class _UnplacedCard extends StatelessWidget {
  const _UnplacedCard({
    required this.roster,
    required this.actor,
    required this.squads,
  });

  final SquadRoster roster;
  final AppUser? actor;
  final List<Squad> squads;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'On no squad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'In the organisation, not placed on a squad. Their work still '
            'reaches a score through whichever source reads it; this list is '
            'only about who has been accounted for.',
            style: AppType.bodyMuted,
          ),
          const SizedBox(height: Tokens.space3),
          for (final member in roster.unplaced)
            _MemberRow(
              member: member,
              actor: actor,
              currentSquadId: '',
              squads: squads,
            ),
        ],
      ),
    );
  }
}

/// One person on a roster: a name, a role, and a way to move them.
///
/// The move control appears only when the signed-in person strictly outranks
/// this one, which is [SquadRosterRules]. The rules refuse it again, so what
/// is hidden here is a door that is already locked.
class _MemberRow extends ConsumerWidget {
  const _MemberRow({
    required this.member,
    required this.actor,
    required this.currentSquadId,
    required this.squads,
  });

  final RosterMember member;
  final AppUser? actor;

  /// The squad they are on now, or empty. Marked in the move sheet so a tap
  /// that changes nothing is obvious before it is made.
  final String currentSquadId;

  final List<Squad> squads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canMove =
        actor != null &&
        SquadRosterRules.canPlace(
          actorRole: actor!.role,
          targetRole: member.role,
        );

    return Semantics(
      label: '${member.displayName}, ${member.role.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Tokens.slate),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text(
                member.displayName,
                style: AppType.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Tokens.space2),
            Text(
              member.role.label.toUpperCase(),
              style: AppType.label.copyWith(fontSize: 10, color: Tokens.slate),
            ),
            if (canMove) ...[
              const SizedBox(width: Tokens.space2),
              IconButton(
                onPressed: () => _openMoveSheet(context, ref),
                icon: const Icon(Icons.swap_horiz, size: 18),
                color: Tokens.beacon,
                visualDensity: VisualDensity.compact,
                tooltip: 'Move ${member.displayName} to another squad',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMoveSheet(BuildContext context, WidgetRef ref) async {
    // Held before the sheet opens. Afterwards this row may be gone — a move
    // rebuilds the roster it is part of — and the result still has to be
    // reportable.
    final messenger = ScaffoldMessenger.of(context);

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Tokens.seam,
      builder: (context) => _MoveSheet(
        member: member,
        squads: squads,
        currentSquadId: currentSquadId,
      ),
    );

    if (chosen == null || chosen == currentSquadId) return;

    try {
      await ref
          .read(squadRosterRepositoryProvider)
          .place(userId: member.userId, squadId: chosen);

      final where = chosen.isEmpty
          ? 'no squad'
          : squads
                .firstWhere(
                  (s) => s.id == chosen,
                  orElse: () => _unknownSquad(chosen),
                )
                .name;

      messenger.showSnackBar(
        SnackBar(content: Text('${member.displayName} is now on $where.')),
      );
    } on AppException catch (error) {
      // Said rather than swallowed: a refused move has to be visible, or
      // somebody carries on believing the roster says what they meant.
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  static Squad _unknownSquad(String id) => Squad(
    id: id,
    name: id,
    headcount: 0,
    capacityUsed: 0,
    activeProjectCount: 0,
    velocityTrend: 0,
  );
}

/// Where to move somebody. Squads, plus taking them off every squad.
class _MoveSheet extends StatelessWidget {
  const _MoveSheet({
    required this.member,
    required this.squads,
    required this.currentSquadId,
  });

  final RosterMember member;
  final List<Squad> squads;
  final String currentSquadId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              Tokens.space2,
              Tokens.space4,
              Tokens.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move ${member.displayName}', style: AppType.heading),
                const SizedBox(height: Tokens.space1),
                Text(
                  'Somebody is on one squad at a time, so this replaces '
                  'wherever they are now.',
                  style: AppType.bodyMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.rule),
          for (final squad in squads)
            _MoveOption(
              label: squad.name,
              icon: Icons.group_work_outlined,
              isCurrent: squad.id == currentSquadId,
              onTap: () => Navigator.of(context).pop(squad.id),
            ),
          _MoveOption(
            label: 'No squad',
            icon: Icons.person_outline,
            isCurrent: currentSquadId.isEmpty,
            onTap: () => Navigator.of(context).pop(''),
          ),
        ],
      ),
    );
  }
}

class _MoveOption extends StatelessWidget {
  const _MoveOption({
    required this.label,
    required this.icon,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Tokens.slate),
            const SizedBox(width: Tokens.space3),
            Expanded(child: Text(label, style: AppType.bodyStrong)),
            if (isCurrent)
              Text(
                'ON NOW',
                style: AppType.label.copyWith(
                  fontSize: 10,
                  color: Tokens.beacon,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context) {
    // The bar is scaled so 100% sits at a fixed marker rather than at the far
    // edge — over-allocation has to be visible as overflow, not just as a
    // full bar.
    const fullMark = 0.72;
    final fill = (squad.capacityUsed * fullMark).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Tokens.shaft,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(color: Tokens.rule),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    color: squad.state.color,
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  ),
                ),
              ),
              Positioned(
                left: width * fullMark,
                top: -2,
                bottom: -2,
                child: Container(width: 1.5, color: Tokens.chalk),
              ),
            ],
          ),
        );
      },
    );
  }
}
