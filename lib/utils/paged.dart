/// The shared page/limit pagination envelope used by admin-facing list
/// endpoints (`GET /interests/admin/all`, `GET /categories/admin`, …).
///
/// See docs §Pagination envelope:
/// ```json
/// { "items": [...], "total": 137, "page": 2, "pageSize": 20, "pageCount": 7 }
/// ```
/// `pageCount` is always ≥ 1 (an empty result still reports one page), and a
/// `page` past the end returns an empty `items`, never an error.
class Paged {
  const Paged({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pageCount,
  });

  final List<dynamic> items;
  final int total;
  final int page;
  final int pageSize;
  final int pageCount;

  /// Whether another page exists after this one.
  bool get hasMore => page < pageCount;

  factory Paged.fromJson(Map<dynamic, dynamic> json) {
    int asInt(Object? v, [int fallback = 0]) =>
        v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;
    final items = json['items'];
    return Paged(
      items: items is List ? items : const [],
      total: asInt(json['total']),
      page: asInt(json['page'], 1),
      pageSize: asInt(json['pageSize'], 20),
      pageCount: asInt(json['pageCount'], 1),
    );
  }
}
