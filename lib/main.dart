import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'data/mock_project_repository.dart';
import 'data/project_repository.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KeelApp());
}

class KeelApp extends StatefulWidget {
  const KeelApp({super.key});

  @override
  State<KeelApp> createState() => _KeelAppState();
}

class _KeelAppState extends State<KeelApp> {
  // The one place the concrete implementation is named. Swapping in real
  // ingestion later is a change to this line and nothing else.
  final ProjectRepository _repository = MockProjectRepository();

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AppShell(repository: _repository),
    );
  }
}