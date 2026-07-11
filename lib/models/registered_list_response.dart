import 'registered_farmers_list.dart';

/// Pagination metadata for a list response.
///
/// Describes where a returned page sits within the full result set: the
/// current [page], the [pageSize], and the totals ([totalItems], [totalPages])
/// across all pages. Parsed from backend JSON with sensible defaults for any
/// missing field.
class PaginationMeta {
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  PaginationMeta({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pageSize': pageSize,
      'totalItems': totalItems,
      'totalPages': totalPages,
    };
  }
}

/// A single paginated page of registered farmers as returned by the backend.
///
/// This is the backbone of the registered-farmers list feature: it couples a
/// page of [RegisteredFarmersList] rows with the [PaginationMeta] describing
/// that page's position in the overall result set. [fromJson] parses the
/// server envelope — synthesising a single-page [DetailedPaginationMeta] when
/// the response omits pagination — and [toJson] serializes it back.
class RegisteredListResponse {
  final List<RegisteredFarmersList> registeredFarmers;
  final PaginationMeta pagination;

  RegisteredListResponse({
    required this.registeredFarmers,
    required this.pagination,
  });

  factory RegisteredListResponse.fromJson(Map<String, dynamic> json) {
    var farmersJson = (json['registeredFarmers'] as List?) ?? [];
    DetailedPaginationMeta? meta;

    if (json['pagination'] != null) {
      meta = DetailedPaginationMeta.fromJson(
          json['pagination'] as Map<String, dynamic>);
    } else {
      meta = DetailedPaginationMeta(
          page: 1, pageSize: 10, totalItems: farmersJson.length, totalPages: 1);
    }

    return RegisteredListResponse(
      registeredFarmers: farmersJson
          .whereType<Map>()
          .map((e) => RegisteredFarmersList.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registeredFarmers': registeredFarmers.map((e) => e.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

// Rename the internal PaginationMeta alias to avoid conflict or just use the same name.
// Actually, let's keep it clean:
/// The [PaginationMeta] variant used by [RegisteredListResponse].
///
/// Behaviourally identical to its base class today; it exists as a distinct
/// type so the registered-farmers response can evolve its pagination shape
/// independently without affecting other consumers of [PaginationMeta].
class DetailedPaginationMeta extends PaginationMeta {
  DetailedPaginationMeta({
    required super.page,
    required super.pageSize,
    required super.totalItems,
    required super.totalPages,
  });

  factory DetailedPaginationMeta.fromJson(Map<String, dynamic> json) {
    return DetailedPaginationMeta(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pageSize': pageSize,
      'totalItems': totalItems,
      'totalPages': totalPages,
    };
  }
}
