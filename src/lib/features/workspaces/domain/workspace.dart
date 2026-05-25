import '../../../core/utils/json_utils.dart';

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    this.description,
    this.visibility = 'private',
    this.ownerId = '',
    this.currentUserRole = '',
    this.canWrite = true,
    this.canManageMembers = false,
    this.canDeleteWorkspace = false,
  });

  final String id;
  final String name;
  final String? description;
  final String visibility;
  final String ownerId;
  final String currentUserRole;
  final bool canWrite;
  final bool canManageMembers;
  final bool canDeleteWorkspace;

  bool get isOwner => currentUserRole == 'owner';

  Workspace copyWith({
    String? id,
    String? name,
    String? description,
    String? visibility,
    String? ownerId,
    String? currentUserRole,
    bool? canWrite,
    bool? canManageMembers,
    bool? canDeleteWorkspace,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      ownerId: ownerId ?? this.ownerId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      canWrite: canWrite ?? this.canWrite,
      canManageMembers: canManageMembers ?? this.canManageMembers,
      canDeleteWorkspace: canDeleteWorkspace ?? this.canDeleteWorkspace,
    );
  }

  factory Workspace.fromJson(JsonMap json) {
    final role = normalizeWorkspaceRole(json['currentUserRole'] ?? json['role']);
    return Workspace(
      id: asString(json['id']),
      name: asString(json['name'], 'Untitled workspace'),
      description: json['description']?.toString(),
      visibility: asString(json['visibility'], 'private').toLowerCase(),
      ownerId: asString(json['ownerId']),
      currentUserRole: role,
      canWrite: asBool(json['canWrite'], _roleCanWrite(role)),
      canManageMembers: asBool(
        json['canManageMembers'],
        _roleCanManageMembers(role),
      ),
      canDeleteWorkspace: asBool(
        json['canDeleteWorkspace'],
        _roleCanDeleteWorkspace(role),
      ),
    );
  }
}

class WorkspaceMember {
  const WorkspaceMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isOwner,
    this.userName = '',
    this.avatarUrl,
    this.isCurrentUser = false,
  });

  final String userId;
  final String userName;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String role;
  final bool isOwner;
  final bool isCurrentUser;

  factory WorkspaceMember.fromJson(JsonMap json) {
    final role = normalizeWorkspaceRole(json['role']);
    return WorkspaceMember(
        userId: asString(json['userId']),
        userName: asString(json['userName']),
        fullName: asString(
          json['fullName'],
          asString(json['userName'], 'Member'),
        ),
        email: asString(json['email']),
        avatarUrl: json['avatarUrl']?.toString(),
        role: role,
        isOwner: asBool(json['isOwner'], role == 'owner'),
        isCurrentUser: asBool(json['isCurrentUser']),
      );
  }
}

String normalizeWorkspaceRole(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  final normalized = raw.replaceAll('-', '_').replaceAll(' ', '_');
  return switch (normalized) {
    'owner' || 'workspace_role_owner' || 'chu_so_huu' => 'owner',
    'manager' || 'admin' => 'manager',
    'member' => 'member',
    'viewer' || 'view' => 'viewer',
    _ => raw,
  };
}

bool _roleCanWrite(String role) =>
    role == 'owner' || role == 'manager' || role == 'member';

bool _roleCanManageMembers(String role) => role == 'owner' || role == 'manager';

bool _roleCanDeleteWorkspace(String role) => role == 'owner';
