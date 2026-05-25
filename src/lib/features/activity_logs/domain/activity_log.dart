import '../../../core/utils/json_utils.dart';

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.userName,
    this.userFullName,
    this.userAvatarUrl,
    this.description,
    this.metadataJson,
    this.ipAddress,
    this.occurredAt,
    this.createdDate,
  });

  final String id;
  final String workspaceId;
  final String userId;
  final String? userName;
  final String? userFullName;
  final String? userAvatarUrl;
  final String action;
  final String entityType;
  final String entityId;
  final String? description;
  final String? metadataJson;
  final String? ipAddress;
  final DateTime? occurredAt;
  final DateTime? createdDate;

  factory ActivityLog.fromJson(JsonMap json) => ActivityLog(
        id: asString(json['id']),
        workspaceId: asString(json['workspaceId']),
        userId: asString(json['userId']),
        userName: _optionalString(json['userName']),
        userFullName: _optionalString(json['userFullName']),
        userAvatarUrl: _optionalString(json['userAvatarUrl']),
        action: asString(json['action']),
        entityType: asString(json['entityType']),
        entityId: asString(json['entityId']),
        description: _optionalString(json['description']),
        metadataJson: _optionalString(json['metadataJson']),
        ipAddress: _optionalString(json['ipAddress']),
        occurredAt: _date(json['occurredAt']),
        createdDate: _date(json['createdDate']),
      );

  String get actorName {
    final fullName = userFullName?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final name = userName?.trim();
    if (name != null && name.isNotEmpty) return name;

    return 'Unknown user';
  }

  String get title {
    final text = description?.trim();
    if (text != null && text.isNotEmpty) return text;
    return '${actionLabel(action)} ${entityLabel(entityType).toLowerCase()}';
  }

  static String actionLabel(String value) => switch (value.toLowerCase()) {
        'create' => 'Created',
        'update' => 'Updated',
        'delete' => 'Deleted',
        'archive' => 'Archived',
        'restore' => 'Restored',
        'move' => 'Moved',
        'assign' => 'Assigned',
        'unassign' => 'Unassigned',
        'complete' => 'Completed',
        'reopen' => 'Reopened',
        'login' => 'Logged in',
        'changepermissions' => 'Changed permissions',
        _ => value.isEmpty ? 'Activity' : value,
      };

  static String entityLabel(String value) => switch (value.toLowerCase()) {
        'workspace' => 'Workspace',
        'workspacemember' => 'Workspace member',
        'page' => 'Page',
        'worktask' => 'Task',
        'taskcomment' => 'Task comment',
        'taskassignee' => 'Task assignee',
        'user' => 'User',
        'userpreference' => 'User preference',
        'realtimesession' => 'Realtime session',
        'block' => 'Block',
        _ => value.isEmpty ? 'Item' : value,
      };

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

class ActivityLogPageResult {
  const ActivityLogPageResult({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<ActivityLog> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  factory ActivityLogPageResult.fromJson(JsonMap json) {
    final items = json['items'];
    return ActivityLogPageResult(
      items: items is List
          ? items.map((item) => ActivityLog.fromJson(asMap(item))).toList()
          : const <ActivityLog>[],
      pageNumber: asInt(json['pageNumber'], 1),
      pageSize: asInt(json['pageSize'], 30),
      totalCount: asInt(json['totalCount']),
      totalPages: asInt(json['totalPages']),
    );
  }

  static const empty = ActivityLogPageResult(
    items: <ActivityLog>[],
    pageNumber: 1,
    pageSize: 30,
    totalCount: 0,
    totalPages: 0,
  );
}
