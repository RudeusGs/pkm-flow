import 'dart:convert';

import '../../../core/utils/json_utils.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = '',
    this.referenceId,
    this.referenceType,
    this.workspaceId,
    this.isRead = false,
    this.createdDate,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final String? workspaceId;
  final bool isRead;
  final String? createdDate;

  factory NotificationItem.fromJson(JsonMap json) => NotificationItem(
        id: asString(json['id']),
        title: asString(json['title'], 'Notification'),
        message: asString(json['message']),
        type: asString(json['type']),
        referenceId: json['referenceId']?.toString(),
        referenceType: json['referenceType']?.toString(),
        workspaceId: json['workspaceId']?.toString(),
        isRead: asBool(json['isRead']),
        createdDate: json['createdDate']?.toString(),
      );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherFullName,
    this.otherAvatarUrl,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.lastMessageAtUtc,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String otherFullName;
  final String? otherAvatarUrl;
  final String? lastMessagePreview;
  final int unreadCount;
  final String? lastMessageAtUtc;

  factory Conversation.fromJson(JsonMap json) {
    final other = asMap(json['otherUser']);
    return Conversation(
      id: asString(json['id']),
      otherUserId: asString(other['id'] ?? other['userId']),
      otherUserName: asString(other['userName'], 'user'),
      otherFullName: asString(other['fullName'], asString(other['userName'], 'Người dùng')),
      otherAvatarUrl: other['avatarUrl']?.toString(),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      unreadCount: asInt(json['unreadCount']),
      lastMessageAtUtc: json['lastMessageAtUtc']?.toString(),
    );
  }

  Conversation copyWith({
    String? id,
    String? otherUserId,
    String? otherUserName,
    String? otherFullName,
    String? otherAvatarUrl,
    String? lastMessagePreview,
    int? unreadCount,
    String? lastMessageAtUtc,
  }) {
    return Conversation(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherFullName: otherFullName ?? this.otherFullName,
      otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAtUtc: lastMessageAtUtc ?? this.lastMessageAtUtc,
    );
  }
}

class WorkspaceSharePayload {
  const WorkspaceSharePayload({
    required this.workspaceId,
    required this.workspaceName,
    this.workspaceDescription,
    this.workspaceVisibility = 'private',
    this.grantedRole = 'viewer',
    this.sharedByUserId = '',
    this.sharedByDisplayName = '',
    this.sharedAtUtc = '',
  });

  final String workspaceId;
  final String workspaceName;
  final String? workspaceDescription;
  final String workspaceVisibility;
  final String grantedRole;
  final String sharedByUserId;
  final String sharedByDisplayName;
  final String sharedAtUtc;

  factory WorkspaceSharePayload.fromJson(JsonMap json) => WorkspaceSharePayload(
        workspaceId: asString(json['workspaceId']),
        workspaceName: asString(json['workspaceName'], 'Không gian'),
        workspaceDescription: json['workspaceDescription']?.toString(),
        workspaceVisibility: asString(json['workspaceVisibility'], 'private'),
        grantedRole: asString(json['grantedRole'], 'viewer'),
        sharedByUserId: asString(json['sharedByUserId']),
        sharedByDisplayName: asString(json['sharedByDisplayName'], 'Một thành viên'),
        sharedAtUtc: asString(json['sharedAtUtc']),
      );
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.conversationId,
    required this.body,
    this.type = 'Text',
    this.imageUrl,
    this.isMine = false,
    this.readAtUtc,
    this.createdDate,
  });

  final String id;
  final String conversationId;
  final String body;
  final String type;
  final String? imageUrl;
  final bool isMine;
  final String? readAtUtc;
  final String? createdDate;

  bool get isWorkspaceShare => type.toLowerCase() == 'workspaceshare' && workspaceShare != null;

  WorkspaceSharePayload? get workspaceShare {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final payload = WorkspaceSharePayload.fromJson(decoded.cast<String, dynamic>());
      if (payload.workspaceId.isEmpty || payload.workspaceName.isEmpty) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  factory MessageItem.fromJson(JsonMap json) => MessageItem(
        id: asString(json['id']),
        conversationId: asString(json['conversationId']),
        type: asString(json['type'], 'Text'),
        body: asString(json['body'], asString(json['textContent'])),
        imageUrl: json['imageUrl']?.toString(),
        isMine: asBool(json['isMine']),
        readAtUtc: json['readAtUtc']?.toString(),
        createdDate: json['createdDate']?.toString(),
      );
}