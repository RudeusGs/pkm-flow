import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../../../core/utils/session_id.dart';
import '../data/page_repository.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';

class PagesController extends ChangeNotifier {
  PagesController(
      {required PageRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final PageRepository _repository;
  final RealtimeService _realtime;
  final String editorSessionId = newEditorSessionId();
  final List<VoidCallback> _unsubscribe = [];
  Timer? _pageHeartbeat;
  Timer? _debounce;

  String? workspaceId;
  PageItem? selectedPage;
  List<PageItem> pages = const [];
  List<BlockItem> blocks = const [];
  int currentRevision = 0;
  int _draftSequence = 0;
  bool isLoading = false;
  String? error;

  Future<void> loadPages(String nextWorkspaceId, {String? keyword}) async {
    workspaceId = nextWorkspaceId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      pages = await _repository.pages(nextWorkspaceId, keyword: keyword);
      final currentId = selectedPage?.id;
      selectedPage = pages.where((item) => item.id == currentId).firstOrNull ??
          (pages.isEmpty ? null : pages.first);
      _bindRealtime();
      if (selectedPage != null) await loadDocument(selectedPage!);
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PageItem?> createPage(String title,
      {String icon = '📝', String? parentPageId}) async {
    final id = workspaceId;
    if (id == null) return null;
    final page = await _repository.createPage(id,
        title: title, icon: icon, parentPageId: parentPageId);
    pages = [page, ...pages];
    await loadDocument(page);
    return page;
  }

  Future<void> updatePageTitle(String title, {String? icon}) async {
    final page = selectedPage;
    if (page == null || title.trim().isEmpty) return;
    final updated = await _repository.updatePage(page,
        title: title.trim(), icon: icon ?? page.icon);
    selectedPage = updated;
    pages =
        pages.map((item) => item.id == updated.id ? updated : item).toList();
    notifyListeners();
  }

  Future<void> renamePage(PageItem page,
      {required String title, String? icon}) async {
    if (title.trim().isEmpty) return;
    final updated = await _repository.updatePage(
      page,
      title: title.trim(),
      icon: icon ?? page.icon,
    );
    pages =
        pages.map((item) => item.id == updated.id ? updated : item).toList();
    if (selectedPage?.id == updated.id) selectedPage = updated;
    notifyListeners();
  }

  Future<void> loadDocument(PageItem page) async {
    if (selectedPage?.id != page.id && selectedPage != null) {
      await _realtime.leavePage(selectedPage!.id);
    }
    selectedPage = page;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _realtime.joinPage(page.id);
      _startPageHeartbeat(page.id);
      final doc = await _repository.document(page.id);
      currentRevision = doc.currentRevision;
      blocks = doc.blocks;
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<BlockItem?> addBlock(String type) async {
    final page = selectedPage;
    if (page == null) return null;
    final last = blocks.isEmpty ? null : blocks.last.id;
    final mutation = await _repository.createBlock(
      page.id,
      expectedRevision: currentRevision,
      type: type,
      textContent: _defaultTextForType(type),
      propsJson: _defaultPropsForType(type),
      previousBlockId: last,
    );
    currentRevision = mutation.appliedRevision;
    if (mutation.block != null) blocks = [...blocks, mutation.block!];
    notifyListeners();
    return mutation.block;
  }

  Future<void> updateBlock(BlockItem block, String type, String text,
      {String? propsJson}) async {
    final mutation = await _repository.updateBlock(
      block,
      expectedRevision: currentRevision,
      editorSessionId: editorSessionId,
      textContent: text,
      type: type,
      propsJson: propsJson,
    );
    currentRevision = mutation.appliedRevision;
    if (mutation.block != null) {
      blocks = blocks
          .map((item) => item.id == block.id ? mutation.block! : item)
          .toList();
    }
    notifyListeners();
  }

  Future<BlockItem?> duplicateBlock(BlockItem block) async {
    final page = selectedPage;
    if (page == null) return null;
    final mutation = await _repository.createBlock(
      page.id,
      expectedRevision: currentRevision,
      type: block.type,
      textContent: block.textContent,
      propsJson: block.propsJson,
      previousBlockId: block.id,
    );
    currentRevision = mutation.appliedRevision;
    if (mutation.block != null) {
      final index = blocks.indexWhere((item) => item.id == block.id);
      final next = List<BlockItem>.from(blocks);
      next.insert(index < 0 ? next.length : index + 1, mutation.block!);
      blocks = next;
    }
    notifyListeners();
    return mutation.block;
  }

  Future<void> deleteBlock(BlockItem block) async {
    final mutation = await _repository.deleteBlock(block,
        expectedRevision: currentRevision, editorSessionId: editorSessionId);
    currentRevision = mutation.appliedRevision;
    blocks = blocks.where((item) => item.id != block.id).toList();
    notifyListeners();
  }

  Future<void> sendDraft(BlockItem block, String text) async {
    final page = selectedPage;
    if (page == null) return;
    _draftSequence += 1;
    await _realtime.sendBlockDraft(
      pageId: page.id,
      blockId: block.id,
      editorSessionId: editorSessionId,
      baseRevision: currentRevision,
      clientSequence: _draftSequence,
      textContent: text,
      type: block.type,
      propsJson: block.propsJson,
    );
  }

  String _defaultTextForType(String type) {
    return switch (type) {
      'heading_1' => 'Tiêu đề lớn',
      'heading_2' => 'Tiêu đề nhỏ',
      'heading_3' => 'Tiêu đề',
      'todo' => 'Việc cần làm',
      'quote' => 'Trích dẫn',
      'code' => '// code',
      'image' => '',
      'divider' => '',
      'table' => '',
      _ => '',
    };
  }

  String? _defaultPropsForType(String type) {
    if (type != 'table') return null;
    return jsonEncode({
      'rows': [
        ['Name', 'Status'],
        ['', ''],
      ],
      'hasHeader': true,
    });
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in ['PageCreated', 'PageUpdated', 'PageDeleted']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final id = workspaceId;
        if (id != null &&
            (payload.workspaceId == null || payload.workspaceId == id)) {
          _debounced(() => loadPages(id));
        }
      }));
    }
    for (final event in [
      'BlockCreated',
      'BlockUpdated',
      'BlockDeleted',
      'BlockLeaseChanged'
    ]) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final page = selectedPage;
        if (page != null &&
            (payload.pageId == null || payload.pageId == page.id)) {
          _debounced(() => loadDocument(page));
        }
      }));
    }
    _unsubscribe.add(_realtime.on('BlockDraftChanged', (payload) {
      final page = selectedPage;
      if (page != null &&
          (payload.pageId == null || payload.pageId == page.id)) {
        notifyListeners();
      }
    }));
    _unsubscribe
        .add(_realtime.on('PagePresenceChanged', (_) => notifyListeners()));
  }

  void _debounced(Future<void> Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () => action());
  }

  void _startPageHeartbeat(String pageId) {
    _pageHeartbeat?.cancel();
    _pageHeartbeat = Timer.periodic(
        const Duration(seconds: 25), (_) => _realtime.heartbeatPage(pageId));
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    _pageHeartbeat?.cancel();
    if (selectedPage != null) _realtime.leavePage(selectedPage!.id);
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
