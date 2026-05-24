import '../../../core/utils/json_utils.dart';

class BlockItem {
  const BlockItem({
    required this.id,
    required this.pageId,
    required this.type,
    required this.textContent,
    this.propsJson,
    this.parentBlockId,
    this.orderKey = '',
  });

  final String id;
  final String pageId;
  final String type;
  final String textContent;
  final String? propsJson;
  final String? parentBlockId;
  final String orderKey;

  factory BlockItem.fromJson(JsonMap json) => BlockItem(
        id: asString(json['id']),
        pageId: asString(json['pageId']),
        type: asString(json['type'], 'paragraph'),
        textContent: asString(json['textContent']),
        propsJson: json['propsJson']?.toString(),
        parentBlockId: json['parentBlockId']?.toString(),
        orderKey: asString(json['orderKey']),
      );

  BlockItem copyWith({String? type, String? textContent, String? propsJson}) => BlockItem(
        id: id,
        pageId: pageId,
        type: type ?? this.type,
        textContent: textContent ?? this.textContent,
        propsJson: propsJson ?? this.propsJson,
        parentBlockId: parentBlockId,
        orderKey: orderKey,
      );
}

class PageDocument {
  const PageDocument({required this.pageId, required this.currentRevision, required this.blocks});

  final String pageId;
  final int currentRevision;
  final List<BlockItem> blocks;

  factory PageDocument.fromJson(JsonMap json) => PageDocument(
        pageId: asString(json['pageId']),
        currentRevision: asInt(json['currentRevision']),
        blocks: asMapList(json['blocks']).map(BlockItem.fromJson).toList(),
      );
}

class BlockMutation {
  const BlockMutation({required this.pageId, this.blockId, required this.appliedRevision, this.block});

  final String pageId;
  final String? blockId;
  final int appliedRevision;
  final BlockItem? block;

  factory BlockMutation.fromJson(JsonMap json) => BlockMutation(
        pageId: asString(json['pageId']),
        blockId: json['blockId']?.toString(),
        appliedRevision: asInt(json['appliedRevision']),
        block: json['block'] == null ? null : BlockItem.fromJson(asMap(json['block'])),
      );
}
