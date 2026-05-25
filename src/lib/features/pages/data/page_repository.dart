import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';

class PageRepository {
  const PageRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PageItem>> pages(String workspaceId, {String? keyword}) {
    final path = keyword == null || keyword.trim().isEmpty
        ? 'workspaces/$workspaceId/pages'
        : 'workspaces/$workspaceId/pages:search';

    return _apiClient.get<List<PageItem>>(
      path,
      query: {
        'pageNumber': 1,
        'pageSize': 100,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
      parser: (json) => parsePagedItems(json, PageItem.fromJson),
    );
  }

  Future<List<PageItem>> trashPages(String workspaceId) {
    return _apiClient.get<List<PageItem>>(
      'workspaces/$workspaceId/pages/trash',
      query: const {'pageNumber': 1, 'pageSize': 100},
      parser: (json) => parsePagedItems(json, PageItem.fromJson),
    );
  }

  Future<PageItem> createPage(
    String workspaceId, {
    required String title,
    String? parentPageId,
    String? icon,
  }) {
    return _apiClient.post<PageItem>(
      'workspaces/$workspaceId/pages',
      data: {
        'title': title,
        'parentPageId': parentPageId,
        'icon': icon,
      },
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<PageItem> updatePage(
    PageItem page, {
    required String title,
    String? icon,
    String? coverImage,
  }) {
    return _apiClient.patch<PageItem>(
      'pages/${page.id}',
      data: {
        'expectedRevision': page.currentRevision,
        'title': title,
        'icon': icon ?? page.icon,
        'coverImage': coverImage ?? page.coverImage,
      },
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<PageItem> duplicatePage(PageItem page) {
    return _apiClient.post<PageItem>(
      'pages/${page.id}/duplicate',
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<void> deletePage(PageItem page) {
    return _apiClient.delete<void>(
      'pages/${page.id}',
      parser: (_) {},
    );
  }

  Future<PageItem> restorePage(PageItem page) {
    return _apiClient.post<PageItem>(
      'pages/${page.id}/restore',
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<PageItem> favoritePage(PageItem page) {
    return _apiClient.post<PageItem>(
      'pages/${page.id}/favorite',
      parser: (json) =>
          PageItem.fromJson(asMap(json)).copyWith(isFavorite: true),
    );
  }

  Future<void> unfavoritePage(PageItem page) {
    return _apiClient.delete<void>(
      'pages/${page.id}/favorite',
      parser: (_) {},
    );
  }

  Future<PageDocument> document(String pageId) {
    return _apiClient.get<PageDocument>(
      'pages/$pageId/blocks',
      parser: (json) => PageDocument.fromJson(asMap(json)),
    );
  }

  Future<BlockMutation> createBlock(
    String pageId, {
    required int expectedRevision,
    required String type,
    String? textContent,
    String? previousBlockId,
    String? nextBlockId,
    String? parentBlockId,
    String? propsJson,
  }) {
    return _apiClient.post<BlockMutation>(
      'pages/$pageId/blocks',
      data: {
        'expectedRevision': expectedRevision,
        'type': type,
        'textContent': textContent,
        'propsJson': propsJson,
        'previousBlockId': previousBlockId,
        'nextBlockId': nextBlockId,
        'parentBlockId': parentBlockId,
        'schemaVersion': 1,
      },
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }

  Future<BlockMutation> updateBlock(
    BlockItem block, {
    required int expectedRevision,
    required String editorSessionId,
    required String textContent,
    required String type,
    String? propsJson,
  }) {
    return _apiClient.patch<BlockMutation>(
      'blocks/${block.id}',
      data: {
        'expectedRevision': expectedRevision,
        'editorSessionId': editorSessionId,
        'textContent': textContent,
        'type': type,
        'propsJson': propsJson,
      },
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }

  Future<BlockMutation> moveBlock(
    BlockItem block, {
    required int expectedRevision,
    required String editorSessionId,
    String? newParentBlockId,
    String? previousBlockId,
    String? nextBlockId,
  }) {
    return _apiClient.post<BlockMutation>(
      'blocks/${block.id}:move',
      data: {
        'expectedRevision': expectedRevision,
        'editorSessionId': editorSessionId,
        'newParentBlockId': newParentBlockId,
        'previousBlockId': previousBlockId,
        'nextBlockId': nextBlockId,
      },
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }

  Future<BlockMutation> deleteBlock(
    BlockItem block, {
    required int expectedRevision,
    required String editorSessionId,
    String? note,
  }) {
    return _apiClient.delete<BlockMutation>(
      'blocks/${block.id}',
      query: {
        'expectedRevision': expectedRevision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      headers: {'X-Editor-Session-Id': editorSessionId},
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }

  Future<BlockLease> getBlockLease(BlockItem block) {
    return _apiClient.get<BlockLease>(
      'blocks/${block.id}/edit-lease',
      parser: (json) => BlockLease.fromJson(asMap(json)),
    );
  }

  Future<BlockLease> acquireBlockLease(
    BlockItem block, {
    required String editorSessionId,
    String? holderDisplayName,
  }) {
    return _apiClient.post<BlockLease>(
      'blocks/${block.id}:acquire-edit-lease',
      data: {
        'editorSessionId': editorSessionId,
        if (holderDisplayName != null && holderDisplayName.trim().isNotEmpty)
          'holderDisplayName': holderDisplayName.trim(),
      },
      parser: (json) => BlockLease.fromJson(asMap(json)),
    );
  }

  Future<BlockLease> renewBlockLease(
    BlockItem block, {
    required String editorSessionId,
  }) {
    return _apiClient.post<BlockLease>(
      'blocks/${block.id}:renew-edit-lease',
      data: {'editorSessionId': editorSessionId},
      parser: (json) => BlockLease.fromJson(asMap(json)),
    );
  }

  Future<BlockLease> releaseBlockLease(
    BlockItem block, {
    required String editorSessionId,
  }) {
    return _apiClient.post<BlockLease>(
      'blocks/${block.id}:release-edit-lease',
      data: {'editorSessionId': editorSessionId},
      parser: (json) => BlockLease.fromJson(asMap(json)),
    );
  }
}
