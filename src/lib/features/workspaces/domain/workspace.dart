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

  String get normalizedRole => normalizeWorkspaceRole(currentUserRole);

  bool get isOwner => normalizedRole == 'owner';

  bool get canWriteEffective =>
      canWrite || _roleCanWrite(normalizedRole);

  bool get canManageMembersEffective =>
      canManageMembers || _roleCanManageMembers(normalizedRole);

  bool get canManageSettingsEffective =>
      canManageMembersEffective || isOwner;

  bool get canDeleteWorkspaceEffective =>
      canDeleteWorkspace || _roleCanDeleteWorkspace(normalizedRole);

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
      currentUserRole:
          currentUserRole == null ? this.currentUserRole : normalizeWorkspaceRole(currentUserRole),
      canWrite: canWrite ?? this.canWrite,
      canManageMembers: canManageMembers ?? this.canManageMembers,
      canDeleteWorkspace: canDeleteWorkspace ?? this.canDeleteWorkspace,
    );
  }

  factory Workspace.fromJson(JsonMap json) {
    final role = normalizeWorkspaceRole(
      json['currentUserRole'] ??
          json['role'] ??
          json['memberRole'] ??
          json['workspaceRole'],
    );

    final isOwner = asBool(json['isOwner']) || role == 'owner';

    return Workspace(
      id: asString(json['id']),
      name: asString(json['name'], 'Untitled workspace'),
      description: json['description']?.toString(),
      visibility: asString(json['visibility'], 'private').toLowerCase(),
      ownerId: asString(json['ownerId']),
      currentUserRole: isOwner ? 'owner' : role,
      canWrite: asBool(json['canWrite'], _roleCanWrite(role) || isOwner),
      canManageMembers: asBool(
        json['canManageMembers'] ?? json['canManageWorkspaceMembers'],
        _roleCanManageMembers(role) || isOwner,
      ),
      canDeleteWorkspace: asBool(
        json['canDeleteWorkspace'],
        _roleCanDeleteWorkspace(role) || isOwner,
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

  bool get canBeManaged => !isOwner && !isCurrentUser;

  factory WorkspaceMember.fromJson(JsonMap json) {
    final role = normalizeWorkspaceRole(
      json['role'] ?? json['currentUserRole'] ?? json['memberRole'],
    );
    final isOwner = asBool(json['isOwner'], role == 'owner');

    return WorkspaceMember(
      userId: asString(json['userId'] ?? json['id']),
      userName: asString(json['userName']),
      fullName: asString(
        json['fullName'] ?? json['displayName'] ?? json['name'],
        asString(json['userName'], 'Member'),
      ),
      email: asString(json['email']),
      avatarUrl: json['avatarUrl']?.toString(),
      role: isOwner ? 'owner' : role,
      isOwner: isOwner,
      isCurrentUser: asBool(json['isCurrentUser'] ?? json['isMe']),
    );
  }
}

String normalizeWorkspaceRole(Object? value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';
  if (raw.isEmpty) return '';

  final normalized = raw
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .replaceAll('.', '_');

  return switch (normalized) {
    '1' || 'owner' || 'workspace_role_owner' || 'workspacerole_owner' || 'chu_so_huu' => 'owner',
    '2' || 'manager' || 'admin' || 'administrator' || 'workspace_role_manager' || 'workspacerole_manager' => 'manager',
    '3' || 'member' || 'editor' || 'workspace_role_member' || 'workspacerole_member' => 'member',
    '4' || 'viewer' || 'view' || 'readonly' || 'read_only' || 'workspace_role_viewer' || 'workspacerole_viewer' => 'viewer',
    _ => normalized,
  };
}

bool _roleCanWrite(String role) =>
    role == 'owner' || role == 'manager' || role == 'member';

bool _roleCanManageMembers(String role) => role == 'owner' || role == 'manager';

bool _roleCanDeleteWorkspace(String role) => role == 'owner';
