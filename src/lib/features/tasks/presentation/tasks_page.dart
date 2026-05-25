import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_icon_button.dart';
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
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    (() async {
      var user = await deps.authRepository.cachedUser();
      if (user == null) {
        try {
          user = await deps.authRepository.me();
        } catch (_) {
          user = null;
        }
      }
      if (!mounted) return;
      setState(() => _currentUserId = user?.id);
    })();
    _controller = TasksController(
      repository: deps.taskRepository,
      workspaceRepository: deps.workspaceRepository,
      realtime: deps.realtime,
    );
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
                  AppIconButton(
                    tooltip: 'AI suggestions',
                    tone: AppIconButtonTone.secondary,
                    isLoading: _controller.isGenerating,
                    onPressed:
                        _controller.isGenerating ? null : _generateSuggestions,
                    icon: Icons.auto_awesome_rounded,
                  ),
                  if (workspace.canWriteEffective) ...[
                    const SizedBox(width: 8),
                    AppIconButton(
                      tooltip: 'Create task',
                      tone: AppIconButtonTone.primary,
                      onPressed: _showCreateTask,
                      icon: Icons.add_rounded,
                    ),
                  ],
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
                      onSelected: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Todo',
                      value: 'todo',
                      selected: _filter,
                      onSelected: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Doing',
                      value: 'doing',
                      selected: _filter,
                      onSelected: _setFilter,
                    ),
                    _FilterPill(
                      label: 'Done',
                      value: 'done',
                      selected: _filter,
                      onSelected: _setFilter,
                    ),
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
                  action: workspace.canWriteEffective
                      ? NotionButton(
                          label: 'Create task',
                          icon: Icons.add_rounded,
                          onPressed: _showCreateTask,
                        )
                      : null,
                )
              else
                ...filtered.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskTile(
                      task: task,
                      members: _controller.members,
                      currentUserId: _currentUserId,
                      onOpen: () => _openTaskDetails(task),
                      onStatus: (value) => _changeTaskStatus(task, value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeTaskStatus(WorkTask task, String status) async {
    final ok = await _controller.changeStatus(
      task,
      status,
      currentUserId: _currentUserId,
    );

    if (!mounted || ok) return;
    AppSnackBar.warning(context, _controller.error ?? task.statusLockReason(_currentUserId));
  }

  void _setFilter(String value) => setState(() => _filter = value);

  Future<void> _showCreateTask() async {
    final workspace = widget.workspace;
    if (workspace == null) return;
    final deps = AppScope.read(context);
    final pages = await deps.pageRepository.pages(workspace.id);
    if (!mounted) return;
    if (pages.isEmpty) {
      AppSnackBar.warning(context, 'Hãy tạo page trước khi tạo task.');
      return;
    }

    if (_controller.members.isEmpty) {
      await _controller.reloadMembers();
    }

    final title = TextEditingController();
    final description = TextEditingController();
    var priority = 'medium';
    PageItem selectedPage = pages.first;
    final selectedAssignees = <String>{};

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                  title: 'New task',
                  subtitle: 'Tạo task và gán người làm ngay từ đầu.',
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
                    if (value != null) {
                      setSheetState(() => selectedPage = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                const _SheetLabel('Priority'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NotionPill(
                      label: 'Low',
                      selected: priority == 'low',
                      onTap: () => setSheetState(() => priority = 'low'),
                    ),
                    NotionPill(
                      label: 'Medium',
                      selected: priority == 'medium',
                      onTap: () => setSheetState(() => priority = 'medium'),
                    ),
                    NotionPill(
                      label: 'High',
                      selected: priority == 'high',
                      onTap: () => setSheetState(() => priority = 'high'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (workspace.canManageMembersEffective) ...[
                  _AssigneePicker(
                    members: _controller.members,
                    selectedIds: selectedAssignees,
                    currentUserId: _currentUserId,
                    enabled: true,
                    onToggle: (member) {
                      setSheetState(() {
                        if (!selectedAssignees.add(member.userId)) {
                          selectedAssignees.remove(member.userId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                ],
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
      ),
    );

    if (ok == true && title.text.trim().isNotEmpty) {
      try {
        await _controller.createTask(
          pageId: selectedPage.id,
          title: title.text.trim(),
          description: description.text.trim(),
          priority: priority,
          assigneeUserIds: selectedAssignees.toList(),
        );
        if (mounted) {
          AppSnackBar.success(context, 'Đã tạo task.');
        }
      } catch (_) {
        if (!mounted) return;
        AppSnackBar.error(context, _controller.error);
      }
    }
  }

  Future<void> _openTaskDetails(WorkTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TaskDetailSheet(
        task: task,
        controller: _controller,
        canAssign: widget.workspace?.canManageMembersEffective == true,
        currentUserId: _currentUserId,
      ),
    );
  }

  Future<void> _generateSuggestions() async {
    final ok = await _controller.generateAi();
    if (!mounted) return;

    final message = ok
        ? (_controller.recommendations.isEmpty
            ? 'Chưa có gợi ý AI phù hợp.'
            : 'Đã làm mới gợi ý AI.')
        : _controller.error ?? 'Không thao tác được.';
    AppSnackBar.show(
      context,
      message,
      tone: ok ? AppSnackTone.success : AppSnackTone.error,
    );
  }

  Future<void> _showAiSettings() async {
    final current = _controller.preference;
    if (current == null) {
      AppSnackBar.info(context, 'AI preference is still loading.');
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
    AppSnackBar.show(
      context,
      ok ? 'AI settings saved.' : AppSnackBar.cleanError(_controller.error),
      tone: ok ? AppSnackTone.success : AppSnackTone.error,
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
        : _controller.error ?? 'Không thao tác được.';
    AppSnackBar.show(
      context,
      message,
      tone: ok ? AppSnackTone.success : AppSnackTone.error,
    );
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

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.controller,
    required this.canAssign,
    this.currentUserId,
  });

  final WorkTask task;
  final TasksController controller;
  final bool canAssign;
  final String? currentUserId;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  final TextEditingController _comment = TextEditingController();
  String? _replyToCommentId;

  @override
  void initState() {
    super.initState();
    widget.controller.loadComments(widget.task);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final task = widget.controller.taskById(widget.task.id) ?? widget.task;
        final comments = widget.controller.commentsFor(task.id);
        final replyTo = _replyToCommentId == null
            ? null
            : _findComment(comments, _replyToCommentId!);
        final bottom = MediaQuery.viewInsetsOf(context).bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BottomSheetHeader(
                    title: task.title,
                    subtitle: 'Bình luận realtime · phân người làm rõ ràng',
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (task.description?.trim().isNotEmpty == true) ...[
                          Text(
                            task.description!.trim(),
                            style: const TextStyle(
                              color: AppColors.muted,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(
                              label: _statusLabel(task.status),
                              icon: Icons.flag_outlined,
                            ),
                            _MetaChip(
                              label: _priorityLabel(task.priority),
                              icon: Icons.priority_high_rounded,
                            ),
                            if (task.dueDate != null)
                              _MetaChip(
                                label: shortDate(task.dueDate),
                                icon: Icons.event_outlined,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _SheetLabel('Status'),
                        const SizedBox(height: 8),
                        if (task.canChangeStatusBy(widget.currentUserId))
                          _TaskStatusPicker(
                            status: task.status,
                            onChanged: (status) => _changeStatus(task, status),
                          )
                        else
                          _InlineNotice(
                            icon: task.isDone
                                ? Icons.lock_outline_rounded
                                : Icons.person_off_outlined,
                            message: task.statusLockReason(widget.currentUserId),
                          ),
                        const SizedBox(height: 20),
                        if (widget.canAssign || task.assigneeUserIds.isNotEmpty) ...[
                          const _SheetLabel('Assignees'),
                          const SizedBox(height: 8),
                          if (widget.canAssign)
                            _AssigneePicker(
                              members: widget.controller.members,
                              selectedIds: task.assigneeUserIds.toSet(),
                              currentUserId: widget.currentUserId,
                              enabled: !widget.controller.isAssigning,
                              onToggle: (member) async {
                                final ok = await widget.controller.toggleAssignee(
                                  task,
                                  member,
                                );
                                if (!ok && mounted) {
                                  AppSnackBar.error(context, widget.controller.error);
                                }
                              },
                            )
                          else
                            _AssigneePreview(
                              userIds: task.assigneeUserIds,
                              members: widget.controller.members,
                            ),
                          const SizedBox(height: 20),
                        ],
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Comments',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (widget.controller.isLoadingComments(task.id))
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                tooltip: 'Refresh comments',
                                onPressed: () =>
                                    widget.controller.loadComments(task),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (comments.isEmpty &&
                            !widget.controller.isLoadingComments(task.id))
                          const _InlineNotice(
                            icon: Icons.chat_bubble_outline_rounded,
                            message:
                                'Chưa có bình luận. Bắn phát đầu cho nóng workspace nào.',
                          )
                        else
                          _CommentThreadList(
                            comments: comments,
                            memberFor: widget.controller.memberById,
                            onReply: (comment) {
                              setState(() => _replyToCommentId = comment.id);
                            },
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  if (replyTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReplyBanner(
                        name: _commentAuthorName(replyTo, widget.controller),
                        onCancel: () => setState(() => _replyToCommentId = null),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comment,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: replyTo == null
                                ? 'Viết bình luận...'
                                : 'Trả lời bình luận...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppIconButton(
                        tooltip: 'Send comment',
                        tone: AppIconButtonTone.primary,
                        isLoading: widget.controller.isSendingComment(task.id),
                        onPressed: widget.controller.isSendingComment(task.id)
                            ? null
                            : () => _sendComment(task),
                        icon: Icons.send_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeStatus(WorkTask task, String status) async {
    final ok = await widget.controller.changeStatus(
      task,
      status,
      currentUserId: widget.currentUserId,
    );

    if (!mounted || ok) return;
    AppSnackBar.warning(
      context,
      widget.controller.error ?? task.statusLockReason(widget.currentUserId),
    );
  }

  Future<void> _sendComment(WorkTask task) async {
    final ok = await widget.controller.createComment(
      task,
      content: _comment.text,
      parentId: _replyToCommentId,
    );

    if (ok) {
      _comment.clear();
      setState(() => _replyToCommentId = null);
      return;
    }

    if (!mounted) return;
    AppSnackBar.error(context, widget.controller.error);
  }
}

class _CommentThreadList extends StatelessWidget {
  const _CommentThreadList({
    required this.comments,
    required this.memberFor,
    required this.onReply,
  });

  final List<TaskComment> comments;
  final WorkspaceMember? Function(String userId) memberFor;
  final ValueChanged<TaskComment> onReply;

  @override
  Widget build(BuildContext context) {
    final roots = comments
        .where((comment) => comment.parentId == null || comment.parentId!.isEmpty)
        .toList();
    final repliesByParent = <String, List<TaskComment>>{};
    for (final comment in comments.where((item) =>
        item.parentId != null && item.parentId!.trim().isNotEmpty)) {
      repliesByParent.putIfAbsent(comment.parentId!, () => <TaskComment>[])
          .add(comment);
    }

    return Column(
      children: [
        for (final root in roots)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommentBubble(
              comment: root,
              memberFor: memberFor,
              repliesByParent: repliesByParent,
              onReply: onReply,
            ),
          ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.memberFor,
    required this.repliesByParent,
    required this.onReply,
  });

  final TaskComment comment;
  final WorkspaceMember? Function(String userId) memberFor;
  final Map<String, List<TaskComment>> repliesByParent;
  final ValueChanged<TaskComment> onReply;

  @override
  Widget build(BuildContext context) {
    final member = memberFor(comment.userId);
    final name = _memberName(member);
    final replies = repliesByParent[comment.id] ?? const <TaskComment>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NotionCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                name: name,
                imageUrl: member?.avatarUrl,
                radius: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (comment.createdDate?.isNotEmpty == true)
                          Text(
                            shortDate(comment.createdDate),
                            style: const TextStyle(
                              color: AppColors.subtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.isDeleted
                          ? 'Bình luận đã bị xóa.'
                          : comment.content,
                      style: TextStyle(
                        color:
                            comment.isDeleted ? AppColors.subtle : AppColors.ink,
                        height: 1.35,
                        fontStyle:
                            comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    if (!comment.isDeleted) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => onReply(comment),
                          icon: const Icon(Icons.reply_rounded, size: 16),
                          label: const Text('Reply'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (replies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    for (final reply in replies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommentBubble(
                          comment: reply,
                          memberFor: memberFor,
                          repliesByParent: repliesByParent,
                          onReply: onReply,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AssigneePicker extends StatelessWidget {
  const _AssigneePicker({
    required this.members,
    required this.selectedIds,
    required this.enabled,
    required this.onToggle,
    this.currentUserId,
  });

  final List<WorkspaceMember> members;
  final Set<String> selectedIds;
  final bool enabled;
  final ValueChanged<WorkspaceMember> onToggle;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final me = currentUserId?.trim().toLowerCase();
    final assignable = members.where((member) {
      final id = member.userId.trim().toLowerCase();
      if (id.isEmpty) return false;
      if (member.isCurrentUser) return false;
      if (me != null && me.isNotEmpty && id == me) return false;
      return true;
    }).toList();
    if (assignable.isEmpty) {
      return const _InlineNotice(
        icon: Icons.person_search_rounded,
        message: 'Chưa có member khác để gán task.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final member in assignable)
          FilterChip(
            selected: selectedIds.contains(member.userId),
            onSelected: enabled ? (_) => onToggle(member) : null,
            selectedColor: AppColors.ink,
            checkmarkColor: AppColors.background,
            backgroundColor: AppColors.surface,
            disabledColor: AppColors.hover,
            side: BorderSide(
              color: selectedIds.contains(member.userId)
                  ? AppColors.ink
                  : AppColors.line,
            ),
            avatar: AppAvatar(
              name: _memberName(member),
              imageUrl: member.avatarUrl,
              radius: 11,
            ),
            label: Text(
              _memberName(member),
              style: TextStyle(
                color: selectedIds.contains(member.userId)
                    ? AppColors.background
                    : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}


class _TaskStatusPicker extends StatelessWidget {
  const _TaskStatusPicker({required this.status, required this.onChanged});

  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NotionPill(
          label: 'Todo',
          selected: status == 'todo',
          onTap: status == 'todo' ? null : () => onChanged('todo'),
        ),
        NotionPill(
          label: 'Doing',
          selected: status == 'doing',
          onTap: status == 'doing' ? null : () => onChanged('doing'),
        ),
        NotionPill(
          label: 'Done',
          selected: status == 'done',
          onTap: status == 'done' ? null : () => onChanged('done'),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.members,
    required this.currentUserId,
    required this.onOpen,
    required this.onStatus,
  });

  final WorkTask task;
  final List<WorkspaceMember> members;
  final String? currentUserId;
  final VoidCallback onOpen;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';
    final canChangeStatus = task.canChangeStatusBy(currentUserId);
    final description = task.description?.trim();

    return NotionCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: canChangeStatus ? 'Đổi trạng thái' : task.statusLockReason(currentUserId),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: canChangeStatus ? () => _showStatusSheet(context) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone
                          ? AppColors.success
                          : (canChangeStatus ? AppColors.ink : AppColors.muted),
                    ),
                  ),
                ),
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
              if (canChangeStatus)
                IconButton(
                  tooltip: 'Task status',
                  onPressed: () => _showStatusSheet(context),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.muted,
                  ),
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                label: _statusLabel(task.status),
                icon: Icons.flag_outlined,
              ),
              _MetaChip(
                label: _priorityLabel(task.priority),
                icon: Icons.priority_high_rounded,
              ),
              if (task.dueDate != null)
                _MetaChip(
                  label: shortDate(task.dueDate),
                  icon: Icons.event_outlined,
                ),
              if (task.pageId?.isNotEmpty == true)
                const _MetaChip(
                  label: 'Page linked',
                  icon: Icons.description_outlined,
                ),
              if (task.assigneeUserIds.isNotEmpty)
                _AssigneePreview(
                  userIds: task.assigneeUserIds,
                  members: members,
                ),
              const _MetaChip(
                label: 'Comments',
                icon: Icons.mode_comment_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusSheet(BuildContext context) async {
    if (!task.canChangeStatusBy(currentUserId)) {
      AppSnackBar.warning(context, task.statusLockReason(currentUserId));
      return;
    }

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
            subtitle: task.status == 'todo' ? 'Đang ở trạng thái này.' : null,
            enabled: task.status != 'todo',
            onTap: () => Navigator.pop(context, 'todo'),
          ),
          NotionActionRow(
            icon: Icons.pending_actions_rounded,
            title: 'Doing',
            subtitle: task.status == 'doing' ? 'Đang ở trạng thái này.' : null,
            enabled: task.status != 'doing',
            onTap: () => Navigator.pop(context, 'doing'),
          ),
          NotionActionRow(
            icon: Icons.check_circle_rounded,
            title: 'Done',
            subtitle: 'Hoàn thành là khóa, không đổi lại được.',
            enabled: task.status != 'done',
            onTap: () => Navigator.pop(context, 'done'),
          ),
        ],
      ),
    );
    if (next != null && next != task.status) onStatus(next);
  }
}

class _AssigneePreview extends StatelessWidget {
  const _AssigneePreview({required this.userIds, required this.members});

  final List<String> userIds;
  final List<WorkspaceMember> members;

  @override
  Widget build(BuildContext context) {
    final visibleUserIds = userIds
        .where((id) => _memberById(members, id)?.isCurrentUser != true)
        .toList();

    if (visibleUserIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = visibleUserIds.take(3).toList();
    final names = shown.map((id) => _memberName(_memberById(members, id))).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: shown.length <= 1 ? 22 : 22.0 + (shown.length - 1) * 14,
            height: 22,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 14,
                    child: AppAvatar(
                      name: names[i],
                      imageUrl: _memberById(members, shown[i])?.avatarUrl,
                      radius: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            visibleUserIds.length > 3
                ? '${visibleUserIds.length} assignees'
                : names.join(', '),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
            AppIconButton(
              tooltip: 'AI settings',
              tone: AppIconButtonTone.secondary,
              onPressed: onSettings,
              icon: Icons.tune_rounded,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 8),
            AppIconButton(
              tooltip: 'Refresh suggestions',
              tone: AppIconButtonTone.primary,
              isLoading: isGenerating,
              onPressed: isGenerating ? null : onRefresh,
              icon: Icons.refresh_rounded,
              size: 40,
              iconSize: 19,
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

WorkspaceMember? _memberById(List<WorkspaceMember> members, String userId) {
  final clean = userId.trim().toLowerCase();
  if (clean.isEmpty) return null;
  for (final member in members) {
    if (member.userId.toLowerCase() == clean) return member;
  }
  return null;
}

String _memberName(WorkspaceMember? member) {
  if (member == null) return 'Thành viên';
  final name = member.fullName.trim().isNotEmpty
      ? member.fullName.trim()
      : member.userName.trim();
  return name.isEmpty ? 'Thành viên' : name;
}

String _commentAuthorName(TaskComment comment, TasksController controller) {
  return _memberName(controller.memberById(comment.userId));
}

String _statusLabel(String value) => switch (value) {
      'doing' => 'Doing',
      'done' => 'Done',
      _ => 'Todo',
    };

String _priorityLabel(String value) => switch (value) {
      'low' => 'Low',
      'high' => 'High',
      _ => 'Medium',
    };

TaskComment? _findComment(List<TaskComment> comments, String id) {
  for (final comment in comments) {
    if (comment.id == id) return comment;
  }
  return null;
}
