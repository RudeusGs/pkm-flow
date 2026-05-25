import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../workspaces/data/workspace_repository.dart';
import '../../workspaces/domain/workspace.dart';
import '../data/task_repository.dart';
import '../domain/work_task.dart';

class TasksController extends ChangeNotifier {
  TasksController({
    required TaskRepository repository,
    required WorkspaceRepository workspaceRepository,
    required RealtimeService realtime,
  })  : _repository = repository,
        _workspaceRepository = workspaceRepository,
        _realtime = realtime;

  final TaskRepository _repository;
  final WorkspaceRepository _workspaceRepository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  final Set<String> _joinedPageIds = <String>{};

  Timer? _reloadDebounce;
  Timer? _commentDebounce;

  String? workspaceId;
  List<WorkTask> tasks = const [];
  List<WorkspaceMember> members = const [];
  List<TaskRecommendation> recommendations = const [];
  TaskRecommendationPreference? preference;

  final Map<String, List<TaskComment>> commentsByTaskId =
      <String, List<TaskComment>>{};
  final Set<String> _loadingCommentTaskIds = <String>{};
  final Set<String> _sendingCommentTaskIds = <String>{};

  bool isLoading = false;
  bool isGenerating = false;
  bool isSavingPreference = false;
  bool isAssigning = false;
  String? error;

  List<TaskComment> commentsFor(String taskId) =>
      commentsByTaskId[taskId] ?? const <TaskComment>[];

  bool isLoadingComments(String taskId) => _loadingCommentTaskIds.contains(taskId);

  bool isSendingComment(String taskId) => _sendingCommentTaskIds.contains(taskId);

  WorkTask? taskById(String taskId) {
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  WorkspaceMember? memberById(String userId) {
    final clean = userId.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final member in members) {
      if (member.userId.toLowerCase() == clean) return member;
    }
    return null;
  }

  Future<void> load(String nextWorkspaceId) async {
    workspaceId = nextWorkspaceId;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final nextTasks = await _repository.workspaceTasks(nextWorkspaceId);
      List<TaskRecommendation> nextRecommendations = const <TaskRecommendation>[];
      TaskRecommendationPreference? nextPreference;
      List<WorkspaceMember> nextMembers = const <WorkspaceMember>[];

      try {
        nextRecommendations =
            await _repository.activeRecommendations(nextWorkspaceId);
      } catch (_) {
        nextRecommendations = const <TaskRecommendation>[];
      }

      try {
        nextPreference = await _repository.recommendationPreference(nextWorkspaceId);
      } catch (_) {
        nextPreference = null;
      }

      try {
        nextMembers = await _workspaceRepository.members(nextWorkspaceId);
      } catch (_) {
        nextMembers = const <WorkspaceMember>[];
      }

      tasks = nextTasks;
      recommendations = nextRecommendations;
      preference = nextPreference;
      members = nextMembers;

      await _syncJoinedTaskPages();
      _bindRealtime();
    } catch (err) {
      error = _friendlyError(err);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadMembers() async {
    final id = workspaceId;
    if (id == null) return;
    try {
      members = await _workspaceRepository.members(id);
      error = null;
      notifyListeners();
    } catch (err) {
      error = _friendlyError(err);
      notifyListeners();
    }
  }

  Future<void> createTask({
    required String pageId,
    required String title,
    String? description,
    String priority = 'medium',
    String? dueDate,
    List<String> assigneeUserIds = const <String>[],
  }) async {
    try {
      final created = await _repository.createTask(
        pageId,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        assigneeUserIds: assigneeUserIds,
      );
      tasks = [created, ...tasks];
      await _joinTaskPage(created);
      error = null;
      notifyListeners();
    } catch (err) {
      error = _friendlyError(err);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> changeStatus(WorkTask task, String status) async {
    try {
      final updated = await _repository.changeStatus(task.id, status);
      _replaceTask(updated);
      error = null;
    } catch (err) {
      error = _friendlyError(err);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> toggleAssignee(WorkTask task, WorkspaceMember member) async {
    if (member.userId.trim().isEmpty) return false;

    isAssigning = true;
    error = null;
    notifyListeners();

    try {
      final isAssigned = task.assigneeUserIds.contains(member.userId);
      final updated = isAssigned
          ? await _repository.unassignTask(task.id, member.userId)
          : await _repository.assignTask(task.id, member.userId);
      _replaceTask(updated);
      error = null;
      return true;
    } catch (err) {
      error = _friendlyError(err);
      return false;
    } finally {
      isAssigning = false;
      notifyListeners();
    }
  }

  Future<void> loadComments(WorkTask task) async {
    if (_loadingCommentTaskIds.contains(task.id)) return;

    _loadingCommentTaskIds.add(task.id);
    error = null;
    notifyListeners();

    try {
      await _joinTaskPage(task);
      commentsByTaskId[task.id] = await _repository.taskComments(task.id);
      error = null;
    } catch (err) {
      error = _friendlyError(err);
    } finally {
      _loadingCommentTaskIds.remove(task.id);
      notifyListeners();
    }
  }

  Future<bool> createComment(
    WorkTask task, {
    required String content,
    String? parentId,
  }) async {
    final clean = content.trim();
    if (clean.isEmpty) return false;

    _sendingCommentTaskIds.add(task.id);
    error = null;
    notifyListeners();

    try {
      await _joinTaskPage(task);
      final created = await _repository.createComment(
        task.id,
        content: clean,
        parentId: parentId,
      );
      final current = commentsByTaskId[task.id] ?? const <TaskComment>[];
      commentsByTaskId[task.id] = [...current, created];
      error = null;
      return true;
    } catch (err) {
      error = _friendlyError(err);
      return false;
    } finally {
      _sendingCommentTaskIds.remove(task.id);
      notifyListeners();
    }
  }

  Future<bool> generateAi({String? pageId}) async {
    final id = workspaceId;
    if (id == null) return false;
    isGenerating = true;
    error = null;
    notifyListeners();
    try {
      final generated = await _repository.generateRecommendations(
        id,
        pageId: pageId,
        force: true,
      );
      final active = await _repository.activeRecommendations(id);
      recommendations = _mergeRecommendations([...generated, ...active]);
      error = null;
      return true;
    } catch (err) {
      error = _friendlyError(err);
      return false;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<bool> updatePreference(TaskRecommendationPreference next) async {
    final id = workspaceId;
    if (id == null) return false;
    isSavingPreference = true;
    error = null;
    notifyListeners();
    try {
      preference = await _repository.updateRecommendationPreference(id, next);
      error = null;
      return true;
    } catch (err) {
      error = _friendlyError(err);
      return false;
    } finally {
      isSavingPreference = false;
      notifyListeners();
    }
  }

  Future<bool> acceptRecommendation(TaskRecommendation recommendation) async {
    try {
      final updated = await _repository.acceptRecommendation(recommendation.id);
      _replaceRecommendation(updated);
      final id = workspaceId;
      if (id != null) {
        tasks = await _repository.workspaceTasks(id);
        await _syncJoinedTaskPages();
      }
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = _friendlyError(err);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRecommendation(TaskRecommendation recommendation) async {
    try {
      await _repository.rejectRecommendation(recommendation.id);
      recommendations = recommendations
          .where((item) => item.id != recommendation.id)
          .toList();
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = _friendlyError(err);
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeRecommendation(
    TaskRecommendation recommendation, {
    String? notes,
  }) async {
    try {
      await _repository.completeRecommendation(
        recommendation.id,
        notes: notes,
      );
      recommendations = recommendations
          .where((item) => item.id != recommendation.id)
          .toList();
      final id = workspaceId;
      if (id != null) {
        tasks = await _repository.workspaceTasks(id);
        await _syncJoinedTaskPages();
      }
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = _friendlyError(err);
      notifyListeners();
      return false;
    }
  }

  Future<void> _syncJoinedTaskPages() async {
    final nextPageIds = tasks
        .map((task) => task.pageId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final stale = _joinedPageIds.difference(nextPageIds).toList();
    for (final pageId in stale) {
      _joinedPageIds.remove(pageId);
      unawaited(_realtime.leavePage(pageId));
    }

    for (final pageId in nextPageIds) {
      if (_joinedPageIds.add(pageId)) {
        await _realtime.joinPage(pageId);
      }
    }
  }

  Future<void> _joinTaskPage(WorkTask task) async {
    final pageId = task.pageId?.trim();
    if (pageId == null || pageId.isEmpty) return;
    if (_joinedPageIds.add(pageId)) {
      await _realtime.joinPage(pageId);
    }
  }

  void _replaceTask(WorkTask updated) {
    var found = false;
    tasks = tasks.map((item) {
      if (item.id == updated.id) {
        found = true;
        return updated;
      }
      return item;
    }).toList();

    if (!found) tasks = [updated, ...tasks];
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;

    for (final event in [
      'TaskCreated',
      'TaskUpdated',
      'TaskDeleted',
      'TaskStatusChanged',
      'TaskAssigned',
      'TaskUnassigned',
      'TaskAssignedFromRecommendation',
      'TaskCompletedFromRecommendation',
      'TaskRecommendationsGenerated',
      'TaskRecommendationAccepted',
      'TaskRecommendationRejected',
      'TaskRecommendationCompleted',
    ]) {
      _unsubscribe.add(_realtime.on(event, _handleTaskRealtimeEvent));
    }

    for (final event in [
      'TaskCommentCreated',
      'TaskCommentUpdated',
      'TaskCommentDeleted',
      'TaskCommentRestored',
    ]) {
      _unsubscribe.add(_realtime.on(event, _handleTaskCommentRealtimeEvent));
    }
  }

  void _handleTaskRealtimeEvent(RealtimeEvent event) {
    final id = workspaceId;
    if (id == null) return;
    if (event.workspaceId != null && event.workspaceId != id) return;

    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () => load(id));
  }

  void _handleTaskCommentRealtimeEvent(RealtimeEvent event) {
    final taskId = event.taskId;
    if (taskId == null || !commentsByTaskId.containsKey(taskId)) return;

    final task = taskById(taskId);
    if (task == null) return;

    _commentDebounce?.cancel();
    _commentDebounce =
        Timer(const Duration(milliseconds: 250), () => loadComments(task));
  }

  void _replaceRecommendation(TaskRecommendation recommendation) {
    final next = [...recommendations];
    final index = next.indexWhere((item) => item.id == recommendation.id);
    if (index < 0) {
      next.insert(0, recommendation);
    } else {
      next[index] = recommendation;
    }
    recommendations = next;
  }

  List<TaskRecommendation> _mergeRecommendations(
      List<TaskRecommendation> items) {
    final seen = <String>{};
    final unique = <TaskRecommendation>[];
    for (final item in items) {
      if (seen.add(item.id)) unique.add(item);
    }
    unique.sort((left, right) {
      final leftRank = left.isAccepted ? 0 : 1;
      final rightRank = right.isAccepted ? 0 : 1;
      final rankCompare = leftRank.compareTo(rightRank);
      if (rankCompare != 0) return rankCompare;
      return right.score.compareTo(left.score);
    });
    return unique;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('không có quyền')) {
      return 'Không có quyền thực hiện thao tác này.';
    }

    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Bạn cần đăng nhập lại.';
    }

    if (lower.contains('404') || lower.contains('not found')) {
      return 'Không tìm thấy dữ liệu.';
    }

    if (text.trim().isEmpty || lower.contains('exception')) {
      return 'Không thao tác được.';
    }

    return text;
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }

    for (final pageId in _joinedPageIds) {
      unawaited(_realtime.leavePage(pageId));
    }

    _reloadDebounce?.cancel();
    _commentDebounce?.cancel();
    super.dispose();
  }
}
