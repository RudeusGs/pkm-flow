class Endpoints {
  const Endpoints._();

  // Auth
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';

  // Me
  static const String myRoles = '/api/v1/me/roles';
  static const String myWorkspaces = '/api/v1/me/workspaces';

  // Workspaces
  static const String workspaces = '/api/v1/workspaces';

  static String workspaceById(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId';
  }

  static String workspaceMembers(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/members';
  }

  static String workspaceMemberRole(String workspaceId, String userId) {
    return '/api/v1/workspaces/$workspaceId/members/$userId/role';
  }

  static String workspaceMemberById(String workspaceId, String userId) {
    return '/api/v1/workspaces/$workspaceId/members/$userId';
  }

  // Pages
  static String workspacePages(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/pages';
  }

  static String searchWorkspacePages(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/pages:search';
  }

  static String pageById(String pageId) {
    return '/api/v1/pages/$pageId';
  }

  static String pageSubpages(String pageId) {
    return '/api/v1/pages/$pageId/subpages';
  }

  static String pagePresence(String pageId) {
    return '/api/v1/pages/$pageId/presence';
  }

  // Blocks
  static String pageBlocks(String pageId) {
    return '/api/v1/pages/$pageId/blocks';
  }

  static String blockById(String blockId) {
    return '/api/v1/blocks/$blockId';
  }

  static String blockMove(String blockId) {
    return '/api/v1/blocks/$blockId:move';
  }

  static String blockLease(String blockId) {
    return '/api/v1/blocks/$blockId/edit-lease';
  }

  static String acquireBlockLease(String blockId) {
    return '/api/v1/blocks/$blockId:acquire-edit-lease';
  }

  static String renewBlockLease(String blockId) {
    return '/api/v1/blocks/$blockId:renew-edit-lease';
  }

  static String releaseBlockLease(String blockId) {
    return '/api/v1/blocks/$blockId:release-edit-lease';
  }

  // Tasks
  static String pageTasks(String pageId) {
    return '/api/v1/pages/$pageId/tasks';
  }

  static String workspaceTasks(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/tasks';
  }

  static String taskById(String taskId) {
    return '/api/v1/tasks/$taskId';
  }

  static String taskAssignees(String taskId) {
    return '/api/v1/tasks/$taskId/assignees';
  }

  static String taskAssigneeById(String taskId, String userId) {
    return '/api/v1/tasks/$taskId/assignees/$userId';
  }

  static String changeTaskStatus(String taskId) {
    return '/api/v1/tasks/$taskId:change-status';
  }

  // Task comments
  static String taskComments(String taskId) {
    return '/api/v1/tasks/$taskId/comments';
  }

  static String taskCommentById(String commentId) {
    return '/api/v1/task-comments/$commentId';
  }

  static String restoreTaskComment(String commentId) {
    return '/api/v1/task-comments/$commentId:restore';
  }

  // Notifications
  static const String notifications = '/api/v1/notifications';
  static const String notificationUnreadCount =
      '/api/v1/notifications/unread-count';
  static const String markAllNotificationsRead =
      '/api/v1/notifications/mark-all-read';

  static String markNotificationRead(String notificationId) {
    return '/api/v1/notifications/$notificationId:read';
  }

  static String markNotificationUnread(String notificationId) {
    return '/api/v1/notifications/$notificationId:unread';
  }

  static String notificationById(String notificationId) {
    return '/api/v1/notifications/$notificationId';
  }

  // Recommendations
  static const String taskRecommendations = '/api/v1/task-recommendations';

  static String generateTaskRecommendations(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/task-recommendations:generate';
  }

  static String acceptTaskRecommendation(String recommendationId) {
    return '/api/v1/task-recommendations/$recommendationId:accept';
  }

  static String rejectTaskRecommendation(String recommendationId) {
    return '/api/v1/task-recommendations/$recommendationId:reject';
  }

  static String completeTaskRecommendation(String recommendationId) {
    return '/api/v1/task-recommendations/$recommendationId:complete';
  }

  static String recommendationPreference(String workspaceId) {
    return '/api/v1/workspaces/$workspaceId/task-recommendation-preference';
  }

  // SignalR
  static const String collaborationHub = '/hubs/collaboration';
}
