import '../theme/health_state_style.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/project_repository.dart';
import '../models/project.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/panel.dart';

/// The week ahead, and what the grid has cost it.
///
/// This is the screen no competing tool has. Its job is to hold infrastructure
/// loss separate from delivery performance, so a team is never scored down for
/// a national power failure — the hours are stated plainly and then excluded
/// from every score.
///
/// Horizons are deliberately short. A bar is the same linear projection the
/// forecast panel uses, and a straight line stops being honest past a week.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  /// Days from today. 0 is today, which is what the panel below opens on.
  int _selectedDayIndex = 0;

  static const _daysShown = 7;

  @override
  Widget build(BuildContext context) {
    // One column per day, sized to the viewport so the week never scrolls
    // sideways and a bar can never run off the edge.
    final dayColumnWidth = MediaQuery.of(context).size.width / _daysShown;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TimelineArea(
          snapshot: widget.snapshot,
          dayWidth: dayColumnWidth,
          selectedDayIndex: _selectedDayIndex,
          onSelectDay: (index) => setState(() => _selectedDayIndex = index),
        ),
        const Divider(height: Tokens.hairline, color: Tokens.rule),
        _DayDetails(snapshot: widget.snapshot, dayIndex: _selectedDayIndex),
      ],
    );
  }
}

/// The week strip and the project bars drawn against it.
class _TimelineArea extends StatelessWidget {
  const _TimelineArea({
    required this.snapshot,
    required this.dayWidth,
    required this.selectedDayIndex,
    required this.onSelectDay,
  });

  final HealthSnapshot snapshot;
  final double dayWidth;
  final int selectedDayIndex;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final projects = snapshot.worstFirst;

    return Stack(
      children: [
        // Day gridlines, behind everything, so a bar's length can be read off
        // the week rather than guessed at.
        Positioned.fill(
          child: Row(
            children: List.generate(
              _WeekScreenState._daysShown,
              (_) => Container(
                width: dayWidth,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Tokens.rule,
                      width: Tokens.hairline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeekStrip(
              snapshot: snapshot,
              dayWidth: dayWidth,
              selectedDayIndex: selectedDayIndex,
              onSelectDay: onSelectDay,
            ),
            const SizedBox(height: Tokens.space3),
            if (projects.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Text(
                  'No projects to lay out yet. Connect a source and this week '
                  'fills itself in.',
                  style: AppType.bodyMuted,
                ),
              )
            else
              for (final project in projects)
                _ProjectBar(project: project, dayWidth: dayWidth),
            const SizedBox(height: Tokens.space5),
          ],
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.snapshot,
    required this.dayWidth,
    required this.selectedDayIndex,
    required this.onSelectDay,
  });

  final HealthSnapshot snapshot;
  final double dayWidth;
  final int selectedDayIndex;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toLocal();

    return Row(
      children: List.generate(_WeekScreenState._daysShown, (index) {
        final day = today.add(Duration(days: index));
        final isSelected = selectedDayIndex == index;

        // Only today's outage state is known. Load shedding is scheduled in
        // blocks that change, so the rest of the week is left unmarked rather
        // than guessed at.
        final isShedding = index == 0 && snapshot.grid.isShedding;

        return Semantics(
          button: true,
          selected: isSelected,
          label:
              DateFormat('EEEE d MMMM').format(day) +
              (isShedding ? ', load shedding' : ''),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onSelectDay(index),
            child: Container(
              width: dayWidth,
              padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
              decoration: BoxDecoration(
                color: isSelected ? Tokens.seam : null,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Tokens.radiusMd),
                ),
              ),
              child: Column(
                children: [
                  // Holds its space whether or not it is shown, so the strip
                  // does not shift height as the grid changes.
                  Icon(
                    Icons.bolt,
                    size: 14,
                    color: isShedding ? Tokens.brass : Colors.transparent,
                  ),
                  const SizedBox(height: Tokens.space1),
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: AppType.label.copyWith(
                      color: isSelected ? Tokens.chalk : Tokens.slate,
                    ),
                  ),
                  const SizedBox(height: Tokens.space2),
                  Container(
                    padding: const EdgeInsets.all(Tokens.space2),
                    decoration: BoxDecoration(
                      color: isSelected ? Tokens.beacon : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      DateFormat('d').format(day),
                      style: AppType.dataStrong.copyWith(
                        color: isSelected ? Tokens.shaft : Tokens.slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// One project as a bar across the days it still has scheduled.
///
/// Colour comes from [HealthState] rather than from anything local, so a
/// project cannot read as green here and amber on the Health tab. The label
/// states the state in words for the same reason the status pill does.
class _ProjectBar extends StatelessWidget {
  const _ProjectBar({required this.project, required this.dayWidth});

  final Project project;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    // At least one day so a project that is out of schedule is still visible,
    // and never more than the week on screen.
    final days = min(
      max(1, project.scheduleDaysRemaining),
      _WeekScreenState._daysShown,
    );
    final colour = project.state.color;
    final runsPastTheWeek =
        project.scheduleDaysRemaining > _WeekScreenState._daysShown;

    return Semantics(
      label:
          '${project.name}, ${project.state.label}, '
          '${project.scheduleDaysRemaining} days of schedule left',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Tokens.space2),
        child: Row(
          children: [
            Container(
              width: (days * dayWidth) - Tokens.space2,
              margin: const EdgeInsets.symmetric(horizontal: Tokens.space1),
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space3,
                vertical: Tokens.space3,
              ),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.15),
                border: Border.all(color: colour.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyStrong.copyWith(color: colour),
                    ),
                  ),
                  // Says the bar was cut off, rather than letting it read as a
                  // project that finishes on Sunday.
                  if (runsPastTheWeek)
                    Icon(
                      Icons.more_horiz,
                      size: 14,
                      color: colour.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chosen day, and what the grid has taken from the week.
///
/// The hours panel is the point of the screen: it states the loss in full and
/// then says plainly that it is excluded from every score. A team reading this
/// should never wonder whether an outage counted against them.
class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.snapshot, required this.dayIndex});

  final HealthSnapshot snapshot;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().toLocal().add(Duration(days: dayIndex));
    final isToday = dayIndex == 0;
    final grid = snapshot.grid;
    final isShedding = isToday && grid.isShedding;

    final hoursLost = snapshot.projects.fold<double>(
      0,
      (sum, project) => sum + project.loadSheddingHoursLost,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space4,
        Tokens.space4,
        Tokens.space7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, d MMMM').format(day), style: AppType.heading),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'The grid',
            // Only stated for today. A schedule that changes daily cannot
            // honestly be labelled for Thursday.
            trailing: isToday
                ? Text(
                    grid.isShedding ? 'SHEDDING' : 'STABLE',
                    style: AppType.label.copyWith(
                      color: grid.isShedding ? Tokens.brass : Tokens.jade,
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isShedding ? Icons.bolt : Icons.check_circle_outline,
                      size: 18,
                      color: isShedding ? Tokens.brass : Tokens.jade,
                    ),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Text(
                        switch ((isToday, grid.isShedding)) {
                          (true, true) => 'Stage ${grid.stage}',
                          (true, false) => 'No shedding',
                          // Schedules change, so a future day is honestly
                          // unknown rather than quietly assumed to be clear.
                          _ => 'Outages are only known for today',
                        },
                        style: AppType.metricSmall.copyWith(
                          color: isShedding ? Tokens.brass : Tokens.jade,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isToday && grid.nextOutageStart != null) ...[
                  const SizedBox(height: Tokens.space3),
                  Text(
                    'Next outage ${_time(grid.nextOutageStart!)}'
                    '–${_time(grid.nextOutageEnd!)}',
                    style: AppType.body,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Hours lost this week',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(hoursLost.toStringAsFixed(1), style: AppType.metric),
                    const SizedBox(width: Tokens.space2),
                    Text('hours', style: AppType.bodyMuted),
                  ],
                ),
                const SizedBox(height: Tokens.space4),
                for (final project in snapshot.projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: AppType.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Tokens.space3),
                        Text(
                          '${project.loadSheddingHoursLost.toStringAsFixed(1)}h',
                          style: AppType.dataStrong,
                        ),
                      ],
                    ),
                  ),
                const Divider(height: Tokens.space4),
                const SizedBox(height: Tokens.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Tokens.slate,
                    ),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Text(
                        'These hours are excluded from every health score. '
                        'Outages change what a team could deliver, not how '
                        'well they delivered it.',
                        style: AppType.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Squad capacity',
            child: snapshot.squads.isEmpty
                ? Text('No squads reported yet.', style: AppType.bodyMuted)
                : Column(
                    children: [
                      for (final squad in snapshot.squads)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Tokens.space3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(squad.name, style: AppType.body),
                              ),
                              Text(
                                squad.capacityLabel,
                                style: AppType.dataStrong.copyWith(
                                  color: squad.capacityUsed > 1
                                      ? Tokens.ember
                                      : Tokens.chalk,
                                ),
                              ),
                              if (squad.capacityUsed > 1) ...[
                                const SizedBox(width: Tokens.space2),
                                Text('over', style: AppType.label),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
