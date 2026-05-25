import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/activity_log.dart';

class ActivityLogRepository {
  const ActivityLogRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ActivityLogPageResult> workspaceLogs(
    String workspaceId, {
    String? action,
    String? entityType,
    String? search,
    int pageNumber = 1,
    int pageSize = 30,
  }) {
    return _apiClient.get<ActivityLogPageResult>(
      'workspaces/$workspaceId/activity-logs',
      query: {
        'action': action,
        'entityType': entityType,
        'search': search,
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
      parser: (json) => ActivityLogPageResult.fromJson(asMap(json)),
    );
  }
}
