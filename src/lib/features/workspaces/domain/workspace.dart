import '../../../core/utils/json_utils.dart';

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    this.description,
    this.visibility = 'private',
    this.currentUserRole = '',
    this.canWrite = true,
    this.canManageMembers = false,
  });

  final String id;
  final String name;
  final String? description;
  final String visibility;
  final String currentUserRole;
  final bool canWrite;
  final bool canManageMembers;

  factory Workspace.fromJson(JsonMap json) => Workspace(
        id: asString(json['id']),
        name: asString(json['name'], 'Untitled workspace'),
        description: json['description']?.toString(),
        visibility: asString(json['visibility'], 'private'),
        currentUserRole: asString(json['currentUserRole']),
        canWrite: asBool(json['canWrite'], true),
        canManageMembers: asBool(json['canManageMembers'], false),
      );
}

class WorkspaceMember {
  const WorkspaceMember({
    required this.userId,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isOwner,
    required this.isCurrentUser,
  });

  final String userId;
  final String userName;
  final String fullName;
  final String email;
  final String role;
  final bool isOwner;
  final bool isCurrentUser;

  factory WorkspaceMember.fromJson(JsonMap json) => WorkspaceMember(
        userId: asString(json['userId']),
        userName: asString(json['userName']),
        fullName:
            asString(json['fullName'], asString(json['userName'], 'Member')),
        email: asString(json['email']),
        role: asString(json['role']),
        isOwner: asBool(json['isOwner']),
        isCurrentUser: asBool(json['isCurrentUser']),
      );
}
