import 'registered_farmer.dart';

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

class RegisteredListResponse {
  final List<RegisteredFarmer> farmers;
  final PaginationMeta pagination;

  RegisteredListResponse({
    required this.farmers,
    required this.pagination,
  });

  factory RegisteredListResponse.fromJson(Map<String, dynamic> json) {
    var farmersJson = (json['registeredFarmers'] as List?) ?? [];
    DetailedPaginationMeta? meta;
    
    if (json['pagination'] != null) {
      meta = DetailedPaginationMeta.fromJson(json['pagination'] as Map<String, dynamic>);
    } else {
      meta = DetailedPaginationMeta(page: 1, pageSize: 10, totalItems: farmersJson.length, totalPages: 1);
    }
    
    return RegisteredListResponse(
      farmers: farmersJson
          .whereType<Map>()
          .map((e) => RegisteredFarmer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pagination: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmers': farmers.map((e) => e.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

// Rename the internal PaginationMeta alias to avoid conflict or just use the same name.
// Actually, let's keep it clean:
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
