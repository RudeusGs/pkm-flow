import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required WorkspaceRepository repository,
    required RealtimeService realtime,
  })  : _repository = repository,
        _realtime = realtime;

  final WorkspaceRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];

  Future<void>? _loadFuture;
  Future<void>? _membersLoadFuture;
  Timer? _membersDebounce;

  List<Workspace> workspaces = const [];
  List<WorkspaceMember> members = const [];
  Workspace? selected;
  bool isLoading = false;
  bool isBusy = false;
  String? error;

  Future<void> load() async {
    if (_loadFuture != null) return _loadFuture!;
    _loadFuture = _loadInternal();
    return _loadFuture!;
  }

  Future<void> _loadInternal() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final previousId = selected?.id;
      workspaces = await _repository.myWorkspaces();
      selected = _findWorkspace(previousId) ?? (workspaces.isEmpty ? null : workspaces.first);

      if (selected != null) {
        await _realtime.joinWorkspace(selected!.id);
        await loadMembers(silent: true);
      } else {
        members = const [];
      }

      _bindRealtime();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      _loadFuture = null;
      notifyListeners();
    }
  }

  Workspace? _findWorkspace(String? id) {
    if (id == null) return null;
    for (final workspace in workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  Future<void> select(Workspace workspace) async {
    if (selected?.id == workspace.id) return;

    final previous = selected;
    selected = workspace;
    members = const [];
    notifyListeners();

    if (previous != null) {
      await _realtime.leaveWorkspace(previous.id);
    }

    await _realtime.joinWorkspace(workspace.id);
    await loadMembers();
  }


  Future<void> openWorkspace(Workspace workspace) async {
    final existing = _findWorkspace(workspace.id);

    if (existing == null) {
      workspaces = [workspace, ...workspaces];
    } else {
      workspaces = workspaces
          .map((item) => item.id == workspace.id ? workspace : item)
          .toList();
    }

    if (selected?.id == workspace.id) {
      selected = workspace;
      await loadMembers(silent: true);
      notifyListeners();
      return;
    }

    await select(workspace);
  }

  Future<void> create(
    String name, {
    String? description,
    String visibility = 'private',
  }) async {
    await _run(() async {
      final created = await _repository.createWorkspace(
        name: name,
        description: description,
        visibility: visibility,
      );

      workspaces = [created, ...workspaces];
      await select(created);
    });
  }

  Future<void> updateSelected({
    required String name,
    String? description,
    String? visibility,
  }) async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      final updated = await _repository.updateWorkspace(
        workspace,
        name: name,
        description: description,
        visibility: visibility,
      );

      workspaces = workspaces.map((item) => item.id == updated.id ? updated : item).toList();
      selected = updated;
    });
  }

  Future<void> deleteSelected() async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      await _repository.deleteWorkspace(workspace.id);
      await _realtime.leaveWorkspace(workspace.id);

      workspaces = workspaces.where((item) => item.id != workspace.id).toList();
      selected = workspaces.isEmpty ? null : workspaces.first;
      members = const [];

      if (selected != null) {
        await _realtime.joinWorkspace(selected!.id);
        await loadMembers(silent: true);
      }
    });
  }

  Future<void> leaveSelected() async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      await _repository.leaveWorkspace(workspace.id);
      await _realtime.leaveWorkspace(workspace.id);

      workspaces = workspaces.where((item) => item.id != workspace.id).toList();
      selected = workspaces.isEmpty ? null : workspaces.first;
      members = const [];

      if (selected != null) {
        await _realtime.joinWorkspace(selected!.id);
        await loadMembers(silent: true);
      }
    });
  }

  Future<void> loadMembers({bool silent = false}) async {
    final workspace = selected;
    if (workspace == null) return;
    if (_membersLoadFuture != null) return _membersLoadFuture!;

    _membersLoadFuture = _loadMembersInternal(workspace.id, silent: silent);
    return _membersLoadFuture!;
  }

  Future<void> _loadMembersInternal(
    String workspaceId, {
    required bool silent,
  }) async {
    try {
      members = await _repository.members(workspaceId);
      if (!silent) notifyListeners();
    } finally {
      _membersLoadFuture = null;
    }
  }

  Future<void> inviteByEmail({
    required String email,
    String role = 'member',
  }) async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      await _repository.inviteByEmail(workspace.id, email: email, role: role);
      await loadMembers(silent: true);
    });
  }

  // Alias cho file UI/controller cũ còn gọi inviteMember.
  Future<void> inviteMember({
    required String email,
    required String role,
  }) {
    return inviteByEmail(email: email, role: role);
  }

  Future<void> changeRole(WorkspaceMember member, String role) async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      final updated = await _repository.changeMemberRole(workspace.id, member.userId, role);
      members = members.map((item) => item.userId == updated.userId ? updated : item).toList();
    });
  }

  Future<void> removeMember(WorkspaceMember member) async {
    final workspace = selected;
    if (workspace == null) return;

    await _run(() async {
      await _repository.removeMember(workspace.id, member.userId);
      members = members.where((item) => item.userId != member.userId).toList();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isBusy) return;

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      await action();
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;

    // Không nghe PageCreated/PageUpdated/PageDeleted ở WorkspaceController nữa.
    // Page events để PagesController xử lý, tránh realtime kéo GET me/workspaces liên tục.
    for (final event in const [
      'WorkspaceUpdated',
      'WorkspaceDeleted',
      'WorkspaceMemberAdded',
      'WorkspaceMemberRemoved',
      'WorkspaceMemberRoleChanged',
      'WorkspaceInvitationAccepted',
      'WorkspaceMemberChanged',
    ]) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final current = selected;
        if (current == null) return;
        if (payload.workspaceId != null && payload.workspaceId != current.id) return;
        _debounceMembersReload();
      }));
    }

    // Presence chỉ update UI, không gọi API. Tránh heartbeat -> presence -> GET loop.
    _unsubscribe.add(_realtime.on('WorkspacePresenceChanged', (_) {
      notifyListeners();
    }));
  }

  void _debounceMembersReload() {
    _membersDebounce?.cancel();
    _membersDebounce = Timer(const Duration(seconds: 2), () {
      loadMembers(silent: true).then((_) => notifyListeners());
    });
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _membersDebounce?.cancel();
    if (selected != null) {
      _realtime.leaveWorkspace(selected!.id);
    }
    super.dispose();
  }
}
