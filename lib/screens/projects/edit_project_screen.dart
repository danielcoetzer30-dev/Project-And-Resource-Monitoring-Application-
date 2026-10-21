import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/utils/date_format.dart';
import '../../models/project_plan.dart';
import '../../models/squad.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/panel.dart';

/// Add a project, or change one.
///
/// The second screen in the app where typing is legitimate, and for the same
/// reason as the first: this is one-off setup that buys permanent passive
/// capture. A name, a client, a squad, a budget and a schedule are things no
/// commit log knows, and none of them says how the work is going.
///
/// What is saved here is a plan. Ingestion reads it and produces the project
/// document, which is why a new project appears on the dashboard on the next
/// run rather than instantly — honest, because until something has been read
/// there is nothing to say about its health.
class EditProjectScreen extends ConsumerStatefulWidget {
  const EditProjectScreen({super.key, this.projectId});

  /// Null when adding.
  final String? projectId;

  @override
  ConsumerState<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends ConsumerState<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _client = TextEditingController();
  final _budgetTotal = TextEditingController();
  final _budgetSpent = TextEditingController();
  final _weeklyHours = TextEditingController();

  String _squadId = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _archived = false;

  bool _busy = false;
  bool _loaded = false;
  Failure? _failure;

  bool get _isNew => widget.projectId == null;

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _budgetTotal.dispose();
    _budgetSpent.dispose();
    _weeklyHours.dispose();
    super.dispose();
  }

  /// Fills the form once, from the stored plan.
  ///
  /// Only once: re-filling on every rebuild would overwrite what somebody is
  /// part way through typing each time the stream emits.
  void _fillOnce(ProjectPlan plan) {
    if (_loaded) return;
    _loaded = true;

    _name.text = plan.name;
    _client.text = plan.client;
    _budgetTotal.text = plan.budgetTotal == 0 ? '' : _plain(plan.budgetTotal);
    _budgetSpent.text = plan.budgetSpent == 0 ? '' : _plain(plan.budgetSpent);
    _weeklyHours.text = plan.weeklyHours == 0 ? '' : _plain(plan.weeklyHours);
    _squadId = plan.squadId;
    _startDate = plan.startDate;
    _endDate = plan.endDate;
    _archived = plan.isArchived;
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  ProjectPlan _asPlan() => ProjectPlan(
    projectId: widget.projectId ?? '',
    name: _name.text.trim(),
    client: _client.text.trim(),
    squadId: _squadId,
    budgetTotal: double.tryParse(_budgetTotal.text.trim()) ?? 0,
    budgetSpent: double.tryParse(_budgetSpent.text.trim()) ?? 0,
    startDate: _startDate,
    endDate: _endDate,
    weeklyHours: double.tryParse(_weeklyHours.text.trim()) ?? 0,
    isArchived: _archived,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref.read(projectPlanRepositoryProvider).save(_asPlan());
      if (!mounted) return;
      // Says what will happen next as well as that it worked: a project that
      // does not appear on the dashboard straight away looks like a failed
      // save unless somebody is told why.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.projectId == null
                ? 'Project saved. It appears on the dashboard after the next '
                      'ingestion run.'
                : 'Changes saved.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _failure = failureFromException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Archives the project, or brings it back, after asking.
  ///
  /// Archiving is this module's delete: there is deliberately no permanent
  /// one, because removing a failing project is the simplest way to make it
  /// stop looking bad, and the history is the research record. It is still
  /// hard to undo from the dashboard's point of view — the project disappears
  /// from every screen and stops being scored — so it asks first.
  ///
  /// Bringing one back is not destructive and is not confirmed.
  Future<void> _setArchived(bool archived) async {
    final id = widget.projectId;
    if (id == null) return;

    if (archived) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Archive this project?',
        body:
            'It comes off the dashboard and stops being scored. Nothing is '
            'deleted: the plan, the history and the signals are kept, and you '
            'can bring it back from this screen at any time.',
        confirmLabel: 'Archive',
      );

      if (!confirmed || !mounted) return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref
          .read(projectPlanRepositoryProvider)
          .setArchived(projectId: id, archived: archived);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archived ? 'Project archived.' : 'Project brought back.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _failure = failureFromException(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial =
        (isStart ? _startDate : _endDate) ?? DateTime.now().toLocal();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 10),
    );

    if (picked == null) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final squads =
        ref.watch(healthSnapshotProvider).value?.squads ?? const <Squad>[];

    if (!_isNew) {
      final plan = ref.watch(projectPlanProvider(widget.projectId!)).value;
      if (plan != null) _fillOnce(plan);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add a project' : 'Edit project'),
        leading: const BackButton(color: Tokens.slate),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space2,
            Tokens.space4,
            Tokens.space7,
          ),
          children: [
            Panel(
              title: 'What this is',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    controller: _name,
                    label: 'Project name',
                    hint: 'Ledger rebuild',
                    validator: (v) => ProjectPlanRules.nameProblem(v ?? ''),
                  ),
                  const SizedBox(height: Tokens.space4),
                  _Field(
                    controller: _client,
                    label: 'Client',
                    hint: 'Optional',
                    validator: (v) => ProjectPlanRules.clientProblem(v ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Who is doing it',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity arrives attributed to a squad, so a project '
                    'without one is never scored.',
                    style: AppType.bodyMuted,
                  ),
                  const SizedBox(height: Tokens.space3),
                  if (squads.isEmpty)
                    Text(
                      'No squads yet.',
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
                            onSelected: (_) =>
                                setState(() => _squadId = squad.id),
                            labelStyle: AppType.body.copyWith(
                              color: _squadId == squad.id
                                  ? Tokens.shaft
                                  : Tokens.chalk,
                            ),
                            selectedColor: Tokens.beacon,
                            backgroundColor: Tokens.seam,
                            side: const BorderSide(color: Tokens.rule),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Panel(
              title: 'Budget and schedule',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'None of this can flatter a score. Spending more always '
                    'lowers it, and a longer schedule lowers the burn rate '
                    'while lengthening the delivery forecast.',
                    style: AppType.bodyMuted,
                  ),
                  const SizedBox(height: Tokens.space4),
                  _Field(
                    controller: _budgetTotal,
                    label: 'Budget',
                    hint: 'Total, in whatever you count in',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: Tokens.space4),
                  _Field(
                    controller: _budgetSpent,
                    label: 'Spent so far',
                    hint: 'Updated when your finance figures are',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: Tokens.space4),
                  _DateRow(
                    label: 'Starts',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: Tokens.space3),
                  _DateRow(
                    label: 'Ends',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                  const SizedBox(height: Tokens.space4),
                  _Field(
                    controller: _weeklyHours,
                    label: 'Hours a week',
                    hint: 'Across the whole squad, not per person',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    'This has to match what the squad actually puts in, or '
                    'the idle-time indicator becomes a fact about this number '
                    'rather than about the work.',
                    style: AppType.bodyMuted,
                  ),
                ],
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: Tokens.space4),
              _Refused(failure: _failure!),
            ],
            const SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.beacon,
                foregroundColor: Tokens.shaft,
                padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
              child: Text(
                _busy ? 'Saving…' : (_isNew ? 'Add project' : 'Save changes'),
                style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
              ),
            ),
            if (!_isNew) ...[
              const SizedBox(height: Tokens.space5),
              const Divider(height: Tokens.hairline),
              const SizedBox(height: Tokens.space4),
              Text(
                _archived
                    ? 'This project is archived. Bringing it back puts it on '
                          'the dashboard and starts it being scored again.'
                    : 'Archiving takes a project off the dashboard and stops '
                          'it being scored. The history is kept — there is no '
                          'delete, because a project that went wrong is the '
                          'one most worth being able to look back at.',
                style: AppType.bodyMuted,
              ),
              const SizedBox(height: Tokens.space3),
              TextButton(
                onPressed: _busy ? null : () => _setArchived(!_archived),
                child: Text(
                  _archived ? 'Bring back' : 'Archive project',
                  style: AppType.bodyStrong.copyWith(
                    color: _archived ? Tokens.jade : Tokens.ember,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppType.body)),
            Text(
              value == null ? 'Not set' : DateFormatting.mediumDate(value!),
              style: value == null ? AppType.bodyMuted : AppType.dataStrong,
            ),
            const SizedBox(width: Tokens.space2),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Tokens.slate,
            ),
          ],
        ),
      ),
    );
  }
}

class _Refused extends StatelessWidget {
  const _Refused({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.flare.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.flare.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Tokens.flare),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              failure.message,
              style: AppType.body.copyWith(color: Tokens.flare),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

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
          keyboardType: keyboardType,
          style: AppType.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppType.bodyMuted,
            filled: true,
            fillColor: Tokens.shaft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              borderSide: const BorderSide(color: Tokens.rule),
            ),
          ),
        ),
      ],
    );
  }
}
