import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../pages/domain/page_item.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/work_task.dart';
import 'tasks_controller.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.workspace});

  final Workspace? workspace;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TasksController _controller;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = TasksController(
        repository: deps.taskRepository, realtime: deps.realtime);
    _reload();
  }

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace?.id != widget.workspace?.id) _reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reload() {
    final workspace = widget.workspace;
    if (workspace != null) _controller.load(workspace.id);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    if (workspace == null) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No workspace selected',
        message: 'Choose or create a workspace before adding tasks.',
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filtered = _controller.tasks
            .where((task) => _filter == 'all' || task.status == _filter)
            .toList();
        if (_controller.isLoading && _controller.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => _controller.load(workspace.id),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tasks',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'AI suggestions',
                    onPressed:
                        _controller.isGenerating ? null : _generateSuggestions,
                    icon: _controller.isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Create task',
                    onPressed: _showCreateTask,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                        label: 'All',
                        value: 'all',
                        selected: _filter,
                        onSelected: _setFilter),
                    _FilterPill(
                        label: 'Todo',
                        value: 'todo',
                        selected: _filter,
                        onSelected: _setFilter),
                    _FilterPill(
                        label: 'Doing',
                        value: 'doing',
                        selected: _filter,
                        onSelected: _setFilter),
                    _FilterPill(
                        label: 'Done',
                        value: 'done',
                        selected: _filter,
                        onSelected: _setFilter),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _AiSuggestions(
                recommendations: _controller.recommendations,
                preference: _controller.preference,
                isGenerating: _controller.isGenerating,
                error: _controller.error,
                onRefresh: _generateSuggestions,
                onSettings: _showAiSettings,
                onOpen: _showRecommendationActions,
                onAction: _runRecommendationAction,
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'No tasks here',
                  message:
                      'Create a task or generate AI suggestions from this workspace.',
                  action: NotionButton(
                    label: 'Create task',
                    icon: Icons.add_rounded,
                    onPressed: _showCreateTask,
                  ),
                )
              else
                ...filtered.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskTile(
                      task: task,
                      onStatus: (value) =>
                          _controller.changeStatus(task, value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);

  Future<void> _showCreateTask() async {
    final workspace = widget.workspace;
    if (workspace == null) return;
    final deps = AppScope.read(context);
    final pages = await deps.pageRepository.pages(workspace.id);
    if (!mounted) return;
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a page before adding tasks.')),
      );
      return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    var priority = 'medium';
    PageItem selectedPage = pages.first;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BottomSheetHeader(
                title: 'New task',
                subtitle: 'Keep it tied to a page so it is easy to find later.',
              ),
              NotionTextField(
                controller: title,
                autofocus: true,
                labelText: 'Task title',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              NotionTextField(
                controller: description,
                labelText: 'Description',
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PageItem>(
                initialValue: selectedPage,
                decoration: const InputDecoration(labelText: 'Related page'),
                dropdownColor: AppColors.surface,
                items: pages
                    .map(
                      (page) => DropdownMenuItem(
                        value: page,
                        child: Text(
                          '${page.icon ?? '📄'} ${page.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => selectedPage = value);
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NotionPill(
                      label: 'Low',
                      selected: priority == 'low',
                      onTap: () => setSheetState(() => priority = 'low')),
                  NotionPill(
                      label: 'Medium',
                      selected: priority == 'medium',
                      onTap: () => setSheetState(() => priority = 'medium')),
                  NotionPill(
                      label: 'High',
                      selected: priority == 'high',
                      onTap: () => setSheetState(() => priority = 'high')),
                ],
              ),
              const SizedBox(height: 18),
              NotionButton(
                label: 'Create task',
                icon: Icons.add_rounded,
                expanded: true,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true && title.text.trim().isNotEmpty) {
      await _controller.createTask(
        pageId: selectedPage.id,
        title: title.text.trim(),
        description: description.text.trim(),
        priority: priority,
      );
    }
  }

  Future<void> _generateSuggestions() async {
    final ok = await _controller.generateAi();
    if (!mounted) return;

    final message = ok
        ? (_controller.recommendations.isEmpty
            ? 'No AI suggestions for now.'
            : 'AI suggestions refreshed.')
        : _controller.error ?? 'Could not generate AI suggestions.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAiSettings() async {
    final current = _controller.preference;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI preference is still loading.')),
      );
      return;
    }

    var auto = current.enableAutoRecommendation;
    var startHour = current.workDayStartHour;
    var endHour = current.workDayEndHour;
    var days = current.preferredDaysOfWeek.toSet();
    var maxCount = current.maxRecommendationsPerSession.toDouble();
    var minPriority = current.minPriorityForRecommendation;
    var sensitivity = current.recommendationSensitivity.toDouble();
    var interval = current.recommendationIntervalMinutes.toDouble();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final canSave = days.isNotEmpty && startHour < endHour;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BottomSheetHeader(
                    title: 'AI suggestions',
                    subtitle: 'Personal preference for this workspace.',
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto suggestions',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    value: auto,
                    onChanged: (value) => setSheetState(() => auto = value),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: startHour,
                          decoration:
                              const InputDecoration(labelText: 'Start hour'),
                          dropdownColor: AppColors.surface,
                          items: [
                            for (var hour = 0; hour < 24; hour++)
                              DropdownMenuItem(
                                value: hour,
                                child: Text(_hourLabel(hour)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => startHour = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: endHour,
                          decoration:
                              const InputDecoration(labelText: 'End hour'),
                          dropdownColor: AppColors.surface,
                          items: [
                            for (var hour = 0; hour < 24; hour++)
                              DropdownMenuItem(
                                value: hour,
                                child: Text(_hourLabel(hour)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => endHour = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _SheetLabel('Preferred days'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final day in const [1, 2, 3, 4, 5, 6, 0])
                        NotionPill(
                          label: _dayLabel(day),
                          selected: days.contains(day),
                          onTap: () => setSheetState(() {
                            if (days.contains(day)) {
                              if (days.length > 1) days.remove(day);
                            } else {
                              days.add(day);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: minPriority,
                    decoration:
                        const InputDecoration(labelText: 'Minimum priority'),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => minPriority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _PreferenceSlider(
                    label: 'Suggestions per run',
                    valueLabel: maxCount.round().toString(),
                    value: maxCount,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    onChanged: (value) => setSheetState(() => maxCount = value),
                  ),
                  _PreferenceSlider(
                    label: 'Sensitivity',
                    valueLabel: '${sensitivity.round()}%',
                    value: sensitivity,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (value) =>
                        setSheetState(() => sensitivity = value),
                  ),
                  _PreferenceSlider(
                    label: 'Auto interval',
                    valueLabel: _intervalLabel(interval.round()),
                    value: interval,
                    min: 1,
                    max: 1440,
                    divisions: 95,
                    onChanged: (value) => setSheetState(() => interval = value),
                  ),
                  const SizedBox(height: 18),
                  NotionButton(
                    label: _controller.isSavingPreference
                        ? 'Saving...'
                        : 'Save settings',
                    icon: Icons.done_rounded,
                    expanded: true,
                    onPressed:
                        canSave ? () => Navigator.pop(context, true) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true) return;

    final next = current.copyWith(
      enableAutoRecommendation: auto,
      workDayStartHour: startHour,
      workDayEndHour: endHour,
      preferredDaysOfWeek: days.toList()..sort(),
      maxRecommendationsPerSession: maxCount.round(),
      minPriorityForRecommendation: minPriority,
      recommendationSensitivity: sensitivity.round(),
      recommendationIntervalMinutes: interval.round(),
    );

    final ok = await _controller.updatePreference(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'AI settings saved.'
            : _controller.error ?? 'Could not save AI settings.'),
      ),
    );
  }

  Future<void> _showRecommendationActions(TaskRecommendation item) async {
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: item.taskTitle,
      subtitle: item.reason,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isPending)
            NotionActionRow(
              icon: Icons.playlist_add_check_rounded,
              title: 'Accept suggestion',
              subtitle: 'Assign this task to you and keep it on your list.',
              onTap: () => Navigator.pop(context, 'accept'),
            ),
          NotionActionRow(
            icon: Icons.check_circle_outline_rounded,
            title: item.isAccepted ? 'Complete task' : 'Complete now',
            subtitle: item.isAccepted
                ? 'Mark the recommended task as done.'
                : 'Accept and complete this task in one step.',
            onTap: () => Navigator.pop(context, 'complete'),
          ),
          if (item.isAccepted)
            NotionActionRow(
              icon: Icons.info_outline_rounded,
              title: 'Already accepted',
              subtitle: 'This task is on your active list.',
              enabled: false,
            ),
          NotionActionRow(
            icon: Icons.close_rounded,
            title: 'Reject suggestion',
            subtitle: 'Hide this recommendation from the list.',
            danger: true,
            onTap: () => Navigator.pop(context, 'reject'),
          ),
        ],
      ),
    );

    if (action == null) return;

    await _runRecommendationAction(item, action);
  }

  Future<void> _runRecommendationAction(
    TaskRecommendation item,
    String action,
  ) async {
    bool ok = false;
    if (action == 'accept') {
      ok = await _controller.acceptRecommendation(item);
    } else if (action == 'reject') {
      ok = await _controller.rejectRecommendation(item);
    } else if (action == 'complete') {
      ok = await _controller.completeRecommendation(item);
    }

    if (!mounted) return;
    final message = ok
        ? switch (action) {
            'accept' => 'Suggestion accepted.',
            'reject' => 'Suggestion rejected.',
            'complete' => 'Task completed.',
            _ => 'Recommendation updated.',
          }
        : _controller.error ?? 'Could not update recommendation.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  static String _intervalLabel(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()}h'
        : '${hours.toStringAsFixed(1)}h';
  }

  static String _dayLabel(int day) => switch (day) {
        0 => 'Sun',
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        _ => '$day',
      };
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: NotionPill(
        label: label,
        selected: selected == value,
        onTap: () => onSelected(value),
      ),
    );
  }
}

class _AiSuggestions extends StatelessWidget {
  const _AiSuggestions({
    required this.recommendations,
    required this.preference,
    required this.isGenerating,
    required this.error,
    required this.onRefresh,
    required this.onSettings,
    required this.onOpen,
    required this.onAction,
  });

  final List<TaskRecommendation> recommendations;
  final TaskRecommendationPreference? preference;
  final bool isGenerating;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final ValueChanged<TaskRecommendation> onOpen;
  final Future<void> Function(TaskRecommendation, String) onAction;

  @override
  Widget build(BuildContext context) {
    final summary = preference == null
        ? 'Smart task queue'
        : '${preference!.maxRecommendationsPerSession} per run · ${_priorityLabel(preference!.minPriorityForRecommendation)}+ · ${preference!.recommendationSensitivity}%';
    final visibleError =
        error != null && error!.trim().isNotEmpty && recommendations.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.hover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI suggestions',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'AI settings',
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh suggestions',
              onPressed: isGenerating ? null : onRefresh,
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (isGenerating) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ],
        const SizedBox(height: 10),
        if (visibleError)
          NotionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (recommendations.isEmpty)
          NotionCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppColors.muted),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'No AI suggestions yet',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: isGenerating ? null : onRefresh,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate'),
                ),
              ],
            ),
          )
        else
          ...recommendations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionTile(
                item: item,
                onOpen: () => onOpen(item),
                onPrimaryAction: () => onAction(
                  item,
                  item.isAccepted ? 'complete' : 'accept',
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _priorityLabel(String value) => switch (value) {
        'low' => 'Low',
        'high' => 'High',
        _ => 'Medium',
      };
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.item,
    required this.onOpen,
    required this.onPrimaryAction,
  });

  final TaskRecommendation item;
  final VoidCallback onOpen;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final note = (item.reason?.trim().isNotEmpty == true
            ? item.reason
            : item.taskDescription)
        ?.trim();
    final primaryLabel = item.isAccepted ? 'Complete' : 'Accept';
    final primaryIcon = item.isAccepted
        ? Icons.check_circle_outline_rounded
        : Icons.playlist_add_check_rounded;

    return NotionCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(13),
      selected: item.isAccepted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.isAccepted
                    ? Icons.task_alt_rounded
                    : Icons.auto_awesome_rounded,
                color: item.isAccepted ? AppColors.success : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.taskTitle,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Recommendation actions',
                onPressed: onOpen,
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppColors.muted),
              ),
            ],
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                label: _recommendationStatusLabel(item.status),
                icon: item.isAccepted
                    ? Icons.check_circle_outline_rounded
                    : Icons.auto_awesome_rounded,
              ),
              _MetaChip(
                label: _priorityLabel(item.priority),
                icon: Icons.priority_high_rounded,
              ),
              if (item.score > 0)
                _MetaChip(
                  label: '${item.score.round()} score',
                  icon: Icons.speed_rounded,
                ),
              _MetaChip(
                label: _taskStatusLabel(item.taskStatus),
                icon: Icons.flag_outlined,
              ),
              if (item.taskDueDate != null)
                _MetaChip(
                  label: shortDate(item.taskDueDate),
                  icon: Icons.event_outlined,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrimaryAction,
                icon: Icon(primaryIcon, size: 18),
                label: Text(primaryLabel),
              ),
              const Spacer(),
              if (item.expiresAt?.isNotEmpty == true)
                Text(
                  'Expires ${shortDate(item.expiresAt)}',
                  style: const TextStyle(
                    color: AppColors.subtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String value) => switch (value) {
        'low' => 'Low',
        'high' => 'High',
        _ => 'Medium',
      };

  String _recommendationStatusLabel(String value) => switch (value) {
        'accepted' => 'Accepted',
        'completed' => 'Completed',
        'rejected' => 'Rejected',
        'expired' => 'Expired',
        _ => 'Pending',
      };

  String _taskStatusLabel(String value) => switch (value) {
        'doing' => 'Doing',
        'done' => 'Done',
        _ => 'Todo',
      };
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PreferenceSlider extends StatelessWidget {
  const _PreferenceSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onStatus});

  final WorkTask task;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';
    final description = task.description?.trim();
    return NotionCard(
      onTap: () => _showStatusSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isDone ? AppColors.success : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.muted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Change status',
                onPressed: () => _showStatusSheet(context),
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AppColors.muted),
              ),
            ],
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                  label: _statusLabel(task.status), icon: Icons.flag_outlined),
              _MetaChip(
                  label: task.priority, icon: Icons.priority_high_rounded),
              if (task.dueDate != null)
                _MetaChip(
                    label: shortDate(task.dueDate), icon: Icons.event_outlined),
              if (task.pageId?.isNotEmpty == true)
                const _MetaChip(
                    label: 'Page linked', icon: Icons.description_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusSheet(BuildContext context) async {
    final next = await NotionBottomSheet.show<String>(
      context: context,
      title: 'Task status',
      subtitle: task.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotionActionRow(
            icon: Icons.radio_button_unchecked_rounded,
            title: 'Todo',
            onTap: () => Navigator.pop(context, 'todo'),
          ),
          NotionActionRow(
            icon: Icons.pending_actions_rounded,
            title: 'Doing',
            onTap: () => Navigator.pop(context, 'doing'),
          ),
          NotionActionRow(
            icon: Icons.check_circle_rounded,
            title: 'Done',
            onTap: () => Navigator.pop(context, 'done'),
          ),
        ],
      ),
    );
    if (next != null && next != task.status) onStatus(next);
  }

  String _statusLabel(String value) => switch (value) {
        'doing' => 'Doing',
        'done' => 'Done',
        _ => 'Todo',
      };
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
