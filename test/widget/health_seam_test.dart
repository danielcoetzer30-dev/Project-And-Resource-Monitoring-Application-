import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/health_state.dart';
import 'package:keel/widgets/health_seam.dart';

/// Wraps a widget in the minimum needed to pump it.
Widget host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

List<SeamSegment> segments(int count, {Set<int> flags = const {}}) {
  return [
    for (var i = 0; i < count; i++)
      SeamSegment(
        state: HealthState.values[i % HealthState.values.length],
        periodLabel: 'Day $i',
        flagged: flags.contains(i),
      ),
  ];
}

void main() {
  testWidgets('renders nothing but a message when there is no history', (
    tester,
  ) async {
    await tester.pumpWidget(host(const HealthSeam(segments: [])));

    expect(find.text('No history yet'), findsOneWidget);
  });

  testWidgets('renders at a range of segment counts without overflowing', (
    tester,
  ) async {
    // One segment, a normal month, and far more than fits — the painter
    // collapses gaps below about 3px per segment, and this is what proves it
    // does not blow up instead.
    for (final count in [1, 30, 200]) {
      await tester.pumpWidget(host(HealthSeam(segments: segments(count))));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '$count segments threw');
      expect(find.byType(HealthSeam), findsOneWidget);
    }
  });

  testWidgets('shows dated axis labels only when asked', (tester) async {
    await tester.pumpWidget(host(HealthSeam(segments: segments(5))));
    expect(find.text('Day 0'), findsNothing);

    await tester.pumpWidget(
      host(HealthSeam(segments: segments(5), showAxis: true)),
    );
    expect(find.text('Day 0'), findsOneWidget);
    expect(find.text('Day 4'), findsOneWidget);
  });

  testWidgets('describes the trend to screen readers as a sentence', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      host(HealthSeam(segments: segments(10, flags: {2, 7}))),
    );

    // A screen reader should hear a summary, not a list of ten colours.
    expect(
      find.bySemanticsLabel(RegExp(r'Health history over 10 periods')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'2 risk flags')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('says so when there are no risk flags', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(host(HealthSeam(segments: segments(5))));

    expect(find.bySemanticsLabel(RegExp(r'No risk flags')), findsOneWidget);

    handle.dispose();
  });
}
