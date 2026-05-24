import '../../../core/utils/json_utils.dart';

class NotificationItem {
  const NotificationItem(
      {required this.id,
      required this.title,
      required this.message,
      this.isRead = false,
      this.createdDate});

  final String id;
  final String title;
  final String message;
  final bool isRead;
  final String? createdDate;

  factory NotificationItem.fromJson(JsonMap json) => NotificationItem(
        id: asString(json['id']),
        title: asString(json['title'], 'Notification'),
        message: asString(json['message']),
        isRead: asBool(json['isRead']),
        createdDate: json['createdDate']?.toString(),
      );
}

class Conversation {
  const Conversation(
      {required this.id,
      required this.otherUserName,
      required this.otherFullName,
      this.otherAvatarUrl,
      this.lastMessagePreview,
      this.unreadCount = 0,
      this.lastMessageAtUtc});

  final String id;
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
      otherUserName: asString(other['userName'], 'user'),
      otherFullName: asString(
          other['fullName'], asString(other['userName'], 'Người dùng')),
      otherAvatarUrl: other['avatarUrl']?.toString(),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      unreadCount: asInt(json['unreadCount']),
      lastMessageAtUtc: json['lastMessageAtUtc']?.toString(),
    );
  }
}

class MessageItem {
  const MessageItem(
      {required this.id,
      required this.conversationId,
      required this.body,
      this.isMine = false,
      this.createdDate});

  final String id;
  final String conversationId;
  final String body;
  final bool isMine;
  final String? createdDate;

  factory MessageItem.fromJson(JsonMap json) => MessageItem(
        id: asString(json['id']),
        conversationId: asString(json['conversationId']),
        body: asString(json['body'], asString(json['textContent'])),
        isMine: asBool(json['isMine']),
        createdDate: json['createdDate']?.toString(),
      );
}
