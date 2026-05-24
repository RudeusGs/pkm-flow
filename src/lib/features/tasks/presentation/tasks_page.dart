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
                    onPressed: _controller.generateAi,
                    icon: const Icon(Icons.auto_awesome_rounded),
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
              if (_controller.recommendations.isNotEmpty) ...[
                const SizedBox(height: 18),
                _AiSuggestions(
                  recommendations: _controller.recommendations,
                  onRefresh: _controller.generateAi,
                ),
              ],
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
                value: selectedPage,
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
    required this.onRefresh,
  });

  final List<TaskRecommendation> recommendations;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.muted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI suggestions',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(onPressed: onRefresh, child: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 8),
          ...recommendations.take(4).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NotionCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.taskTitle,
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900),
                        ),
                        if ((item.reason ?? item.priority)
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.reason ?? item.priority,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
