import 'package:flutter/material.dart';

import '../../models/ingestion_source.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

/// Link a repository or issue tracker.
///
/// The one screen in the app where typing things in is legitimate. Everywhere
/// else, asking a developer to enter data would repeat the failure the
/// research identifies in existing tools; here it is a one-off setup step that
/// buys permanent passive capture.
class ConnectSourceScreen extends StatefulWidget {
  const ConnectSourceScreen({super.key, this.onConnect});

  /// Called with the new source and its token. The token is handed straight to
  /// the caller and never held on this screen's state beyond the call.
  final Future<void> Function(IngestionSource source, String token)? onConnect;

  @override
  State<ConnectSourceScreen> createState() => _ConnectSourceScreenState();
}

class _ConnectSourceScreenState extends State<ConnectSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _remoteId = TextEditingController();
  final _token = TextEditingController();

  SourceType _type = SourceType.github;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _remoteId.dispose();
    _token.dispose();
    super.dispose();
  }

  String get _remoteHint => switch (_type) {
    SourceType.github || SourceType.gitlab => 'owner/repository',
    SourceType.clickUp => 'ClickUp list id',
    SourceType.jira => 'Project key, e.g. KEEL',
  };

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final source = IngestionSource(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      label: _label.text.trim(),
      remoteId: _remoteId.text.trim(),
      orgId: '',
      isEnabled: true,
    );

    try {
      await widget.onConnect?.call(source, _token.text.trim());
      if (mounted) Navigator.of(context).maybePop();
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
                const SizedBox(height: Tokens.space4),
                _Input(
                  controller: _token,
                  label: 'Access token',
                  hint: 'Read-only token',
                  obscure: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'A token is needed to read this source'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space3),
          Text(
            'Use a read-only token. The app never writes to your repository or '
            'tracker.',
            style: AppType.bodyMuted,
          ),
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
    this.obscure = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
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
          obscureText: obscure,
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
