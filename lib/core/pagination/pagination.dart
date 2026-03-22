/// A generic, immutable data model representing paginated data.
class Pagination<T> {
  final List<T> data;
  final int currentPage;
  final int pageSize;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  const Pagination({
    required this.data,
    required this.currentPage,
    this.pageSize = 10,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  /// Creates a copy of this [Pagination] but with the given fields replaced with the new values.
  Pagination<T> copyWith({
    List<T>? data,
    int? currentPage,
    int? pageSize,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return Pagination<T>(
      data: data ?? this.data,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
