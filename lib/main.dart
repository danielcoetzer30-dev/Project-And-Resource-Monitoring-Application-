import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'models/preferences.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'state/providers.dart';
import 'theme/accessibility_scope.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: PrahmApp()));
}

class PrahmApp extends ConsumerWidget {
  const PrahmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selected individually, so changing a date format rebuilds neither the
    // theme nor this widget.
    final density = ref.watch(preferencesProvider.select((p) => p.density));
    final textSize = ref.watch(preferencesProvider.select((p) => p.textSize));
    final boldText = ref.watch(preferencesProvider.select((p) => p.boldText));

    return MaterialApp(
      title: 'PRAHM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark.copyWith(
        visualDensity: density == UiDensity.compact
            ? VisualDensity.compact
            : VisualDensity.standard,
      ),
      builder: (context, child) => accessibilityScope(
        context,
        textSize: textSize,
        boldText: boldText,
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: Routes.shell,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
