import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: KeelApp()));
}

class KeelApp extends StatelessWidget {
  const KeelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // The shell is the entry point rather than AuthGate: Firestore rules are
      // closed and the prototype runs on seeded data, so gating it behind a
      // sign-in that cannot yet succeed would make it undemonstrable. Stage 1
      // switches this to AuthGate.
      initialRoute: Routes.shell,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
