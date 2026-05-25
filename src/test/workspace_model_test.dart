import 'package:flutter_test/flutter_test.dart';

import 'package:block_based_pkm_flutter/features/workspaces/domain/workspace.dart';

void main() {
  test('derives owner permissions from workspace list role', () {
    final workspace = Workspace.fromJson({
      'id': 'workspace-1',
      'name': 'Owner space',
      'visibility': 'Private',
      'ownerId': 'user-1',
      'currentUserRole': 'Owner',
    });

    expect(workspace.currentUserRole, 'owner');
    expect(workspace.canWrite, isTrue);
    expect(workspace.canManageMembersEffective, isTrue);
    expect(workspace.canManageSettingsEffective, isTrue);
    expect(workspace.canDeleteWorkspace, isTrue);
  });

  test('keeps viewer read-only when capability flags are absent', () {
    final workspace = Workspace.fromJson({
      'id': 'workspace-2',
      'name': 'Viewer space',
      'visibility': 'Private',
      'ownerId': 'user-1',
      'currentUserRole': 'Viewer',
    });

    expect(workspace.currentUserRole, 'viewer');
    expect(workspace.canWrite, isFalse);
    expect(workspace.canManageMembersEffective, isFalse);
    expect(workspace.canManageSettingsEffective, isFalse);
    expect(workspace.canDeleteWorkspace, isFalse);
  });
}
