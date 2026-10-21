import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../models/ingestion_source.dart';
import '../../models/squad.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/labelled_field.dart';
import '../../widgets/panel.dart';

/// Link a repository or issue tracker, or change one that is already linked.
///
/// The one screen in the app where typing things in is legitimate. Everywhere
/// else, asking a developer to enter data would repeat the failure the
/// research identifies in existing tools; here it is a one-off setup step that
/// buys permanent passive capture.
///
/// One screen for adding and editing, the same arrangement the project form
/// uses: the fields, the validation and the squad choice are identical, and
/// two screens would be two places for the same rules to drift apart. What
/// differs is the title, the button, and that editing can also pause or
/// remove.
class ConnectSourceScreen extends ConsumerStatefulWidget {
  const ConnectSourceScreen({super.key, this.sourceId});

  /// Null to add a new source. An id to change that one.
  final String? sourceId;

  @override
  ConsumerState<ConnectSourceScreen> createState() =>
      _ConnectSourceScreenState();
}

class _ConnectSourceScreenState extends ConsumerState<ConnectSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _remoteId = TextEditingController();

  SourceType _type = SourceType.github;
  String _squadId = '';
  bool _busy = false;

  /// True once the existing source has been read into the fields.
  ///
  /// The list arrives from a stream, so the first build may not have it yet.
  /// This makes the prefill happen exactly once: doing it on every build would
  /// overwrite what somebody is in the middle of typing each time the stream
  /// ticked.
  bool _loaded = false;

  /// Whether the source is being read at all. Editable while editing, so a
  /// tracker that has gone quiet can be paused rather than deleted.
  bool _isEnabled = true;

  bool get _isEditing => widget.sourceId != null;

  /// Why the last attempt was refused, or null if it was not.
  Failure? _failure;

  @override
  void dispose() {
    _label.dispose();
    _remoteId.dispose();
    super.dispose();
  }

  /// Copies [source] into the form, once.
  void _prefill(IngestionSource source) {
    _loaded = true;
    _label.text = source.label;
    _remoteId.text = source.remoteId;
    _type = source.type;
    _squadId = source.squadId;
    _isEnabled = source.isEnabled;
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

    // Adding leaves the id empty so the repository allocates one: a
    // millisecond timestamp would collide between two people adding a source
    // at the same moment, and the loser's source would silently replace the
    // winner's. Editing keeps the id, so connect() replaces that document
    // rather than making a second one.
    final source = IngestionSource(
      id: widget.sourceId ?? '',
      type: _type,
      label: _label.text.trim(),
      remoteId: _remoteId.text.trim(),
      orgId: '',
      isEnabled: _isEnabled,
      squadId: _squadId,
    );

    try {
      await ref.read(sourceRepositoryProvider).connect(source);
      if (!mounted) return;
      _report(_isEditing ? 'Source updated.' : 'Source connected.');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _failure = failureFromException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Forgets the source entirely, after asking.
  ///
  /// A real delete, unlike archiving a project: a source is a statement about
  /// where to read from, and removing one does not remove any history it
  /// produced. The scores it contributed to stay where they are, which is why
  /// this can be a delete and a project cannot.
  Future<void> _remove() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove this source?',
      body:
          'Ingestion stops reading ${_label.text.trim()} and forgets it. The '
          'scores it has already contributed to stay as they are. To stop '
          'reading it without forgetting it, pause it instead.',
      confirmLabel: 'Remove',
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref.read(sourceRepositoryProvider).disconnect(widget.sourceId!);
      if (!mounted) return;
      _report('Source removed.');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _failure = failureFromException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // A source has to belong to a squad, so the squads have to be on screen.
    final squads =
        ref.watch(healthSnapshotProvider).value?.squads ?? const <Squad>[];

    // Editing reads the source out of the same stream the list screen uses,
    // so a change made elsewhere is already reflected before the form opens.
    if (_isEditing && !_loaded) {
      final existing = ref
          .watch(sourcesProvider)
          .value
          ?.where((s) => s.id == widget.sourceId)
          .firstOrNull;

      if (existing == null) {
        // Either the list has not arrived yet or the source was removed from
        // another device. A spinner covers the first; the second resolves
        // itself when the person goes back to a list that no longer has it.
        return Scaffold(
          appBar: AppBar(title: const Text('Source')),
          body: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Tokens.slate,
              ),
            ),
          ),
        );
      }

      _prefill(existing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit source' : 'Connect a source'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _busy ? null : _remove,
              icon: const Icon(Icons.delete_outline),
              color: Tokens.flare,
              tooltip: 'Remove this source',
            ),
        ],
      ),
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
          Text('SQUAD', style: AppType.label),
          const SizedBox(height: Tokens.space1),
          Text(
            'Whose work this source represents. Everything it reports counts '
            'towards this squad, which is how activity is aggregated without '
            'anybody being named.',
            style: AppType.bodyMuted,
          ),
          const SizedBox(height: Tokens.space2),
          if (squads.isEmpty)
            Text(
              'No squads yet. A source needs one, because activity that '
              'belongs to no squad cannot be aggregated into anything.',
              style: AppType.body.copyWith(color: Tokens.brass),
            )
          else
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final squad in squads)
                  ChoiceChip(
                    label: Text(squad.name),
                    selected: _squadId == squad.id,
                    onSelected: (_) => setState(() => _squadId = squad.id),
                    labelStyle: AppType.body.copyWith(
                      color: _squadId == squad.id ? Tokens.shaft : Tokens.chalk,
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
                LabelledField(
                  controller: _label,
                  label: 'Name',
                  hint: 'What your team calls it',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
                ),
                const SizedBox(height: Tokens.space4),
                LabelledField(
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
          // Pausing is offered only while editing: a source being added is
          // being added because somebody wants it read.
          if (_isEditing) ...[
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Reading',
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEnabled ? 'Being read' : 'Paused',
                          style: AppType.bodyStrong,
                        ),
                        const SizedBox(height: Tokens.space1),
                        Text(
                          'Pausing keeps the source, so a tracker that has '
                          'gone quiet for a fortnight does not have to be '
                          'retyped afterwards.',
                          style: AppType.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _isEnabled = value),
                    activeThumbColor: Tokens.beacon,
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
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Tokens.shaft,
                    ),
                  )
                : Text(
                    _isEditing ? 'Save changes' : 'Connect source',
                    style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
                  ),
          ),
        ],
      ),
    );
  }
}
