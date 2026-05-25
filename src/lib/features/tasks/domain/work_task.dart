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
  });

  final String id;
  final String title;
  final String? description;
  final String workspaceId;
  final String? pageId;
  final String status;
  final String priority;
  final String? dueDate;

  factory WorkTask.fromJson(JsonMap json) => WorkTask(
        id: asString(json['id']),
        title: asString(json['title'], 'Untitled task'),
        description: json['description']?.toString(),
        workspaceId: asString(json['workspaceId']),
        pageId: json['pageId']?.toString(),
        status: normalizeTaskStatus(json['status']),
        priority: normalizeTaskPriority(json['priority']),
        dueDate: json['dueDate']?.toString(),
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
