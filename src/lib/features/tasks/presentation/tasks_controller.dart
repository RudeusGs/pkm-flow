import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/task_repository.dart';
import '../domain/work_task.dart';

class TasksController extends ChangeNotifier {
  TasksController(
      {required TaskRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final TaskRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Timer? _debounce;

  String? workspaceId;
  List<WorkTask> tasks = const [];
  List<TaskRecommendation> recommendations = const [];
  TaskRecommendationPreference? preference;
  bool isLoading = false;
  bool isGenerating = false;
  bool isSavingPreference = false;
  String? error;

  Future<void> load(String nextWorkspaceId) async {
    workspaceId = nextWorkspaceId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.workspaceTasks(nextWorkspaceId),
        _repository.activeRecommendations(nextWorkspaceId),
        _repository.recommendationPreference(nextWorkspaceId),
      ]);
      tasks = results[0] as List<WorkTask>;
      recommendations = results[1] as List<TaskRecommendation>;
      preference = results[2] as TaskRecommendationPreference;
      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTask(
      {required String pageId,
      required String title,
      String? description,
      String priority = 'medium',
      String? dueDate}) async {
    final created = await _repository.createTask(pageId,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate);
    tasks = [created, ...tasks];
    notifyListeners();
  }

  Future<void> changeStatus(WorkTask task, String status) async {
    final updated = await _repository.changeStatus(task.id, status);
    tasks =
        tasks.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
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
      error = err.toString();
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
      error = err.toString();
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
      }
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = err.toString();
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
      error = err.toString();
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
      }
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = err.toString();
      notifyListeners();
      return false;
    }
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

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    super.dispose();
  }
}
