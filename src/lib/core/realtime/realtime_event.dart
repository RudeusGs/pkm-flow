import '../utils/json_utils.dart';

class RealtimeEvent {
  const RealtimeEvent({
    required this.name,
    this.workspaceId,
    this.pageId,
    this.taskId,
    this.blockId,
    this.conversationId,
    this.userId,
    this.actorId,
    this.senderUserId,
    this.recipientUserId,
    this.revision,
    this.payload,
  });

  final String name;
  final String? workspaceId;
  final String? pageId;
  final String? taskId;
  final String? blockId;
  final String? conversationId;
  final String? userId;
  final String? actorId;
  final String? senderUserId;
  final String? recipientUserId;
  final int? revision;
  final Object? payload;

  factory RealtimeEvent.fromSignalR(String eventName, List<Object?>? args) {
    final raw = args == null || args.isEmpty
        ? null
        : args.length == 1
            ? args.first
            : args;
    final normalized = normalizeJsonKeys(raw);
    final map = asMap(normalized);
    final payload = map.containsKey('payload')
        ? normalizeJsonKeys(map['payload'])
        : normalized;
    final payloadMap = asMap(payload);

    String? readString(String key) {
      final value = map[key] ?? payloadMap[key];
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    int? readInt(String key) {
      final value = map[key] ?? payloadMap[key];
      if (value == null) return null;
      final parsed = asInt(value, -1);
      return parsed < 0 ? null : parsed;
    }

    return RealtimeEvent(
      name: asString(map['eventName'], eventName),
      workspaceId: readString('workspaceId'),
      pageId: readString('pageId'),
      taskId: readString('taskId'),
      blockId: readString('blockId'),
      conversationId: readString('conversationId'),
      userId: readString('userId'),
      actorId: readString('actorId'),
      senderUserId: readString('senderUserId'),
      recipientUserId: readString('recipientUserId'),
      revision: readInt('revision'),
      payload: payload,
    );
  }

  JsonMap get payloadMap => normalizedMap(payload);
}
