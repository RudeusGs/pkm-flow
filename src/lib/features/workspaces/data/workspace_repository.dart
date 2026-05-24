import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/workspace.dart';

class WorkspaceRepository {
  const WorkspaceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Workspace>> myWorkspaces() {
    return _apiClient.get<List<Workspace>>(
      'me/workspaces',
      query: const {'pageNumber': 1, 'pageSize': 80},
      parser: (json) => parsePagedItems(json, Workspace.fromJson),
    );
  }

  Future<Workspace> createWorkspace({
    required String name,
    String? description,
    String visibility = 'private',
  }) {
    return _apiClient.post<Workspace>(
      'workspaces',
      data: {
        'name': name,
        'description': description,
        'visibility': visibility,
      },
      parser: (json) => Workspace.fromJson(asMap(json)),
    );
  }

  Future<Workspace> updateWorkspace(
    Workspace workspace, {
    required String name,
    String? description,
    String? visibility,
  }) {
    return _apiClient.put<Workspace>(
      'workspaces/${workspace.id}',
      data: {
        'name': name,
        'description': description,
        'visibility': visibility ?? workspace.visibility,
      },
      parser: (json) => Workspace.fromJson(asMap(json)),
    );
  }

  Future<void> deleteWorkspace(String workspaceId) {
    return _apiClient.delete<void>(
      'workspaces/$workspaceId',
      parser: (_) {},
    );
  }

  Future<void> leaveWorkspace(String workspaceId) {
    return _apiClient.post<void>(
      'workspaces/$workspaceId/leave',
      parser: (_) {},
    );
  }

  Future<List<WorkspaceMember>> members(String workspaceId) {
    return _apiClient.get<List<WorkspaceMember>>(
      'workspaces/$workspaceId/members',
      parser: (json) => asMapList(json).map(WorkspaceMember.fromJson).toList(),
    );
  }

  Future<void> inviteByEmail(
    String workspaceId, {
    required String email,
    String role = 'member',
  }) {
    return _apiClient.post<void>(
      'workspaces/$workspaceId/members',
      data: {'email': email, 'role': role},
      parser: (_) {},
    );
  }

  // Alias để tương thích với controller/file cũ.
  Future<void> inviteMember(
    String workspaceId, {
    required String email,
    String role = 'member',
  }) {
    return inviteByEmail(workspaceId, email: email, role: role);
  }

  Future<WorkspaceMember> changeMemberRole(
    String workspaceId,
    String userId,
    String role,
  ) {
    return _apiClient.patch<WorkspaceMember>(
      'workspaces/$workspaceId/members/$userId/role',
      data: {'role': role},
      parser: (json) => WorkspaceMember.fromJson(asMap(json)),
    );
  }

  Future<void> removeMember(String workspaceId, String userId) {
    return _apiClient.delete<void>(
      'workspaces/$workspaceId/members/$userId',
      parser: (_) {},
    );
  }
}
