import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/squad.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/onboarding/connect_source_screen.dart';
import '../screens/project_detail_screen.dart';
import '../screens/settings/api_key_screen.dart';
import '../screens/settings/ingestion_sources_screen.dart';
import '../screens/settings/scoring_weights_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'routes.dart';

/// Arguments for the project detail route.
class ProjectDetailArgs {
  const ProjectDetailArgs({required this.project, this.squad});

  final Project project;
  final Squad? squad;
}

/// Builds routes by name.
///
/// Named routes rather than a router package: the app has eight destinations
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

      case Routes.settings:
        return _page(const SettingsScreen(), settings);

      case Routes.scoringWeights:
        return _page(const ScoringWeightsScreen(), settings);

      case Routes.ingestionSources:
        return _page(const IngestionSourcesScreen(), settings);

      case Routes.connectSource:
        return _page(const ConnectSourceScreen(), settings);

      case Routes.apiKey:
        return _page(const ApiKeyScreen(), settings);

      default:
        return null;
    }
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) =>
      MaterialPageRoute<dynamic>(builder: (_) => child, settings: s);

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
