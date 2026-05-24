import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/work_task.dart';

class TaskRepository {
  const TaskRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<WorkTask>> workspaceTasks(String workspaceId,
      {String? status, String? keyword}) {
    return _apiClient.get<List<WorkTask>>(
      'workspaces/$workspaceId/tasks',
      query: {
        'status': status,
        'keyword': keyword,
        'includeCompleted': true,
        'pageNumber': 1,
        'pageSize': 100
      },
      parser: (json) => parsePagedItems(json, WorkTask.fromJson),
    );
  }

  Future<WorkTask> createTask(String pageId,
      {required String title,
      String? description,
      String priority = 'medium',
      String? dueDate}) {
    return _apiClient.post<WorkTask>(
      'pages/$pageId/tasks',
      data: {
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate
      },
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<WorkTask> updateTask(
    WorkTask task, {
    required String title,
    String? description,
    String priority = 'medium',
    String? dueDate,
  }) {
    return _apiClient.patch<WorkTask>(
      'tasks/${task.id}',
      data: {
        'pageId': task.pageId,
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate,
      },
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<void> deleteTask(String taskId) {
    return _apiClient.delete<void>('tasks/$taskId', parser: (_) {});
  }

  Future<WorkTask> changeStatus(String taskId, String status) {
    return _apiClient.post<WorkTask>(
      'tasks/$taskId:change-status',
      data: {'status': status},
      parser: (json) => WorkTask.fromJson(asMap(json)),
    );
  }

  Future<List<TaskRecommendation>> recommendations(
      {String? workspaceId, String status = 'pending'}) {
    return _apiClient.get<List<TaskRecommendation>>(
      'task-recommendations',
      query: {
        'workspaceId': workspaceId,
        'status': status,
        'pageNumber': 1,
        'pageSize': 30
      },
      parser: (json) => parsePagedItems(json, TaskRecommendation.fromJson),
    );
  }

  Future<List<TaskRecommendation>> generateRecommendations(String workspaceId,
      {String? pageId}) {
    return _apiClient.post<List<TaskRecommendation>>(
      'workspaces/$workspaceId/task-recommendations:generate',
      data: {'pageId': pageId, 'force': true},
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

  Future<TaskRecommendation> acceptRecommendation(String recommendationId) {
    return _apiClient.post<TaskRecommendation>(
      'task-recommendations/$recommendationId:accept',
      parser: (json) => TaskRecommendation.fromJson(asMap(json)),
    );
  }

  Future<void> rejectRecommendation(String recommendationId) {
    return _apiClient.post<void>(
        'task-recommendations/$recommendationId:reject',
        parser: (_) {});
  }

  Future<void> completeRecommendation(String recommendationId,
      {String? notes}) {
    return _apiClient.post<void>(
      'task-recommendations/$recommendationId:complete',
      data: {'notes': notes},
      parser: (_) {},
    );
  }

  Future<List<TaskComment>> comments(String taskId) {
    return _apiClient.get<List<TaskComment>>(
      'tasks/$taskId/comments',
      query: const {'pageNumber': 1, 'pageSize': 100},
      parser: (json) => parsePagedItems(json, TaskComment.fromJson),
    );
  }

  Future<TaskComment> addComment(String taskId, String content) {
    return _apiClient.post<TaskComment>(
      'tasks/$taskId/comments',
      data: {'content': content},
      parser: (json) => TaskComment.fromJson(asMap(json)),
    );
  }
}
