import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../shared/widgets/empty_state.dart';
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

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = TasksController(
        repository: deps.taskRepository,
        pageRepository: deps.pageRepository,
        realtime: deps.realtime);
    _reload();
  }

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace?.id != widget.workspace?.id) _reload();
  }

  void _reload() {
    final workspace = widget.workspace;
    if (workspace != null) _controller.load(workspace.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workspace == null) {
      return const EmptyState(icon: Icons.task_alt, title: 'Chưa có workspace');
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => _controller.load(widget.workspace!.id),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Tasks',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900))),
                  IconButton.filledTonal(
                      onPressed: _showCreateTask,
                      icon: const Icon(Icons.add_task)),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _controller.generateAi,
                      icon: const Icon(Icons.auto_awesome)),
                ],
              ),
              if (_controller.error != null) ...[
                const SizedBox(height: 8),
                Text(_controller.error!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              if (_controller.recommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Gợi ý AI',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ..._controller.recommendations.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: Text(item.taskTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(item.reason ?? item.priority),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                              onPressed: () =>
                                  _controller.acceptRecommendation(item),
                              icon: const Icon(Icons.check)),
                          IconButton(
                              onPressed: () =>
                                  _controller.rejectRecommendation(item),
                              icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_controller.tasks.isEmpty)
                const EmptyState(icon: Icons.checklist, title: 'Chưa có task')
              else
                ..._controller.tasks.map(
                  (task) => _TaskTile(
                    task: task,
                    onTap: () => _openTask(task),
                    onStatus: (value) => _controller.changeStatus(task, value),
                    onEdit: () => _showEditTask(task),
                    onDelete: () => _deleteTask(task),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateTask() async {
    final result = await _showTaskDialog(context, _controller);
    if (result == null) return;
    await _controller.createTask(
      pageId: result.pageId,
      title: result.title,
      description: result.description,
      priority: result.priority,
      dueDate: result.dueDate,
    );
  }

  Future<void> _showEditTask(WorkTask task) async {
    final result = await _showTaskDialog(context, _controller, task: task);
    if (result == null) return;
    await _controller.updateTask(
      task,
      title: result.title,
      description: result.description,
      priority: result.priority,
      dueDate: result.dueDate,
    );
  }

  Future<void> _deleteTask(WorkTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa task?'),
        content: Text(task.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await _controller.deleteTask(task);
  }

  Future<void> _openTask(WorkTask task) async {
    await _controller.openTask(task);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskDetailPage(controller: _controller)));
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.task,
      required this.onTap,
      required this.onStatus,
      required this.onEdit,
      required this.onDelete});

  final WorkTask task;
  final VoidCallback onTap;
  final ValueChanged<String> onStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(task.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${task.priority} • ${task.dueDate == null ? 'Không deadline' : shortDate(task.dueDate)}'),
        leading: Icon(
            task.status == 'done'
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: task.status == 'done' ? AppColors.accent : AppColors.muted),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'todo':
              case 'doing':
              case 'done':
                onStatus(value);
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'todo', child: Text('Todo')),
            PopupMenuItem(value: 'doing', child: Text('Doing')),
            PopupMenuItem(value: 'done', child: Text('Done')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'edit', child: Text('Sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.controller});

  final TasksController controller;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _comment = TextEditingController();

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
        final task = widget.controller.selectedTask;
        return Scaffold(
          appBar: AppBar(title: Text(task?.title ?? 'Task')),
          body: task == null
              ? const EmptyState(
                  icon: Icons.task_alt, title: 'Không tìm thấy task')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(task.title,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(task.status)),
                        Chip(label: Text(task.priority)),
                        if (task.dueDate != null)
                          Chip(label: Text(shortDate(task.dueDate))),
                      ],
                    ),
                    if (task.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(task.description!),
                    ],
                    const SizedBox(height: 24),
                    const Text('Bình luận',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (widget.controller.comments.isEmpty)
                      const EmptyState(
                          icon: Icons.mode_comment_outlined,
                          title: 'Chưa có bình luận')
                    else
                      ...widget.controller.comments.map((item) => Card(
                          child: ListTile(
                              title: Text(item.content),
                              subtitle: Text(shortDate(item.createdDate))))),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _comment,
                                decoration: const InputDecoration(
                                    hintText: 'Thêm bình luận'))),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () async {
                            final text = _comment.text;
                            _comment.clear();
                            await widget.controller.addComment(text);
                          },
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _TaskFormResult {
  const _TaskFormResult(
      {required this.pageId,
      required this.title,
      this.description,
      required this.priority,
      this.dueDate});

  final String pageId;
  final String title;
  final String? description;
  final String priority;
  final String? dueDate;
}

Future<_TaskFormResult?> _showTaskDialog(
    BuildContext context, TasksController controller,
    {WorkTask? task}) {
  final title = TextEditingController(text: task?.title ?? '');
  final description = TextEditingController(text: task?.description ?? '');
  final dueDate = TextEditingController(text: task?.dueDate ?? '');
  var priority = task?.priority ?? 'medium';
  var pageId = task?.pageId ??
      (controller.pages.isEmpty ? '' : controller.pages.first.id);

  return showDialog<_TaskFormResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(task == null ? 'Tạo task' : 'Sửa task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: pageId.isEmpty ? null : pageId,
                decoration: const InputDecoration(labelText: 'Page'),
                items: controller.pages
                    .map((page) => DropdownMenuItem(
                        value: page.id, child: Text(page.title)))
                    .toList(),
                onChanged: task == null
                    ? (value) => setState(() => pageId = value ?? '')
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mô tả')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Ưu tiên'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) =>
                    setState(() => priority = value ?? 'medium'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: dueDate,
                  decoration: const InputDecoration(
                      labelText: 'Due date', hintText: '2026-05-24')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: pageId.isEmpty || title.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _TaskFormResult(
                        pageId: pageId,
                        title: title.text.trim(),
                        description: description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        priority: priority,
                        dueDate: dueDate.text.trim().isEmpty
                            ? null
                            : dueDate.text.trim(),
                      ),
                    ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}
