import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../models/squad.dart';
import '../models/squad_rules.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/labelled_field.dart';

/// Create a squad, or rename one.
///
/// Two inputs, both things a person states: a name and, optionally, how many
/// people the squad says it has. Capacity, velocity and active projects are
/// measured by ingestion and are not asked for here.
///
/// Reached only by leads and managers; the route checks, and the repository
/// and security rules check again.
class SquadFormScreen extends ConsumerStatefulWidget {
  const SquadFormScreen({super.key, this.squad});

  /// The squad being edited. Null creates a new one.
  final Squad? squad;

  @override
  ConsumerState<SquadFormScreen> createState() => _SquadFormScreenState();
}

class _SquadFormScreenState extends ConsumerState<SquadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.squad?.name);
  late final _headcount = TextEditingController(
    text: widget.squad == null || widget.squad!.headcount == 0
        ? ''
        : '${widget.squad!.headcount}',
  );

  bool get _isEditing => widget.squad != null;

  @override
  void dispose() {
    _name.dispose();
    _headcount.dispose();
    super.dispose();
  }

  void _report(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureFromException(error).message)),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(squadRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final name = _name.text.trim();
    final headcount = SquadRules.parseHeadcount(_headcount.text);

    // Not awaited, as everywhere in the app: offline, Firestore holds the
    // change and the screen must not wait on a confirmation that may be hours
    // away. A refusal arrives as a message on the screen behind.
    try {
      if (_isEditing) {
        unawaited(
          repository
              .update(
                squadId: widget.squad!.id,
                name: name,
                headcount: headcount,
              )
              .catchError((Object e) => _report(messenger, e)),
        );
      } else {
        final created = repository.create(name: name, headcount: headcount);
        unawaited(created.saved.catchError((Object e) => _report(messenger, e)));
      }
    } catch (error) {
      _report(messenger, error);
      return;
    }

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final squads =
        ref.watch(healthSnapshotProvider).value?.squads ?? const <Squad>[];

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit squad' : 'New squad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  LabelledField(
                    controller: _name,
                    label: 'Squad name',
                    hint: 'For example, Platform',
                    autofocus: !_isEditing,
                    validator: (v) {
                      final problem = SquadRules.nameProblem(v ?? '');
                      if (problem != null) return problem;
                      if (SquadRules.nameTaken(
                        v ?? '',
                        squads,
                        exceptId: widget.squad?.id,
                      )) {
                        return 'A squad with this name already exists';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Tokens.space4),
                  LabelledField(
                    controller: _headcount,
                    label: 'Stated headcount (optional)',
                    hint: 'How many people the squad says it has',
                    keyboardType: TextInputType.number,
                    validator: (v) => SquadRules.headcountProblem(v ?? ''),
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space3),
            Text(
              'Capacity, velocity and active projects are measured, not '
              'entered. A new squad starts at zero and fills in as data '
              'arrives.',
              style: AppType.bodyMuted,
            ),
            const SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.beacon,
                foregroundColor: Tokens.shaft,
                padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
              child: Text(
                _isEditing ? 'Save changes' : 'Create squad',
                style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
