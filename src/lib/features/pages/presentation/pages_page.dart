import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/page_item.dart';
import 'editor_page.dart';
import 'pages_controller.dart';

class PagesPage extends StatefulWidget {
  const PagesPage({super.key, required this.workspace});

  final Workspace? workspace;

  @override
  State<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends State<PagesPage> {
  late final PagesController _controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _controller = PagesController(
        repository: deps.pageRepository, realtime: deps.realtime);
    _reload();
  }

  @override
  void didUpdateWidget(covariant PagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace?.id != widget.workspace?.id) _reload();
  }

  void _reload() {
    final workspace = widget.workspace;
    if (workspace != null) {
      _controller.loadPages(workspace.id, keyword: _search.text.trim());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workspace == null) {
      return const EmptyState(
          icon: Icons.space_dashboard_outlined,
          title: 'Chưa có workspace',
          message: 'Tạo workspace trước rồi viết page sau nha.');
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.pages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.pages.isEmpty) {
          return EmptyState(
              icon: Icons.description_outlined,
              title: 'Chưa có page',
              message: 'Bấm nút + để tạo page kiểu Notion mobile.');
        }
        return RefreshIndicator(
          onRefresh: () => _controller.loadPages(widget.workspace!.id),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _controller.pages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'Tìm page'),
                  onSubmitted: (value) => _controller
                      .loadPages(widget.workspace!.id, keyword: value.trim()),
                );
              }
              final page = _controller.pages[index - 1];
              return _PageTile(
                page: page,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        EditorPage(controller: _controller, page: page))),
                onRename: () => _renamePage(page),
                onDuplicate: () => _controller.duplicatePage(page),
                onDelete: () => _deletePage(page),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _renamePage(PageItem page) async {
    final title =
        await _askTitle(context, initial: page.title, title: 'Đổi tên page');
    if (title != null && title.trim().isNotEmpty) {
      await _controller.renamePage(page, title.trim());
    }
  }

  Future<void> _deletePage(PageItem page) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa page?'),
        content: Text(page.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await _controller.deletePage(page);
  }
}

class PagesFab extends StatelessWidget {
  const PagesFab({super.key, required this.workspace});

  final Workspace? workspace;

  @override
  Widget build(BuildContext context) {
    if (workspace == null) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      heroTag: 'pages-create',
      onPressed: () async {
        final deps = AppScope.read(context);
        final controller = PagesController(
            repository: deps.pageRepository, realtime: deps.realtime);
        await controller.loadPages(workspace!.id);
        if (!context.mounted) return;
        final title = await _askTitle(context);
        if (title != null && title.trim().isNotEmpty) {
          await controller.createPage(title.trim());
        }
        controller.dispose();
      },
      child: const Icon(Icons.add),
    );
  }

  Future<String?> _askTitle(BuildContext context) {
    final input = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo page'),
        content: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên page')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Tạo')),
        ],
      ),
    );
  }
}

Future<String?> _askTitle(BuildContext context,
    {String? initial, String title = 'Tạo page'}) {
  final input = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên page')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Lưu')),
      ],
    ),
  );
}

class _PageTile extends StatelessWidget {
  const _PageTile(
      {required this.page,
      required this.onTap,
      required this.onRename,
      required this.onDuplicate,
      required this.onDelete});

  final PageItem page;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            backgroundColor: AppColors.soft, child: Text(page.icon ?? '📝')),
        title: Text(page.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Revision ${page.currentRevision}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'duplicate':
                onDuplicate();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
            PopupMenuItem(value: 'duplicate', child: Text('Nhân bản')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}
