import '../../../core/utils/json_utils.dart';

class PageItem {
  const PageItem({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.parentPageId,
    this.icon,
    this.coverImage,
    this.isArchived = false,
    this.isFavorite = false,
    this.currentRevision = 0,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? parentPageId;
  final String? icon;
  final String? coverImage;
  final bool isArchived;
  final bool isFavorite;
  final int currentRevision;

  factory PageItem.fromJson(JsonMap json) => PageItem(
        id: asString(json['id']),
        workspaceId: asString(json['workspaceId']),
        title: asString(json['title'], 'Untitled'),
        parentPageId: json['parentPageId']?.toString(),
        icon: json['icon']?.toString(),
        coverImage: json['coverImage']?.toString(),
        isArchived: asBool(json['isArchived']),
        isFavorite: asBool(json['isFavorite']),
        currentRevision: asInt(json['currentRevision']),
      );

  PageItem copyWith({
    String? title,
    String? icon,
    String? coverImage,
    bool? isArchived,
    bool? isFavorite,
    int? currentRevision,
  }) =>
      PageItem(
        id: id,
        workspaceId: workspaceId,
        title: title ?? this.title,
        parentPageId: parentPageId,
        icon: icon ?? this.icon,
        coverImage: coverImage ?? this.coverImage,
        isArchived: isArchived ?? this.isArchived,
        isFavorite: isFavorite ?? this.isFavorite,
        currentRevision: currentRevision ?? this.currentRevision,
      );
}
