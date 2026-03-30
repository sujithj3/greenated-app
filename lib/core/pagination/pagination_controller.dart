import 'pagination.dart';

/// A controller to manage [Pagination] state and logic independently of API or UI.
class PaginationController<T> {
  Pagination<T> state;

  PaginationController()
      : state = Pagination<T>(
          data: [],
          currentPage: 1,
        );

  /// Resets the pagination state to its initial values.
  void reset() {
    state = Pagination<T>(
      data: [],
      currentPage: 1,
      hasMore: true,
    );
  }

  /// Sets the state to initial loading.
  void startInitialLoading() {
    state = state.copyWith(isLoading: true);
  }

  /// Stops the initial loading state.
  void stopInitialLoading() {
    state = state.copyWith(isLoading: false);
  }

  /// Safely starts a "load more" operation if not already loading and if more data is available.
  void startLoadMore() {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
  }

  /// Stops the "load more" loading state.
  void stopLoadMore() {
    state = state.copyWith(isLoadingMore: false);
  }

  /// Appends new data to the list, updates the current page, and determines if more data exists.
  void appendData(List<T> newData, {bool? hasMoreOverride}) {
    final updatedList = [...state.data, ...newData];

    // Determine if more data can be fetched based on the fixed pageSize logic or override
    final hasMore = hasMoreOverride ?? (newData.length >= state.pageSize);

    state = state.copyWith(
      data: updatedList,
      currentPage: state.currentPage + 1,
      hasMore: hasMore,
      isLoading: false,
      isLoadingMore: false,
    );
  }

  /// Resets loading states in case of an error safely without losing data.
  void setError() {
    state = state.copyWith(
      isLoading: false,
      isLoadingMore: false,
    );
  }
}
