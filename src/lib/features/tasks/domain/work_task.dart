import '../../../core/utils/json_utils.dart';

String normalizeTaskStatus(Object? value) {
  final raw = asString(value, 'todo').trim().toLowerCase();
  final normalized = raw.replaceAll('-', '_').replaceAll(' ', '_');
  return switch (normalized) {
    'to_do' || 'todo' => 'todo',
    'doing' || 'in_progress' => 'doing',
    'done' || 'completed' => 'done',
    _ => raw.isEmpty ? 'todo' : raw,
  };
}

String normalizeTaskPriority(Object? value) {
  final raw = asString(value, 'medium').trim().toLowerCase();
  return switch (raw) {
    'low' || 'medium' || 'high' => raw,
    _ => raw.isEmpty ? 'medium' : raw,
  };
}

String normalizeRecommendationStatus(Object? value) {
  final raw = asString(value, 'pending').trim().toLowerCase();
  return raw.isEmpty ? 'pending' : raw;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _normalizeUserId(Object? value) => value?.toString().trim().toLowerCase() ?? '';

bool _sameUserId(Object? left, Object? right) {
  final a = _normalizeUserId(left);
  final b = _normalizeUserId(right);
  return a.isNotEmpty && b.isNotEmpty && a == b;
}

List<String> _parseAssigneeUserIds(Object? value) {
  if (value is! List) return const <String>[];

  final ids = <String>[];
  for (final item in value) {
    if (item is Map) {
      final map = asMap(item);
      final id = asString(map['userId'] ?? map['id']);
      if (id.trim().isNotEmpty) ids.add(id.trim());
      continue;
    }

    final id = item?.toString().trim() ?? '';
    if (id.isNotEmpty) ids.add(id);
  }

  return ids.toSet().toList();
}

class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    this.description,
    required this.workspaceId,
    this.pageId,
    this.status = 'todo',
    this.priority = 'medium',
    this.dueDate,
    this.createdById = '',
    this.lastModifiedById,
    this.createdDate,
    this.updatedDate,
    this.assigneeUserIds = const <String>[],
  });

  final String id;
  final String title;
  final String? description;
  final String workspaceId;
  final String? pageId;
  final String status;
  final String priority;
  final String? dueDate;
  final String createdById;
  final String? lastModifiedById;
  final String? createdDate;
  final String? updatedDate;
  final List<String> assigneeUserIds;

  bool get isDone => status == 'done';
  bool get hasAssignees => assigneeUserIds.isNotEmpty;

  bool isAssignedTo(String? userId) {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;
    return assigneeUserIds.any((assigneeId) => _sameUserId(assigneeId, id));
  }

  bool isCreatedBy(String? userId) => _sameUserId(createdById, userId);

  bool isMineForStatus(String? userId) {
    final id = _normalizeUserId(userId);
    if (id.isEmpty) return false;

    // Nếu task đã được gán, chỉ assignee được đổi trạng thái.
    if (assigneeUserIds.isNotEmpty) return isAssignedTo(id);

    // Task chưa gán ai thì người tạo task được xử lý trạng thái.
    return isCreatedBy(id);
  }

  bool canChangeStatusBy(String? userId) => !isDone && isMineForStatus(userId);

  String statusLockReason(String? userId) {
    if (isDone) return 'Task đã hoàn thành nên không thể đổi lại.';
    if (!isMineForStatus(userId)) {
      return 'Chỉ người được giao task mới được đổi trạng thái.';
    }
    return 'Không thao tác được.';
  }

  WorkTask copyWith({
    String? id,
    String? title,
    String? description,
    String? workspaceId,
    String? pageId,
    String? status,
    String? priority,
    String? dueDate,
    String? createdById,
    String? lastModifiedById,
    String? createdDate,
    String? updatedDate,
    List<String>? assigneeUserIds,
  }) {
    return WorkTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      workspaceId: workspaceId ?? this.workspaceId,
      pageId: pageId ?? this.pageId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdById: createdById ?? this.createdById,
      lastModifiedById: lastModifiedById ?? this.lastModifiedById,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      assigneeUserIds: assigneeUserIds ?? this.assigneeUserIds,
    );
  }

  factory WorkTask.fromJson(JsonMap json) => WorkTask(
        id: asString(json['id']),
        title: asString(json['title'], 'Untitled task'),
        description: json['description']?.toString(),
        workspaceId: asString(json['workspaceId']),
        pageId: json['pageId']?.toString(),
        status: normalizeTaskStatus(json['status']),
        priority: normalizeTaskPriority(json['priority']),
        dueDate: json['dueDate']?.toString(),
        createdById: asString(json['createdById'] ?? json['createdByUserId']),
        lastModifiedById:
            (json['lastModifiedById'] ?? json['updatedById'])?.toString(),
        createdDate: json['createdDate']?.toString(),
        updatedDate: json['updatedDate']?.toString(),
        assigneeUserIds: _parseAssigneeUserIds(
          json['assignees'] ?? json['assigneeUserIds'] ?? json['assignedUserIds'],
        ),
      );
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    this.parentId,
    this.isDeleted = false,
    this.createdDate,
    this.updatedDate,
    this.deletedDate,
  });

  final String id;
  final String taskId;
  final String userId;
  final String? parentId;
  final String content;
  final bool isDeleted;
  final String? createdDate;
  final String? updatedDate;
  final String? deletedDate;

  bool get isReply => parentId != null && parentId!.trim().isNotEmpty;

  factory TaskComment.fromJson(JsonMap json) => TaskComment(
        id: asString(json['id']),
        taskId: asString(json['taskId']),
        userId: asString(json['userId']),
        parentId: json['parentId']?.toString(),
        content: asString(json['content']),
        isDeleted: asBool(json['isDeleted']),
        createdDate: json['createdDate']?.toString(),
        updatedDate: json['updatedDate']?.toString(),
        deletedDate: json['deletedDate']?.toString(),
      );
}

class TaskRecommendation {
  const TaskRecommendation({
    required this.id,
    required this.taskId,
    required this.workspaceId,
    this.pageId,
    required this.taskTitle,
    this.taskDescription,
    this.reason,
    this.priority = 'medium',
    this.taskStatus = 'todo',
    this.taskDueDate,
    this.score = 0,
    this.status = 'pending',
    this.expiresAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.createdDate,
    this.updatedDate,
  });

  final String id;
  final String taskId;
  final String workspaceId;
  final String? pageId;
  final String taskTitle;
  final String? taskDescription;
  final String? reason;
  final String priority;
  final String taskStatus;
  final String? taskDueDate;
  final double score;
  final String status;
  final String? expiresAt;
  final String? acceptedAt;
  final String? rejectedAt;
  final String? completedAt;
  final String? createdDate;
  final String? updatedDate;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';

  factory TaskRecommendation.fromJson(JsonMap json) => TaskRecommendation(
        id: asString(json['id']),
        taskId: asString(json['taskId']),
        workspaceId: asString(json['workspaceId']),
        pageId: json['pageId']?.toString(),
        taskTitle:
            asString(json['taskTitle'], asString(json['title'], 'Task gợi ý')),
        taskDescription: json['taskDescription']?.toString() ??
            json['description']?.toString(),
        reason: json['reason']?.toString(),
        priority:
            normalizeTaskPriority(json['taskPriority'] ?? json['priority']),
        taskStatus: normalizeTaskStatus(json['taskStatus'] ?? json['status']),
        taskDueDate:
            json['taskDueDate']?.toString() ?? json['dueDate']?.toString(),
        score: asDouble(json['score']),
        status: normalizeRecommendationStatus(json['status']),
        expiresAt: json['expiresAt']?.toString(),
        acceptedAt: json['acceptedAt']?.toString(),
        rejectedAt: json['rejectedAt']?.toString(),
        completedAt: json['completedAt']?.toString(),
        createdDate: json['createdDate']?.toString(),
        updatedDate: json['updatedDate']?.toString(),
      );
}

class TaskRecommendationPreference {
  const TaskRecommendationPreference({
    required this.id,
    required this.userId,
    required this.workspaceId,
    this.workDayStartHour = 8,
    this.workDayEndHour = 18,
    this.preferredDaysOfWeek = const [1, 2, 3, 4, 5],
    this.maxRecommendationsPerSession = 3,
    this.minPriorityForRecommendation = 'medium',
    this.recommendationSensitivity = 50,
    this.recommendationIntervalMinutes = 30,
    this.enableAutoRecommendation = true,
  });

  final String id;
  final String userId;
  final String workspaceId;
  final int workDayStartHour;
  final int workDayEndHour;
  final List<int> preferredDaysOfWeek;
  final int maxRecommendationsPerSession;
  final String minPriorityForRecommendation;
  final int recommendationSensitivity;
  final int recommendationIntervalMinutes;
  final bool enableAutoRecommendation;

  factory TaskRecommendationPreference.fromJson(JsonMap json) {
    final days = json['preferredDaysOfWeek'];
    return TaskRecommendationPreference(
      id: asString(json['id']),
      userId: asString(json['userId']),
      workspaceId: asString(json['workspaceId']),
      workDayStartHour: asInt(json['workDayStartHour'], 8),
      workDayEndHour: asInt(json['workDayEndHour'], 18),
      preferredDaysOfWeek: days is List
          ? days
              .map((item) => asInt(item, -1))
              .where((day) => day >= 0)
              .toList()
          : const [1, 2, 3, 4, 5],
      maxRecommendationsPerSession:
          asInt(json['maxRecommendationsPerSession'], 3),
      minPriorityForRecommendation:
          normalizeTaskPriority(json['minPriorityForRecommendation']),
      recommendationSensitivity: asInt(json['recommendationSensitivity'], 50),
      recommendationIntervalMinutes:
          asInt(json['recommendationIntervalMinutes'], 30),
      enableAutoRecommendation: asBool(json['enableAutoRecommendation'], true),
    );
  }

  TaskRecommendationPreference copyWith({
    int? workDayStartHour,
    int? workDayEndHour,
    List<int>? preferredDaysOfWeek,
    int? maxRecommendationsPerSession,
    String? minPriorityForRecommendation,
    int? recommendationSensitivity,
    int? recommendationIntervalMinutes,
    bool? enableAutoRecommendation,
  }) {
    return TaskRecommendationPreference(
      id: id,
      userId: userId,
      workspaceId: workspaceId,
      workDayStartHour: workDayStartHour ?? this.workDayStartHour,
      workDayEndHour: workDayEndHour ?? this.workDayEndHour,
      preferredDaysOfWeek: preferredDaysOfWeek ?? this.preferredDaysOfWeek,
      maxRecommendationsPerSession:
          maxRecommendationsPerSession ?? this.maxRecommendationsPerSession,
      minPriorityForRecommendation:
          minPriorityForRecommendation ?? this.minPriorityForRecommendation,
      recommendationSensitivity:
          recommendationSensitivity ?? this.recommendationSensitivity,
      recommendationIntervalMinutes:
          recommendationIntervalMinutes ?? this.recommendationIntervalMinutes,
      enableAutoRecommendation:
          enableAutoRecommendation ?? this.enableAutoRecommendation,
    );
  }

  JsonMap toRequestJson() => {
        'workDayStartHour': workDayStartHour,
        'workDayEndHour': workDayEndHour,
        'preferredDaysOfWeek': preferredDaysOfWeek,
        'maxRecommendationsPerSession': maxRecommendationsPerSession,
        'minPriorityForRecommendation': minPriorityForRecommendation,
        'recommendationSensitivity': recommendationSensitivity,
        'recommendationIntervalMinutes': recommendationIntervalMinutes,
        'enableAutoRecommendation': enableAutoRecommendation,
      };
}
