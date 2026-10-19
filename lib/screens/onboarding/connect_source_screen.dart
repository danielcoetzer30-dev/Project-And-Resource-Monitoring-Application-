import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../models/ingestion_source.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

/// Link a repository or issue tracker.
///
/// The one screen in the app where typing things in is legitimate. Everywhere
/// else, asking a developer to enter data would repeat the failure the
/// research identifies in existing tools; here it is a one-off setup step that
/// buys permanent passive capture.
class ConnectSourceScreen extends ConsumerStatefulWidget {
  const ConnectSourceScreen({super.key});

  @override
  ConsumerState<ConnectSourceScreen> createState() =>
      _ConnectSourceScreenState();
}

class _ConnectSourceScreenState extends ConsumerState<ConnectSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _remoteId = TextEditingController();

  SourceType _type = SourceType.github;
  bool _busy = false;

  /// Why the last attempt was refused, or null if it was not.
  Failure? _failure;

  @override
  void dispose() {
    _label.dispose();
    _remoteId.dispose();
    super.dispose();
  }

  String get _remoteHint => switch (_type) {
    SourceType.github || SourceType.gitlab => 'owner/repository',
    SourceType.clickUp => 'ClickUp list id',
    SourceType.jira => 'Project key, e.g. KEEL',
  };

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    // Id left empty so the repository allocates one. A millisecond timestamp
    // would collide between two people adding a source at the same moment,
    // and the loser's source would silently replace the winner's.
    final source = IngestionSource(
      id: '',
      type: _type,
      label: _label.text.trim(),
      remoteId: _remoteId.text.trim(),
      orgId: '',
      isEnabled: true,
    );

    try {
      await ref.read(sourceRepositoryProvider).connect(source);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _failure = failureFromException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect a source')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          Panel(
            title: 'What gets read',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Only metadata: when commits happened, when tasks opened and '
                  'closed, and how big they were.',
                  style: AppType.bodyMuted,
                ),
                const SizedBox(height: Tokens.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Tokens.slate,
                    ),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        'Code, commit messages and issue descriptions are never '
                        'requested. Activity is aggregated to squad level before '
                        'it is stored, so no individual is ever measured.',
                        style: AppType.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text('SOURCE TYPE', style: AppType.label),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            children: [
              for (final type in SourceType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                  labelStyle: AppType.body.copyWith(
                    color: _type == type ? Tokens.shaft : Tokens.chalk,
                  ),
                  selectedColor: Tokens.beacon,
                  backgroundColor: Tokens.seam,
                  side: const BorderSide(color: Tokens.rule),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _Input(
                  controller: _label,
                  label: 'Name',
                  hint: 'What your team calls it',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
                ),
                const SizedBox(height: Tokens.space4),
                _Input(
                  controller: _remoteId,
                  label: 'Identifier',
                  hint: _remoteHint,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the identifier'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          // No token field, deliberately. The credential belongs to the
          // ingestion job, and `firestore.rules` refuses any source document
          // carrying one — so a box here would take a secret, fail to store
          // it, and leave somebody believing they had set it up.
          Panel(
            title: 'Where the token goes',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.key_outlined, size: 18, color: Tokens.slate),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Text(
                    'This records what to read, never how to sign in. The '
                    'read-only token lives with the ingestion job, so it is '
                    'not on anybody\'s phone and cannot be read back out of '
                    'the app.',
                    style: AppType.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_failure != null) ...[
            const SizedBox(height: Tokens.space4),
            Container(
              padding: const EdgeInsets.all(Tokens.space3),
              decoration: BoxDecoration(
                color: Tokens.flare.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
                border: Border.all(color: Tokens.flare.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Tokens.flare,
                  ),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Text(
                      _failure!.message,
                      style: AppType.body.copyWith(color: Tokens.flare),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Tokens.space5),
          FilledButton(
            onPressed: _busy ? null : _connect,
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.beacon,
              foregroundColor: Tokens.shaft,
              padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
            ),
            child: Text(
              'Connect source',
              style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
            ),
          ),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.label),
        const SizedBox(height: Tokens.space2),
        TextFormField(
          controller: controller,
          validator: validator,
          style: AppType.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppType.bodyMuted,
            filled: true,
            fillColor: Tokens.seam,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Tokens.space3,
              vertical: Tokens.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.beacon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
