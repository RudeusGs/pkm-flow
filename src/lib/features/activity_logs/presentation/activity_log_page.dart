import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../workspaces/domain/workspace.dart';
import '../data/activity_log_repository.dart';
import '../domain/activity_log.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({
    super.key,
    required this.workspace,
    required this.repository,
  });

  final Workspace workspace;
  final ActivityLogRepository repository;

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  static const _pageSize = 30;

  final _search = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _searchDebounce;
  List<ActivityLog> _logs = const [];
  String? _selectedAction;
  String? _selectedEntityType;
  String? _error;
  int _pageNumber = 1;
  int _totalPages = 0;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  bool get _hasMore => _pageNumber < _totalPages;
  bool get _hasFilter => _selectedAction != null || _selectedEntityType != null;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_isLoadingMore || (_isLoading && !reset)) return;

    final nextPage = reset ? 1 : _pageNumber + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
        _logs = const [];
      } else {
        _isLoadingMore = true;
      }
      _error = null;
    });

    try {
      final result = await widget.repository.workspaceLogs(
        widget.workspace.id,
        action: _selectedAction,
        entityType: _selectedEntityType,
        search: _search.text.trim(),
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _pageNumber = result.pageNumber;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _logs = reset ? result.items : [..._logs, ...result.items];
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() => _load(reset: true);

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _load(reset: true),
    );
    setState(() {});
  }

  void _clearFilters() {
    if (!_hasFilter) return;
    setState(() {
      _selectedAction = null;
      _selectedEntityType = null;
    });
    _load(reset: true);
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _load(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotionScaffold(
      appBar: NotionTopBar(
        title: 'Activity log',
        subtitle: widget.workspace.name,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
            icon: Icon(
              _hasFilter
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _ActivityHeroCard(
              workspaceName: widget.workspace.name,
              totalCount: _totalCount,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 14),
            NotionTextField(
              controller: _search,
              hintText: 'Search actor or description...',
              prefixIcon: Icons.search_rounded,
              suffixIcon: _search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _load(reset: true);
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _load(reset: true),
            ),
            const SizedBox(height: 12),
            _ActivityFilterSummaryCard(
              selectedAction: _selectedAction,
              selectedEntityType: _selectedEntityType,
              onOpenFilters: _showFilterSheet,
              onClear: _hasFilter ? _clearFilters : null,
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _ActivityErrorCard(
                message: _error!,
                onRetry: () => _load(reset: true),
              ),
              const SizedBox(height: 14),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty)
              EmptyState(
                icon: Icons.manage_search_rounded,
                title: 'Chưa có activity nào',
                message: _search.text.trim().isEmpty
                    ? 'Workspace này chưa có log phù hợp với bộ lọc hiện tại.'
                    : 'Không tìm thấy log nào khớp từ khóa. Thử keyword ngắn hơn nha.',
                action: NotionButton(
                  label: 'Tải lại',
                  icon: Icons.refresh_rounded,
                  onPressed: _refresh,
                ),
              )
            else ...[
              for (var i = 0; i < _logs.length; i++) ...[
                _ActivityLogTile(
                  log: _logs[i],
                  isLast: i == _logs.length - 1 && !_isLoadingMore,
                ),
                if (i != _logs.length - 1) const SizedBox(height: 8),
              ],
              if (_isLoadingMore) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
              ] else if (_hasMore) ...[
                const SizedBox(height: 18),
                NotionButton(
                  label: 'Load more',
                  icon: Icons.keyboard_arrow_down_rounded,
                  secondary: true,
                  expanded: true,
                  onPressed: () => _load(reset: false),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    var action = _selectedAction;
    var entityType = _selectedEntityType;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: BottomSheetHeader(
                  title: 'Lọc activity log',
                  subtitle:
                      'Danh sách lọc chuyển sang dạng sheet để kéo dọc cho dễ, không còn kẹt chip ngang nữa.',
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  children: [
                    _FilterSectionTitle(
                      title: 'Action',
                      value: _filterLabel(_actionFilters, action),
                    ),
                    const SizedBox(height: 8),
                    for (final item in _actionFilters)
                      _FilterActionTile(
                        item: item,
                        selected: action == item.value,
                        onTap: () => setSheetState(() => action = item.value),
                      ),
                    const SizedBox(height: 18),
                    _FilterSectionTitle(
                      title: 'Entity',
                      value: _filterLabel(_entityFilters, entityType),
                    ),
                    const SizedBox(height: 8),
                    for (final item in _entityFilters)
                      _FilterActionTile(
                        item: item,
                        selected: entityType == item.value,
                        onTap: () => setSheetState(() => entityType = item.value),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: NotionButton(
                        label: 'Clear',
                        icon: Icons.filter_alt_off_outlined,
                        secondary: true,
                        expanded: true,
                        onPressed: () {
                          setSheetState(() {
                            action = null;
                            entityType = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NotionButton(
                        label: 'Apply',
                        icon: Icons.done_rounded,
                        expanded: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (applied != true) return;
    if (_selectedAction == action && _selectedEntityType == entityType) return;

    setState(() {
      _selectedAction = action;
      _selectedEntityType = entityType;
    });
    await _load(reset: true);
  }

}

class _ActivityFilterOption {
  const _ActivityFilterOption({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String? value;
  final IconData icon;
}

const _actionFilters = [
  _ActivityFilterOption(
    label: 'All',
    value: null,
    icon: Icons.auto_awesome_rounded,
  ),
  _ActivityFilterOption(
    label: 'Create',
    value: 'Create',
    icon: Icons.add_circle_outline_rounded,
  ),
  _ActivityFilterOption(
    label: 'Update',
    value: 'Update',
    icon: Icons.edit_outlined,
  ),
  _ActivityFilterOption(
    label: 'Delete',
    value: 'Delete',
    icon: Icons.delete_outline_rounded,
  ),
  _ActivityFilterOption(
    label: 'Archive',
    value: 'Archive',
    icon: Icons.inventory_2_outlined,
  ),
  _ActivityFilterOption(
    label: 'Restore',
    value: 'Restore',
    icon: Icons.restore_rounded,
  ),
  _ActivityFilterOption(
    label: 'Move',
    value: 'Move',
    icon: Icons.drive_file_move_outline,
  ),
  _ActivityFilterOption(
    label: 'Assign',
    value: 'Assign',
    icon: Icons.assignment_ind_outlined,
  ),
  _ActivityFilterOption(
    label: 'Complete',
    value: 'Complete',
    icon: Icons.check_circle_outline_rounded,
  ),
  _ActivityFilterOption(
    label: 'Permission',
    value: 'ChangePermissions',
    icon: Icons.admin_panel_settings_outlined,
  ),
];

const _entityFilters = [
  _ActivityFilterOption(
    label: 'All',
    value: null,
    icon: Icons.category_outlined,
  ),
  _ActivityFilterOption(
    label: 'Workspace',
    value: 'Workspace',
    icon: Icons.space_dashboard_outlined,
  ),
  _ActivityFilterOption(
    label: 'Member',
    value: 'WorkspaceMember',
    icon: Icons.groups_2_outlined,
  ),
  _ActivityFilterOption(
    label: 'Page',
    value: 'Page',
    icon: Icons.description_outlined,
  ),
  _ActivityFilterOption(
    label: 'Block',
    value: 'Block',
    icon: Icons.view_agenda_outlined,
  ),
  _ActivityFilterOption(
    label: 'Task',
    value: 'WorkTask',
    icon: Icons.check_circle_outline_rounded,
  ),
  _ActivityFilterOption(
    label: 'Comment',
    value: 'TaskComment',
    icon: Icons.mode_comment_outlined,
  ),
];

String _filterLabel(List<_ActivityFilterOption> items, String? value) {
  for (final item in items) {
    if (item.value == value) return item.label;
  }
  return 'All';
}

class _ActivityFilterSummaryCard extends StatelessWidget {
  const _ActivityFilterSummaryCard({
    required this.selectedAction,
    required this.selectedEntityType,
    required this.onOpenFilters,
    required this.onClear,
  });

  final String? selectedAction;
  final String? selectedEntityType;
  final VoidCallback onOpenFilters;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(12),
      onTap: onOpenFilters,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FilterBadge(
                      icon: Icons.bolt_outlined,
                      label: _filterLabel(_actionFilters, selectedAction),
                    ),
                    _FilterBadge(
                      icon: Icons.category_outlined,
                      label: _filterLabel(_entityFilters, selectedEntityType),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null) ...[
            IconButton(
              tooltip: 'Clear filters',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
          const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _FilterBadge(icon: Icons.check_circle_outline_rounded, label: value),
      ],
    );
  }
}

class _FilterActionTile extends StatelessWidget {
  const _FilterActionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ActivityFilterOption item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NotionCard(
        selected: selected,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: Icon(item.icon, color: selected ? AppColors.ink : AppColors.muted),
          title: Text(
            item.label,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
              : const Icon(Icons.circle_outlined, color: AppColors.subtle),
        ),
      ),
    );
  }
}

class _ActivityHeroCard extends StatelessWidget {
  const _ActivityHeroCard({
    required this.workspaceName,
    required this.totalCount,
    required this.isLoading,
  });

  final String workspaceName;
  final int totalCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workspace timeline',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Đang lấy activity mới nhất...'
                      : '$totalCount activity trong $workspaceName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  const _ActivityLogTile({
    required this.log,
    required this.isLast,
  });

  final ActivityLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForAction(log.action);
    final timeText = _formatRelative(log.occurredAt);
    final entity = ActivityLog.entityLabel(log.entityType);
    final action = ActivityLog.actionLabel(log.action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tone.border),
                  ),
                  child: Icon(tone.icon, size: 18, color: tone.foreground),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 8),
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NotionCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        name: log.actorName,
                        imageUrl: log.userAvatarUrl,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          log.actorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (timeText.isNotEmpty)
                        Text(
                          timeText,
                          style: const TextStyle(
                            color: AppColors.subtle,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    log.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ActivityMiniChip(
                        icon: tone.icon,
                        label: action,
                        color: tone.foreground,
                      ),
                      _ActivityMiniChip(
                        icon: _entityIcon(log.entityType),
                        label: entity,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _entityIcon(String value) => switch (value.toLowerCase()) {
        'workspace' => Icons.space_dashboard_outlined,
        'workspacemember' => Icons.groups_2_outlined,
        'page' => Icons.description_outlined,
        'block' => Icons.view_agenda_outlined,
        'worktask' => Icons.check_circle_outline_rounded,
        'taskcomment' => Icons.mode_comment_outlined,
        _ => Icons.category_outlined,
      };

  static String _formatRelative(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ActivityTone {
  const _ActivityTone({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}

_ActivityTone _toneForAction(String action) {
  switch (action.toLowerCase()) {
    case 'create':
      return const _ActivityTone(
        icon: Icons.add_rounded,
        foreground: AppColors.success,
        background: Color(0xFF142219),
        border: Color(0xFF284D35),
      );
    case 'update':
      return const _ActivityTone(
        icon: Icons.edit_rounded,
        foreground: AppColors.warning,
        background: Color(0xFF2A2113),
        border: Color(0xFF57401E),
      );
    case 'delete':
      return const _ActivityTone(
        icon: Icons.delete_outline_rounded,
        foreground: AppColors.danger,
        background: AppColors.dangerSurface,
        border: Color(0xFF533035),
      );
    case 'archive':
      return const _ActivityTone(
        icon: Icons.inventory_2_outlined,
        foreground: AppColors.muted,
        background: AppColors.hover,
        border: AppColors.line,
      );
    case 'restore':
      return const _ActivityTone(
        icon: Icons.restore_rounded,
        foreground: AppColors.success,
        background: Color(0xFF142219),
        border: Color(0xFF284D35),
      );
    case 'assign':
    case 'unassign':
      return const _ActivityTone(
        icon: Icons.assignment_ind_outlined,
        foreground: Color(0xFF9AA7FF),
        background: Color(0xFF171A2A),
        border: Color(0xFF30375F),
      );
    case 'complete':
      return const _ActivityTone(
        icon: Icons.check_rounded,
        foreground: AppColors.success,
        background: Color(0xFF142219),
        border: Color(0xFF284D35),
      );
    case 'changepermissions':
      return const _ActivityTone(
        icon: Icons.admin_panel_settings_outlined,
        foreground: Color(0xFFD6A8FF),
        background: Color(0xFF24182D),
        border: Color(0xFF4A315E),
      );
    default:
      return const _ActivityTone(
        icon: Icons.history_rounded,
        foreground: AppColors.ink,
        background: AppColors.hover,
        border: AppColors.line,
      );
  }
}

class _ActivityMiniChip extends StatelessWidget {
  const _ActivityMiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityErrorCard extends StatelessWidget {
  const _ActivityErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
