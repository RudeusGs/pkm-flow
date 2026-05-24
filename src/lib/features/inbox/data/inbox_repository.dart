import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/inbox_models.dart';

class InboxRepository {
  const InboxRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<NotificationItem>> notifications({bool unreadOnly = false}) {
    return _apiClient.get<List<NotificationItem>>(
      'notifications',
      query: {'unreadOnly': unreadOnly, 'pageNumber': 1, 'pageSize': 80},
      parser: (json) => parsePagedItems(json, NotificationItem.fromJson),
    );
  }

  Future<void> markAllNotificationsRead({String? workspaceId}) {
    return _apiClient.post<void>('notifications/mark-all-read',
        query: {'workspaceId': workspaceId}, parser: (_) {});
  }

  Future<void> markNotificationRead(String notificationId) {
    return _apiClient.patch<void>('notifications/$notificationId:read',
        parser: (_) {});
  }

  Future<void> markNotificationUnread(String notificationId) {
    return _apiClient.patch<void>('notifications/$notificationId:unread',
        parser: (_) {});
  }

  Future<void> deleteNotification(String notificationId) {
    return _apiClient.delete<void>('notifications/$notificationId',
        parser: (_) {});
  }

  Future<List<Conversation>> conversations() {
    return _apiClient.get<List<Conversation>>(
      'conversations',
      query: const {'pageNumber': 1, 'pageSize': 50},
      parser: (json) => parsePagedItems(json, Conversation.fromJson),
    );
  }

  Future<List<MessageItem>> messages(String conversationId) {
    return _apiClient.get<List<MessageItem>>(
      'conversations/$conversationId/messages',
      query: const {'pageNumber': 1, 'pageSize': 80},
      parser: (json) => parsePagedItems(json, MessageItem.fromJson),
    );
  }

  Future<MessageItem> sendText(String conversationId, String body) {
    return _apiClient.post<MessageItem>(
      'conversations/$conversationId/messages',
      data: {'body': body},
      parser: (json) => MessageItem.fromJson(asMap(json)),
    );
  }

  Future<MessageItem> sendWorkspaceShare(
    String conversationId, {
    required String workspaceId,
    String role = 'viewer',
  }) {
    return _apiClient.post<MessageItem>(
      'conversations/$conversationId/messages/workspace-share',
      data: {'workspaceId': workspaceId, 'role': role},
      parser: (json) => MessageItem.fromJson(asMap(json)),
    );
  }

  Future<void> acceptWorkspaceShare(String messageId) {
    return _apiClient.post<void>(
      'conversations/messages/$messageId/workspace-share/accept',
      parser: (_) {},
    );
  }

  Future<Conversation> createConversation(String recipientUserId) {
    return _apiClient.post<Conversation>(
      'conversations/direct',
      data: {'recipientUserId': recipientUserId},
      parser: (json) => Conversation.fromJson(asMap(json)),
    );
  }

  Future<void> markConversationRead(String conversationId) {
    return _apiClient.post<void>('conversations/$conversationId/read',
        parser: (_) {});
  }
}
