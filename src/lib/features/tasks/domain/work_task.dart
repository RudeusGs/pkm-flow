import '../../../core/utils/json_utils.dart';

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
        status: asString(json['status'], 'todo'),
        priority: asString(json['priority'], 'medium'),
        dueDate: json['dueDate']?.toString(),
      );

  WorkTask copyWith({
    String? title,
    String? description,
    String? status,
    String? priority,
    String? dueDate,
  }) {
    return WorkTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      workspaceId: workspaceId,
      pageId: pageId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class TaskRecommendation {
  const TaskRecommendation(
      {required this.id,
      required this.taskTitle,
      this.reason,
      this.priority = 'medium',
      this.status = 'pending'});

  final String id;
  final String taskTitle;
  final String? reason;
  final String priority;
  final String status;

  factory TaskRecommendation.fromJson(JsonMap json) => TaskRecommendation(
        id: asString(json['id']),
        taskTitle:
            asString(json['taskTitle'], asString(json['title'], 'Task gợi ý')),
        reason: json['reason']?.toString(),
        priority: asString(json['taskPriority'] ?? json['priority'], 'medium'),
        status: asString(json['status'], 'pending'),
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
  });

  final String id;
  final String taskId;
  final String userId;
  final String content;
  final String? parentId;
  final bool isDeleted;
  final String? createdDate;

  factory TaskComment.fromJson(JsonMap json) => TaskComment(
        id: asString(json['id']),
        taskId: asString(json['taskId']),
        userId: asString(json['userId']),
        parentId: json['parentId']?.toString(),
        content: asString(json['content']),
        isDeleted: asBool(json['isDeleted']),
        createdDate: json['createdDate']?.toString(),
      );
}
