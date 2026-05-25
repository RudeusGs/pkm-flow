import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../pages/domain/page_item.dart';
import '../../pages/presentation/pages_controller.dart';
import '../domain/workspace.dart';

class WorkspaceTrashPage extends StatefulWidget {
  const WorkspaceTrashPage({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<WorkspaceTrashPage> createState() => _WorkspaceTrashPageState();
}

class _WorkspaceTrashPageState extends State<WorkspaceTrashPage> {
  late final PagesController _pages;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _pages = PagesController(
      repository: deps.pageRepository,
      realtime: deps.realtime,
    )..loadTrash(widget.workspace.id);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _pages.loadTrash(widget.workspace.id);

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message);
  }

  Future<void> _restore(PageItem page) async {
    final restored = await _pages.restorePage(page);
    if (!mounted) return;

    if (restored == null) {
      _showSnack(_pages.error ?? 'Không khôi phục được page.');
      return;
    }

    _hasChanges = true;
    _showSnack('Đã khôi phục "${page.title}".');
    Navigator.pop(context, true);
  }

  Future<void> _showPageActions(PageItem page) async {
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: page.title,
      subtitle: 'Page đang nằm trong Trash',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotionActionRow(
            icon: Icons.restore_rounded,
            title: 'Khôi phục page',
            subtitle: 'Đưa page về lại danh sách pages đang dùng.',
            onTap: () => Navigator.pop(context, 'restore'),
          ),
          const NotionActionRow(
            icon: Icons.info_outline_rounded,
            title: 'Xóa vĩnh viễn',
            subtitle: 'Backend hiện chưa có API xóa vĩnh viễn page.',
            enabled: false,
          ),
        ],
      ),
    );

    if (action == 'restore') await _restore(page);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: NotionScaffold(
      appBar: NotionTopBar(
        title: 'Trash',
        subtitle: widget.workspace.name,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context, _hasChanges),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _pages,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
              children: [
                _TrashHeroCard(
                  workspaceName: widget.workspace.name,
                  count: _pages.pages.length,
                  isLoading: _pages.isLoading,
                ),
                if (_pages.error != null) ...[
                  const SizedBox(height: 12),
                  _TrashErrorCard(message: _pages.error!, onRetry: _refresh),
                ],
                const SizedBox(height: 14),
                if (_pages.isLoading && _pages.pages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 56),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_pages.pages.isEmpty)
                  const EmptyState(
                    icon: Icons.delete_outline_rounded,
                    title: 'Trash đang trống',
                    message: 'Page đã đưa vào Trash sẽ hiện ở đây để khôi phục khi cần.',
                  )
                else
                  ..._pages.pages.map(
                    (page) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TrashPageTile(
                        page: page,
                        onRestore: () => _restore(page),
                        onMore: () => _showPageActions(page),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ));
  }
}

class _TrashHeroCard extends StatelessWidget {
  const _TrashHeroCard({
    required this.workspaceName,
    required this.count,
    required this.isLoading,
  });

  final String workspaceName;
  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count page trong Trash',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Đang tải dữ liệu...'
                      : 'Trash của workspace $workspaceName.',
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

class _TrashPageTile extends StatelessWidget {
  const _TrashPageTile({
    required this.page,
    required this.onRestore,
    required this.onMore,
  });

  final PageItem page;
  final VoidCallback onRestore;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.only(left: 14, right: 4, top: 4, bottom: 4),
        leading: SizedBox(
          width: 36,
          child: Center(
            child: Text(
              page.icon?.isNotEmpty == true ? page.icon! : '📄',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          page.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          page.archivedAt?.isNotEmpty == true
              ? 'Đã đưa vào Trash · ${_shortDate(page.archivedAt)}'
              : 'Page trong Trash',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Khôi phục page',
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded, color: AppColors.muted),
            ),
            IconButton(
              tooltip: 'Thao tác',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return '';
    final parsed = DateTime.tryParse(text)?.toLocal();
    if (parsed == null) return text;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}

class _TrashErrorCard extends StatelessWidget {
  const _TrashErrorCard({required this.message, required this.onRetry});

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
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}