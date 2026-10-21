import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project_plan.dart';
import '../../routing/routes.dart';
import '../../state/auth_notifier.dart';
import '../../state/providers.dart';
import '../../theme/density.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';

/// The projects a team has told the app about.
///
/// This is setup, not status. Nothing typed here says how the work is going —
/// a name, a client, a squad, a budget and a schedule, all of which a commit
/// log cannot know. The score still comes from ingestion and is still
/// unwritable from the app, which is what keeps constraint 3 intact while a
/// lead can still add a project.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A developer reads every project's setup and changes none, the same
    // shape as scoring weights and connected sources.
    final canEdit = ref.watch(canChangeSettingsProvider);

    final async = ref.watch(projectPlansProvider);
    final plans = async.value ?? const <ProjectPlan>[];

    if (async.isLoading && async.value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projects')),
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

    final active = plans.where((p) => !p.isArchived).toList();
    final archived = plans.where((p) => p.isArchived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: plans.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              headline: 'No projects yet',
              body:
                  'Add a project and connect a source to it, and the app '
                  'starts reading activity on its own. Nothing about progress '
                  'needs typing in.',
              actionLabel: canEdit ? 'Add a project' : null,
              onAction: canEdit
                  ? () => Navigator.of(context).pushNamed(Routes.editProject)
                  : null,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space2,
                Tokens.space4,
                Tokens.space7,
              ),
              children: [
                for (final plan in active) ...[
                  _PlanRow(plan: plan, canEdit: canEdit),
                  const SizedBox(height: Tokens.space3),
                ],
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space3),
                  Text('ARCHIVED', style: AppType.label),
                  const SizedBox(height: Tokens.space1),
                  Text(
                    'Not scored and not on the dashboard. The history is '
                    'kept, because a project that went wrong is the one most '
                    'worth looking back at.',
                    style: AppType.bodyMuted,
                  ),
                  const SizedBox(height: Tokens.space3),
                  for (final plan in archived) ...[
                    _PlanRow(plan: plan, canEdit: canEdit),
                    const SizedBox(height: Tokens.space3),
                  ],
                ],
              ],
            ),
      floatingActionButton: (plans.isEmpty || !canEdit)
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(Routes.editProject),
              backgroundColor: Tokens.beacon,
              foregroundColor: Tokens.shaft,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.canEdit});

  final ProjectPlan plan;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    // Said plainly rather than hidden: a plan missing a budget or a schedule
    // still scores, just on less. Knowing which is which is the difference
    // between a low score and an incomplete one.
    final incomplete = !plan.isUsable;

    return Semantics(
      button: canEdit,
      label:
          '${plan.name}${plan.client.isEmpty ? '' : ', ${plan.client}'}'
          '${plan.isArchived ? ', archived' : ''}'
          '${incomplete ? ', setup incomplete' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: canEdit
            ? () => Navigator.of(
                context,
              ).pushNamed(Routes.editProject, arguments: plan.projectId)
            : null,
        child: Container(
          padding: EdgeInsets.all(context.dense(Tokens.space4)),
          decoration: BoxDecoration(
            color: Tokens.seam,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(color: Tokens.rule),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: AppType.bodyStrong.copyWith(
                        color: plan.isArchived ? Tokens.slate : Tokens.chalk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.client.isNotEmpty) ...[
                      const SizedBox(height: Tokens.space1),
                      Text(
                        plan.client,
                        style: AppType.bodyMuted,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (incomplete && !plan.isArchived) ...[
                      const SizedBox(height: Tokens.space2),
                      Text(
                        'Budget, dates or hours missing — scored on less',
                        style: AppType.data.copyWith(color: Tokens.brass),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: Tokens.space3),
                const Icon(Icons.chevron_right, size: 18, color: Tokens.slate),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
