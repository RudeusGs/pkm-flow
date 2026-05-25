import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/work_task.dart';

class TaskRepository {
  const TaskRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<WorkTask>> workspaceTasks(
    String workspaceId, {
    String? status,
    String? keyword,
  }) {
    return _apiClient.get<List<WorkTask>>(
      'workspaces/$workspaceId/tasks',
      query: {
        'status': status,
        'keyword': keyword,
        'includeCompleted': true,
        'pageNumber': 1,
        'pageSize': 100,
      },
      parser: (json) => parsePagedItems(json, WorkTask.fromJson),
    );
  }

  Future<WorkTask> task(String taskId) {
    return _apiClient.get<WorkTask>(
      'tasks/$taskId',
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<WorkTask> createTask(
    String pageId, {
    required String title,
    String? description,
    String priority = 'medium',
    String? dueDate,
    List<String> assigneeUserIds = const <String>[],
  }) {
    return _apiClient.post<WorkTask>(
      'pages/$pageId/tasks',
      data: {
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate,
        'assigneeUserIds': assigneeUserIds,
      },
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<WorkTask> changeStatus(String taskId, String status) {
    return _apiClient.post<WorkTask>(
      'tasks/$taskId:change-status',
      data: {'status': status},
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<WorkTask> assignTask(String taskId, String userId) {
    return _apiClient.post<WorkTask>(
      'tasks/$taskId/assignees',
      data: {'userId': userId},
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<WorkTask> unassignTask(String taskId, String userId) {
    return _apiClient.delete<WorkTask>(
      'tasks/$taskId/assignees/$userId',
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<List<TaskComment>> taskComments(
    String taskId, {
    bool includeDeleted = true,
  }) {
    return _apiClient.get<List<TaskComment>>(
      'tasks/$taskId/comments',
      query: {
        'pageNumber': 1,
        'pageSize': 100,
        'includeDeleted': includeDeleted,
      },
      parser: (json) => parsePagedItems(json, TaskComment.fromJson),
    );
  }

  Future<TaskComment> createComment(
    String taskId, {
    required String content,
    String? parentId,
  }) {
    return _apiClient.post<TaskComment>(
      'tasks/$taskId/comments',
      data: {
        'content': content,
        if (parentId != null && parentId.trim().isNotEmpty)
          'parentId': parentId.trim(),
      },
      parser: (json) => TaskComment.fromJson(asMap(json)),
    );
  }

  Future<TaskComment> updateComment(String commentId, String content) {
    return _apiClient.patch<TaskComment>(
      'task-comments/$commentId',
      data: {'content': content},
      parser: (json) => TaskComment.fromJson(asMap(json)),
    );
  }

  Future<TaskComment> deleteComment(String commentId) {
    return _apiClient.delete<TaskComment>(
      'task-comments/$commentId',
      parser: (json) => TaskComment.fromJson(asMap(json)),
    );
  }

  Future<TaskComment> restoreComment(String commentId) {
    return _apiClient.post<TaskComment>(
      'task-comments/$commentId:restore',
      parser: (json) => TaskComment.fromJson(asMap(json)),
    );
  }

  Future<List<TaskRecommendation>> recommendations({
    String? workspaceId,
    String? status = 'pending',
    int pageSize = 30,
  }) {
    return _apiClient.get<List<TaskRecommendation>>(
      'task-recommendations',
      query: {
        'workspaceId': workspaceId,
        'status': status,
        'pageNumber': 1,
        'pageSize': pageSize,
      },
      parser: (json) => parsePagedItems(json, TaskRecommendation.fromJson),
    );
  }

  Future<List<TaskRecommendation>> activeRecommendations(
      String workspaceId) async {
    final results = await Future.wait([
      recommendations(
          workspaceId: workspaceId, status: 'accepted', pageSize: 20),
      recommendations(
          workspaceId: workspaceId, status: 'pending', pageSize: 30),
    ]);
    final items = _dedupeRecommendations([...results[0], ...results[1]]);
    items.sort((left, right) {
      final leftRank = left.isAccepted ? 0 : 1;
      final rightRank = right.isAccepted ? 0 : 1;
      final rankCompare = leftRank.compareTo(rightRank);
      if (rankCompare != 0) return rankCompare;
      return right.score.compareTo(left.score);
    });
    return items;
  }

  Future<List<TaskRecommendation>> generateRecommendations(
    String workspaceId, {
    String? pageId,
    bool force = true,
  }) {
    return _apiClient.post<List<TaskRecommendation>>(
      'workspaces/$workspaceId/task-recommendations:generate',
      data: {'pageId': pageId, 'force': force},
      parser: (json) {
        if (json is List) {
          return json
              .map((item) => TaskRecommendation.fromJson(asMap(item)))
              .toList();
        }
        final map = asMap(json);
        final items = map['recommendations'] ?? map['items'];
        if (items is List) {
          return items
              .map((item) => TaskRecommendation.fromJson(asMap(item)))
              .toList();
        }
        return const <TaskRecommendation>[];
      },
    );
  }

  Future<TaskRecommendationPreference> recommendationPreference(
      String workspaceId) {
    return _apiClient.get<TaskRecommendationPreference>(
      'workspaces/$workspaceId/task-recommendation-preference',
      parser: (json) => TaskRecommendationPreference.fromJson(asMap(json)),
    );
  }

  Future<TaskRecommendationPreference> updateRecommendationPreference(
    String workspaceId,
    TaskRecommendationPreference preference,
  ) {
    return _apiClient.put<TaskRecommendationPreference>(
      'workspaces/$workspaceId/task-recommendation-preference',
      data: preference.toRequestJson(),
      parser: (json) => TaskRecommendationPreference.fromJson(asMap(json)),
    );
  }

  Future<TaskRecommendation> acceptRecommendation(String recommendationId) {
    return _apiClient.post<TaskRecommendation>(
      'task-recommendations/$recommendationId:accept',
      parser: (json) => TaskRecommendation.fromJson(asMap(json)),
    );
  }

  Future<TaskRecommendation> rejectRecommendation(String recommendationId) {
    return _apiClient.post<TaskRecommendation>(
      'task-recommendations/$recommendationId:reject',
      parser: (json) => TaskRecommendation.fromJson(asMap(json)),
    );
  }

  Future<TaskRecommendation> completeRecommendation(
    String recommendationId, {
    String? notes,
  }) {
    return _apiClient.post<TaskRecommendation>(
      'task-recommendations/$recommendationId:complete',
      data: {'notes': notes},
      parser: (json) => TaskRecommendation.fromJson(asMap(json)),
    );
  }

  List<TaskRecommendation> _dedupeRecommendations(
      List<TaskRecommendation> recommendations) {
    final seen = <String>{};
    final unique = <TaskRecommendation>[];
    for (final item in recommendations) {
      if (seen.add(item.id)) unique.add(item);
    }
    return unique;
  }
}
