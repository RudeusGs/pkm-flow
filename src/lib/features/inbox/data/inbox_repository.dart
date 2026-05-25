import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';

class InboxRepository {
  const InboxRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<NotificationItem>> notifications(
      {bool unreadOnly = false, String? workspaceId}) {
    return _apiClient.get<List<NotificationItem>>(
      'notifications',
      query: {
        'workspaceId': workspaceId,
        'unreadOnly': unreadOnly,
        'pageNumber': 1,
        'pageSize': 80
      },
      parser: (json) => parsePagedItems(json, NotificationItem.fromJson),
    );
  }

  Future<int> unreadNotificationCount({String? workspaceId}) async {
    final result = await _apiClient.get<int>(
      'notifications/unread-count',
      query: {'workspaceId': workspaceId},
      parser: (json) => asInt(asMap(json)['unreadCount']),
    );
    return result;
  }

  Future<void> markNotificationRead(String notificationId) {
    return _apiClient.patch<void>('notifications/$notificationId:read',
        parser: (_) {});
  }

  Future<void> markNotificationUnread(String notificationId) {
    return _apiClient.patch<void>('notifications/$notificationId:unread',
        parser: (_) {});
  }

  Future<void> markAllNotificationsRead({String? workspaceId}) {
    return _apiClient.post<void>('notifications/mark-all-read',
        query: {'workspaceId': workspaceId}, parser: (_) {});
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
      query: const {'pageNumber': 1, 'pageSize': 120},
      parser: (json) => _sortMessagesOldestFirst(
        parsePagedItems(json, MessageItem.fromJson),
      ),
    );
  }

  Future<MessageItem> sendText(String conversationId, String body) {
    return _apiClient.post<MessageItem>(
      'conversations/$conversationId/messages',
      data: {'body': body},
      parser: (json) => MessageItem.fromJson(asMap(json)),
    );
  }

  Future<MessageItem> sendImage(
    String conversationId, {
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    String? caption,
  }) {
    final cleanCaption = caption?.trim();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename:
            fileName.trim().isEmpty ? 'message-image.jpg' : fileName.trim(),
        contentType: _safeMediaType(contentType, fileName),
      ),
      if (cleanCaption != null && cleanCaption.isNotEmpty)
        'caption': cleanCaption,
    });

    return _apiClient.postForm<MessageItem>(
      'conversations/$conversationId/messages/image',
      formData: formData,
      parser: (json) => MessageItem.fromJson(asMap(json)),
    );
  }

  Future<MessageItem> sendWorkspaceShare(String conversationId,
      {required String workspaceId, String role = 'member'}) {
    return _apiClient.post<MessageItem>(
      'conversations/$conversationId/messages/workspace-share',
      data: {'workspaceId': workspaceId, 'role': role},
      parser: (json) => MessageItem.fromJson(asMap(json)),
    );
  }

  Future<Workspace> acceptWorkspaceShare(String messageId) {
    return _apiClient.post<Workspace>(
      'conversations/messages/$messageId/workspace-share/accept',
      parser: (json) => Workspace.fromJson(asMap(json)),
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

  static List<MessageItem> _sortMessagesOldestFirst(List<MessageItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final left = DateTime.tryParse(a.createdDate ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final right = DateTime.tryParse(b.createdDate ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final result = left.compareTo(right);
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return sorted;
  }

  static DioMediaType? _safeMediaType(String? contentType, String fileName) {
    final value = (contentType == null || contentType.trim().isEmpty)
        ? _contentTypeFromFileName(fileName)
        : contentType.trim();

    try {
      return DioMediaType.parse(value);
    } catch (_) {
      return DioMediaType.parse('image/jpeg');
    }
  }

  static String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }
}
