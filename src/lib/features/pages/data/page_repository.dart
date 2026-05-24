import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';

class PageRepository {
  const PageRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PageItem>> pages(String workspaceId, {String? keyword}) {
    final path = keyword == null || keyword.trim().isEmpty ? 'workspaces/$workspaceId/pages' : 'workspaces/$workspaceId/pages:search';
    return _apiClient.get<List<PageItem>>(
      path,
      query: {'pageNumber': 1, 'pageSize': 100, if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim()},
      parser: (json) => parsePagedItems(json, PageItem.fromJson),
    );
  }

  Future<PageItem> createPage(String workspaceId, {required String title, String? parentPageId, String? icon}) {
    return _apiClient.post<PageItem>(
      'workspaces/$workspaceId/pages',
      data: {'title': title, 'parentPageId': parentPageId, 'icon': icon},
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<PageItem> updatePage(PageItem page, {required String title, String? icon, String? coverImage}) {
    return _apiClient.patch<PageItem>(
      'pages/${page.id}',
      data: {'expectedRevision': page.currentRevision, 'title': title, 'icon': icon ?? page.icon, 'coverImage': coverImage ?? page.coverImage},
      parser: (json) => PageItem.fromJson(asMap(json)),
    );
  }

  Future<PageDocument> document(String pageId) {
    return _apiClient.get<PageDocument>('pages/$pageId/blocks', parser: (json) => PageDocument.fromJson(asMap(json)));
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
      data: {'expectedRevision': expectedRevision, 'editorSessionId': editorSessionId, 'textContent': textContent, 'type': type, 'propsJson': propsJson ?? block.propsJson},
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }

  Future<BlockMutation> deleteBlock(BlockItem block, {required int expectedRevision, required String editorSessionId}) {
    return _apiClient.delete<BlockMutation>(
      'blocks/${block.id}',
      query: {'expectedRevision': expectedRevision, 'editorSessionId': editorSessionId},
      headers: {'X-Editor-Session-Id': editorSessionId},
      parser: (json) => BlockMutation.fromJson(asMap(json)),
    );
  }
}
