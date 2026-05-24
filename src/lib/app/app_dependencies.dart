import '../core/network/api_client.dart';
import '../core/realtime/realtime_service.dart';
import '../core/storage/auth_token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/inbox/data/inbox_repository.dart';
import '../features/pages/data/page_repository.dart';
import '../features/social/data/social_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../features/workspaces/data/workspace_repository.dart';

class AppDependencies {
  const AppDependencies({
    required this.tokenStore,
    required this.apiClient,
    required this.realtime,
    required this.authRepository,
    required this.workspaceRepository,
    required this.pageRepository,
    required this.taskRepository,
    required this.inboxRepository,
    required this.socialRepository,
  });

  final AuthTokenStore tokenStore;
  final ApiClient apiClient;
  final RealtimeService realtime;
  final AuthRepository authRepository;
  final WorkspaceRepository workspaceRepository;
  final PageRepository pageRepository;
  final TaskRepository taskRepository;
  final InboxRepository inboxRepository;
  final SocialRepository socialRepository;

  factory AppDependencies.create() {
    final tokenStore = AuthTokenStore();
    final apiClient = ApiClient(tokenStore: tokenStore);
    final realtime = RealtimeService(tokenStore: tokenStore);

    return AppDependencies(
      tokenStore: tokenStore,
      apiClient: apiClient,
      realtime: realtime,
      authRepository: AuthRepository(apiClient: apiClient, tokenStore: tokenStore),
      workspaceRepository: WorkspaceRepository(apiClient: apiClient),
      pageRepository: PageRepository(apiClient: apiClient),
      taskRepository: TaskRepository(apiClient: apiClient),
      inboxRepository: InboxRepository(apiClient: apiClient),
      socialRepository: SocialRepository(apiClient: apiClient),
    );
  }
}
