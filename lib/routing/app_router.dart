import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/signal.dart';
import '../models/squad.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/onboarding/connect_source_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/settings/api_key_screen.dart';
import '../screens/settings/ingestion_sources_screen.dart';
import '../screens/settings/scoring_weights_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/signal_thread_screen.dart';
import '../state/auth_notifier.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'routes.dart';

/// Arguments for the project detail route.
class ProjectDetailArgs {
  const ProjectDetailArgs({required this.project, this.squad});

  final Project project;
  final Squad? squad;
}

/// Arguments for the signal discussion route.
class SignalThreadArgs {
  const SignalThreadArgs({required this.signal, required this.projectName});

  final Signal signal;
  final String projectName;
}

/// Builds routes by name.
///
/// Named routes rather than a router package: the app has ten destinations
/// and no deep-linking requirement yet, so a third dependency would be
/// machinery without a job.
abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.shell:
        // The gate, not the shell: data is scoped to the signed-in user's
        // organisation, so there is nothing to render before sign-in.
        return _page(const AuthGate(), settings);

      case Routes.signIn:
        return _page(const SignInScreen(), settings);

      case Routes.projectDetail:
        final args = settings.arguments;
        if (args is! ProjectDetailArgs) return _missingArguments(settings);
        return _page(
          ProjectDetailScreen(project: args.project, squad: args.squad),
          settings,
        );

      case Routes.signalThread:
        final args = settings.arguments;
        if (args is! SignalThreadArgs) return _missingArguments(settings);
        return _page(
          SignalThreadScreen(
            signal: args.signal,
            projectName: args.projectName,
          ),
          settings,
        );

      case Routes.settings:
        return _page(const SettingsScreen(), settings);

      case Routes.scoringWeights:
        return _page(const ScoringWeightsScreen(), settings);

      case Routes.ingestionSources:
        return _page(const IngestionSourcesScreen(), settings);

      case Routes.connectSource:
        // Connecting a source changes what the whole organisation is measured
        // on, so it is gated here rather than only hidden in the UI.
        return _guardedPage(
          settings: settings,
          builder: (ref) {
            final user = ref.watch(currentUserProvider);
            if (user?.canChangeSettings ?? false) {
              return const ConnectSourceScreen();
            }
            return const _NotPermitted(
              message:
                  'Only leads and managers can connect a data source. '
                  'Ask whoever set up your organisation.',
            );
          },
        );

      case Routes.apiKey:
        return _page(const ApiKeyScreen(), settings);

      default:
        return null;
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) =>
      MaterialPageRoute<dynamic>(builder: (_) => child, settings: s);

  /// A route whose screen depends on who is signed in. Wrapping in [Consumer]
  /// keeps the check in the router, so a screen cannot be reached by a second
  /// path that forgot to ask.
  static MaterialPageRoute<dynamic> _guardedPage({
    required Widget Function(WidgetRef ref) builder,
    required RouteSettings settings,
  }) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (context) =>
          Consumer(builder: (context, ref, _) => builder(ref)),
    );
  }

  /// A route reached without what it needs. Says so plainly rather than
  /// crashing on a null.
  static MaterialPageRoute<dynamic> _missingArguments(RouteSettings s) {
    return MaterialPageRoute<dynamic>(
      settings: s,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Not available')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'That screen was opened without a project to show. '
              'Go back and pick one from the dashboard.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of a screen the signed-in person is not allowed to open.
/// Says who can, so it is a next step rather than a dead end.
class _NotPermitted extends StatelessWidget {
  const _NotPermitted({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not available to you')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, size: 24, color: Tokens.slate),
              const SizedBox(height: Tokens.space3),
              Text(
                'You do not have permission for this',
                style: AppType.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Tokens.space2),
              Text(
                message,
                style: AppType.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
