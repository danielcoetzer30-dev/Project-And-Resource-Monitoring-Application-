import '../../data/project_repository.dart';
import '../../models/health_state.dart';

/// Turns the current snapshot into the text the assistant is given as context.
///
/// This is the only thing in the app that sends project data to a third party,
/// so what it includes matters more than how it reads.
///
/// **It can only emit squad-level data, because that is all the snapshot
/// holds.** No individual is identified anywhere in the app's domain model —
/// `Squad` carries a headcount and no member list — so there is no per-person
/// field here to accidentally include. The guarantee is structural rather than
/// a rule this file has to remember, which is the point of having built it
/// that way. `snapshot_brief_test.dart` asserts it anyway.
///
/// Kept compact deliberately: this is re-sent with every question, so every
/// line costs tokens on each turn.
abstract final class SnapshotBrief {
  static String build(HealthSnapshot snapshot) {
    final buffer = StringBuffer();

    buffer.writeln('# Current project health data');
    buffer.writeln();
    buffer.writeln(
      'Captured ${_timestamp(snapshot.capturedAt)}'
      '${snapshot.isLive ? '' : ' (cached — the device was offline)'}.',
    );
    buffer.writeln();

    _writeGrid(buffer, snapshot);
    _writeProjects(buffer, snapshot);
    _writeSquads(buffer, snapshot);
    _writeSignals(buffer, snapshot);

    return buffer.toString();
  }

  static void _writeGrid(StringBuffer b, HealthSnapshot s) {
    b.writeln('## Load-shedding');
    if (!s.grid.isShedding) {
      b.writeln('Grid stable, no stage in effect.');
    } else {
      b.writeln('Stage ${s.grid.stage} in effect.');
      final start = s.grid.nextOutageStart;
      final end = s.grid.nextOutageEnd;
      if (start != null && end != null) {
        b.writeln('Next outage ${_clock(start)}–${_clock(end)}.');
      }
    }
    b.writeln(
      '${s.grid.hoursLostThisWeek} hours lost across the team this week. '
      'These hours are excluded from every health score — a team is never '
      'marked down for a power failure.',
    );
    b.writeln();
  }

  static void _writeProjects(StringBuffer b, HealthSnapshot s) {
    b.writeln('## Projects (${s.projects.length})');
    if (s.projects.isEmpty) {
      b.writeln('None.');
      b.writeln();
      return;
    }

    for (final p in s.worstFirst) {
      b.writeln();
      b.writeln('### ${p.name} — ${p.client}');
      b.writeln('- Health score: ${p.score.round()}/100 (${p.state.label})');
      b.writeln('- Squad: ${p.squadId}');
      b.writeln('- Budget consumed: ${(p.budgetBurn * 100).round()}%');
      b.writeln('- Days of schedule left: ${p.scheduleDaysRemaining}');
      b.writeln(
        '- Hours lost to outages: ${p.loadSheddingHoursLost}'
        ' (reported, not deducted)',
      );
      b.writeln('- Open signals: ${p.openSignals}');

      if (p.factors.isNotEmpty) {
        b.writeln('- Score breakdown:');
        for (final f in p.factors) {
          b.writeln(
            '  - ${f.name}: ${f.value.round()}/100, '
            'weight ${(f.weight * 100).round()}%. ${f.detail}',
          );
        }
      }

      if (p.seam.isNotEmpty) {
        b.writeln('- Recent trend: ${_trend(p.seam.map((x) => x.state))}');
      }
    }
    b.writeln();
  }

  static void _writeSquads(StringBuffer b, HealthSnapshot s) {
    b.writeln('## Squads (${s.squads.length})');
    if (s.squads.isEmpty) {
      b.writeln('None.');
      b.writeln();
      return;
    }
    for (final q in s.squads) {
      b.writeln(
        '- ${q.name} (id ${q.id}): ${q.headcount} people, '
        '${q.capacityLabel} of capacity committed, '
        '${q.activeProjectCount} active '
        '${q.activeProjectCount == 1 ? 'project' : 'projects'}, '
        'velocity ${_percent(q.velocityTrend)} against its own baseline '
        '(${q.state.label})',
      );
    }
    b.writeln();
  }

  static void _writeSignals(StringBuffer b, HealthSnapshot s) {
    b.writeln('## Signals (${s.signals.length})');
    if (s.signals.isEmpty) {
      b.writeln('None raised.');
      return;
    }

    final sorted = [...s.signals]
      ..sort((a, b2) => b2.severity.severity.compareTo(a.severity.severity));

    for (final sig in sorted) {
      b.writeln();
      b.writeln('- [${sig.severity.label}] ${sig.title}');
      b.writeln('  Why: ${sig.because}');
      if (sig.infrastructureRelated) {
        b.writeln(
          '  This is infrastructure, not delivery. No score was reduced.',
        );
      }
    }
  }

  /// Compresses a run of daily states into something short and readable,
  /// e.g. "On track for 9 days, then Watch for 6, now Critical for 7".
  static String _trend(Iterable<HealthState> states) {
    final list = states.toList();
    if (list.isEmpty) return 'no history';

    final runs = <(HealthState, int)>[];
    var current = list.first;
    var count = 0;

    for (final state in list) {
      if (state == current) {
        count++;
      } else {
        runs.add((current, count));
        current = state;
        count = 1;
      }
    }
    runs.add((current, count));

    // Only the last few runs matter for answering "how long has this been bad".
    final tail = runs.length > 4 ? runs.sublist(runs.length - 4) : runs;
    return tail
        .map((r) => '${r.$1.label} for ${r.$2} ${r.$2 == 1 ? 'day' : 'days'}')
        .join(', then ');
  }

  static String _percent(double fraction) {
    final value = (fraction * 100).round();
    return value >= 0 ? '+$value%' : '$value%';
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static String _timestamp(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} ${_clock(t)}';
}
