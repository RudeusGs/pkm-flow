import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(
      {required WorkspaceRepository repository,
      required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final WorkspaceRepository _repository;
  final RealtimeService _realtime;
  final List<VoidCallback> _unsubscribe = [];
  Future<void>? _loadFuture;

  List<Workspace> workspaces = const [];
  List<WorkspaceMember> members = const [];
  Workspace? selected;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    if (_loadFuture != null) {
      return _loadFuture!;
    }
    _loadFuture = _loadInternal();
    return _loadFuture!;
  }

  Future<void> _loadInternal() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      workspaces = await _repository.myWorkspaces();
      if (selected == null ||
          !workspaces.any((workspace) => workspace.id == selected!.id)) {
        selected = workspaces.isEmpty ? null : workspaces.first;
      }
      if (selected != null) {
        await _realtime.joinWorkspace(selected!.id);
        members = await _repository.members(selected!.id);
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

  Future<void> select(Workspace workspace) async {
    if (selected?.id == workspace.id) return;
    final previous = selected;
    selected = workspace;
    notifyListeners();
    if (previous != null) await _realtime.leaveWorkspace(previous.id);
    await _realtime.joinWorkspace(workspace.id);
    await loadMembers();
  }

  Future<void> create(String name,
      {String? description, String visibility = 'private'}) async {
    final created = await _repository.createWorkspace(
        name: name, description: description, visibility: visibility);
    workspaces = [created, ...workspaces];
    await select(created);
  }

  Future<void> updateSelected(
      {required String name,
      String? description,
      String visibility = 'private'}) async {
    final workspace = selected;
    if (workspace == null) return;
    final updated = await _repository.updateWorkspace(workspace,
        name: name, description: description, visibility: visibility);
    workspaces = workspaces
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    selected = updated;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    final workspace = selected;
    if (workspace == null) return;
    await _repository.deleteWorkspace(workspace.id);
    await _realtime.leaveWorkspace(workspace.id);
    workspaces = workspaces.where((item) => item.id != workspace.id).toList();
    selected = workspaces.isEmpty ? null : workspaces.first;
    members = const [];
    if (selected != null) await _realtime.joinWorkspace(selected!.id);
    notifyListeners();
  }

  Future<void> leaveSelected() async {
    final workspace = selected;
    if (workspace == null) return;
    await _repository.leaveWorkspace(workspace.id);
    await _realtime.leaveWorkspace(workspace.id);
    workspaces = workspaces.where((item) => item.id != workspace.id).toList();
    selected = workspaces.isEmpty ? null : workspaces.first;
    members = const [];
    if (selected != null) await _realtime.joinWorkspace(selected!.id);
    notifyListeners();
  }

  Future<void> loadMembers() async {
    final workspace = selected;
    if (workspace == null) return;
    members = await _repository.members(workspace.id);
    notifyListeners();
  }

  Future<void> inviteMember(
      {required String email, required String role}) async {
    final workspace = selected;
    if (workspace == null) return;
    await _repository.inviteMember(workspace.id, email: email, role: role);
    await loadMembers();
  }

  Future<void> changeRole(WorkspaceMember member, String role) async {
    final workspace = selected;
    if (workspace == null) return;
    final updated =
        await _repository.changeMemberRole(workspace.id, member.userId, role);
    members = members
        .map((item) => item.userId == updated.userId ? updated : item)
        .toList();
    notifyListeners();
  }

  Future<void> removeMember(WorkspaceMember member) async {
    final workspace = selected;
    if (workspace == null) return;
    await _repository.removeMember(workspace.id, member.userId);
    members = members.where((item) => item.userId != member.userId).toList();
    notifyListeners();
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in ['PageCreated', 'PageUpdated', 'PageDeleted']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final current = selected;
        if (current == null) {
          return;
        }
        if (payload.workspaceId != null && payload.workspaceId != current.id) {
          return;
        }
        load();
      }));
    }
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    if (selected != null) _realtime.leaveWorkspace(selected!.id);
    super.dispose();
  }
}
