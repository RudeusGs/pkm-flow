import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/task_repository.dart';
import '../domain/work_task.dart';

class TasksController extends ChangeNotifier {
  TasksController({required TaskRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final TaskRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  String? workspaceId;
  List<WorkTask> tasks = const [];
  List<TaskRecommendation> recommendations = const [];
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
      ]);
      tasks = results[0] as List<WorkTask>;
      recommendations = results[1] as List<TaskRecommendation>;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTask({required String pageId, required String title, String? description, String priority = 'medium', String? dueDate}) async {
    final created = await _repository.createTask(pageId, title: title, description: description, priority: priority, dueDate: dueDate);
    tasks = [created, ...tasks];
    notifyListeners();
  }

  Future<void> changeStatus(WorkTask task, String status) async {
    final updated = await _repository.changeStatus(task.id, status);
    tasks = tasks.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
  }

  Future<void> generateAi() async {
    final id = workspaceId;
    if (id == null) return;
    recommendations = await _repository.generateRecommendations(id);
    notifyListeners();
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in ['TaskCreated', 'TaskUpdated', 'TaskDeleted', 'TaskStatusChanged', 'TaskAssigned', 'TaskUnassigned', 'RecommendationCreated']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final id = workspaceId;
        if (id != null && (payload.workspaceId == null || payload.workspaceId == id)) {
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
