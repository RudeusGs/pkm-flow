import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../../pages/data/page_repository.dart';
import '../../pages/domain/page_item.dart';
import '../data/task_repository.dart';
import '../domain/work_task.dart';

class TasksController extends ChangeNotifier {
  TasksController(
      {required TaskRepository repository,
      required PageRepository pageRepository,
      required RealtimeService realtime})
      : _repository = repository,
        _pageRepository = pageRepository,
        _realtime = realtime;

  final TaskRepository _repository;
  final PageRepository _pageRepository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  String? workspaceId;
  List<WorkTask> tasks = const [];
  List<TaskRecommendation> recommendations = const [];
  List<PageItem> pages = const [];
  WorkTask? selectedTask;
  List<TaskComment> comments = const [];
  bool isLoading = false;
  String? error;

  Future<void> load(String nextWorkspaceId) async {
    workspaceId = nextWorkspaceId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.workspaceTasks(nextWorkspaceId),
        _repository.recommendations(workspaceId: nextWorkspaceId),
        _pageRepository.pages(nextWorkspaceId),
      ]);
      tasks = results[0] as List<WorkTask>;
      recommendations = results[1] as List<TaskRecommendation>;
      pages = results[2] as List<PageItem>;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeStatus(WorkTask task, String status) async {
    final updated = await _repository.changeStatus(task.id, status);
    tasks =
        tasks.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
  }

  Future<void> createTask({
    required String pageId,
    required String title,
    String? description,
    String priority = 'medium',
    String? dueDate,
  }) async {
    final created = await _repository.createTask(pageId,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate);
    tasks = [created, ...tasks];
    notifyListeners();
  }

  Future<void> updateTask(
    WorkTask task, {
    required String title,
    String? description,
    String priority = 'medium',
    String? dueDate,
  }) async {
    final updated = await _repository.updateTask(task,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate);
    tasks =
        tasks.map((item) => item.id == updated.id ? updated : item).toList();
    if (selectedTask?.id == updated.id) selectedTask = updated;
    notifyListeners();
  }

  Future<void> deleteTask(WorkTask task) async {
    await _repository.deleteTask(task.id);
    tasks = tasks.where((item) => item.id != task.id).toList();
    if (selectedTask?.id == task.id) {
      selectedTask = null;
      comments = const [];
    }
    notifyListeners();
  }

  Future<void> generateAi() async {
    final id = workspaceId;
    if (id == null) return;
    recommendations = await _repository.generateRecommendations(id);
    notifyListeners();
  }

  Future<void> acceptRecommendation(TaskRecommendation recommendation) async {
    await _repository.acceptRecommendation(recommendation.id);
    recommendations =
        recommendations.where((item) => item.id != recommendation.id).toList();
    final id = workspaceId;
    if (id != null) tasks = await _repository.workspaceTasks(id);
    notifyListeners();
  }

  Future<void> rejectRecommendation(TaskRecommendation recommendation) async {
    await _repository.rejectRecommendation(recommendation.id);
    recommendations =
        recommendations.where((item) => item.id != recommendation.id).toList();
    notifyListeners();
  }

  Future<void> openTask(WorkTask task) async {
    selectedTask = task;
    comments = await _repository.comments(task.id);
    notifyListeners();
  }

  Future<void> addComment(String content) async {
    final task = selectedTask;
    if (task == null || content.trim().isEmpty) return;
    final comment = await _repository.addComment(task.id, content.trim());
    comments = [...comments, comment];
    notifyListeners();
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
      'RecommendationCreated'
    ]) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final id = workspaceId;
        if (id != null &&
            (payload.workspaceId == null || payload.workspaceId == id)) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () => load(id));
        }
      }));
    }
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    super.dispose();
  }
}
