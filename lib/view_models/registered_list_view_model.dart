import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/pagination/pagination.dart';
import '../core/pagination/pagination_controller.dart';
import '../models/registered_farmers_list.dart';
import '../repositories/registered_list_repository.dart';
import '../services/auth_service.dart';

class RegisteredListViewModel extends ChangeNotifier {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 450);
  static const int _minimumServerSearchLength = 2;

  final RegisteredListRepository _repository;
  final AuthService _authService;
  final PaginationController<RegisteredFarmersList> paginationController;
  final PaginationController<RegisteredFarmersList> searchPaginationController;

  RegisteredListViewModel({
    required RegisteredListRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService,
        paginationController = PaginationController<RegisteredFarmersList>(),
        searchPaginationController =
            PaginationController<RegisteredFarmersList>();

  int? _subcategoryId;
  Timer? _searchDebounce;
  int _listGeneration = 0;
  int _searchGeneration = 0;
  String _searchQuery = '';
  String? _listError;
  String? _searchError;

  bool get isLoading => paginationController.state.isLoading;
  bool get isSearching => searchPaginationController.state.isLoading;
  bool get isSearchMode => _searchQuery.isNotEmpty;
  bool get isLoadingMore => isSearchMode
      ? searchPaginationController.state.isLoadingMore
      : paginationController.state.isLoadingMore;
  bool get hasMore => isSearchMode
      ? searchPaginationController.state.hasMore
      : paginationController.state.hasMore;
  int get currentPage => paginationController.state.currentPage;
  int get searchPage => searchPaginationController.state.currentPage;
  String get searchQuery => _searchQuery;
  String? get listError => _listError;
  String? get searchError => _searchError;
  List<RegisteredFarmersList> get registeredFarmers =>
      paginationController.state.data;
  List<RegisteredFarmersList> get searchRegisteredFarmers =>
      searchPaginationController.state.data;
  List<RegisteredFarmersList> get visibleFarmers =>
      isSearchMode ? searchRegisteredFarmers : registeredFarmers;

  Future<void> loadFirstPage(
    int subcategoryId, {
    bool resetSearch = true,
  }) async {
    final userId = _authService.userId;
    if (userId == null) return;

    if (resetSearch) {
      _resetSearchState();
    }

    _subcategoryId = subcategoryId;
    _listError = null;
    _listGeneration++;
    final generation = _listGeneration;
    paginationController.reset();
    paginationController.startInitialLoading();
    notifyListeners();

    try {
      final response = await _repository.fetchRegisteredList(
        subcategoryId: subcategoryId,
        userId: userId,
        page: paginationController.state.currentPage,
        pageSize: paginationController.state.pageSize,
      );

      if (generation != _listGeneration) return;

      final hasMore = response.pagination.page < response.pagination.totalPages;
      final farmers = _withoutExistingFarmerIds(
        existing: const <RegisteredFarmersList>[],
        incoming: response.registeredFarmers,
      );

      paginationController.appendData(
        farmers,
        hasMoreOverride: hasMore,
      );
    } catch (e) {
      if (generation != _listGeneration) return;
      debugPrint('Error fetching registered list: $e');
      _listError = 'Unable to load registered farmers. Please try again.';
      paginationController.setError();
    } finally {
      if (generation == _listGeneration) {
        paginationController.stopInitialLoading();
        notifyListeners();
      }
    }
  }

  Future<void> loadNextPage() async {
    if (isSearchMode) {
      await _loadNextSearchPage();
      return;
    }

    if (paginationController.state.isLoading ||
        paginationController.state.isLoadingMore ||
        !paginationController.state.hasMore ||
        _subcategoryId == null) {
      return;
    }

    final userId = _authService.userId;
    if (userId == null) return;

    paginationController.startLoadMore();
    final generation = _listGeneration;
    notifyListeners();

    try {
      final response = await _repository.fetchRegisteredList(
        subcategoryId: _subcategoryId!,
        userId: userId,
        page: paginationController.state.currentPage,
        pageSize: paginationController.state.pageSize,
      );

      if (generation != _listGeneration) return;

      final hasMore = response.pagination.page < response.pagination.totalPages;
      final farmers = _withoutExistingFarmerIds(
        existing: paginationController.state.data,
        incoming: response.registeredFarmers,
      );

      paginationController.appendData(
        farmers,
        hasMoreOverride: hasMore,
      );
    } catch (e) {
      if (generation != _listGeneration) return;
      debugPrint('Error fetching more registered list: $e');
      paginationController.setError();
    } finally {
      if (generation == _listGeneration) {
        paginationController.stopLoadMore();
        notifyListeners();
      }
    }
  }

  Future<void> refresh(int subcategoryId) async {
    if (!isSearchMode) {
      await loadFirstPage(subcategoryId, resetSearch: false);
      return;
    }

    if (_searchQuery.length < _minimumServerSearchLength) {
      _applyLocalSearchResults(_searchQuery, shouldLoadFromServer: false);
      notifyListeners();
      return;
    }

    _searchGeneration++;
    final generation = _searchGeneration;
    await _fetchSearchPage(
      subcategoryId: subcategoryId,
      query: _searchQuery,
      page: 1,
      generation: generation,
      replace: true,
    );
  }

  void updateSearchQuery(int subcategoryId, String value) {
    _subcategoryId = subcategoryId;
    final query = value.trim();

    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchError = null;

    if (query.isEmpty) {
      _resetSearchState();
      notifyListeners();
      unawaited(loadFirstPage(subcategoryId, resetSearch: false));
      return;
    }

    _searchQuery = query;
    final shouldLoadFromServer = query.length >= _minimumServerSearchLength;
    _applyLocalSearchResults(
      query,
      shouldLoadFromServer: shouldLoadFromServer,
    );
    notifyListeners();

    if (!shouldLoadFromServer) return;

    final generation = _searchGeneration;
    _searchDebounce = Timer(_searchDebounceDuration, () {
      unawaited(
        _fetchSearchPage(
          subcategoryId: subcategoryId,
          query: query,
          page: 1,
          generation: generation,
          replace: true,
        ),
      );
    });
  }

  /// Resets all list and search state, discarding in-flight requests via the
  /// generation counters. The fetched farmers are scoped to the signed-in
  /// user — call this on sign-out so the next user never sees the previous
  /// user's list, even briefly.
  void clear() {
    _searchDebounce?.cancel();
    _listGeneration++;
    _searchGeneration++;
    _subcategoryId = null;
    _searchQuery = '';
    _listError = null;
    _searchError = null;
    paginationController.reset();
    searchPaginationController.reset();
    notifyListeners();
  }

  Future<void> clearSearch(int subcategoryId) async {
    _resetSearchState();
    notifyListeners();
    await loadFirstPage(subcategoryId, resetSearch: false);
  }

  void _resetSearchState() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchQuery = '';
    _searchError = null;
    searchPaginationController.reset();
    searchPaginationController.stopInitialLoading();
    searchPaginationController.stopLoadMore();
  }

  void _applyLocalSearchResults(
    String query, {
    required bool shouldLoadFromServer,
  }) {
    final matches = _localMatches(query);
    searchPaginationController.state = Pagination<RegisteredFarmersList>(
      data: matches,
      currentPage: 1,
      pageSize: searchPaginationController.state.pageSize,
      isLoading: shouldLoadFromServer,
      isLoadingMore: false,
      hasMore: false,
    );
  }

  List<RegisteredFarmersList> _localMatches(String query) {
    final normalized = query.toLowerCase();
    final matches = paginationController.state.data.where((farmer) {
      final code = farmer.farmerCode?.toLowerCase() ?? '';
      return farmer.fullName.toLowerCase().contains(normalized) ||
          code.contains(normalized) ||
          farmer.mobileNumber.toLowerCase().contains(normalized);
    }).toList();

    return _withoutExistingFarmerIds(
      existing: const <RegisteredFarmersList>[],
      incoming: matches,
    );
  }

  Future<void> _fetchSearchPage({
    required int subcategoryId,
    required String query,
    required int page,
    required int generation,
    required bool replace,
  }) async {
    final userId = _authService.userId;
    if (userId == null) return;
    if (generation != _searchGeneration || query != _searchQuery) return;

    if (replace && !searchPaginationController.state.isLoading) {
      searchPaginationController.startInitialLoading();
      notifyListeners();
    }

    try {
      final response = await _repository.fetchRegisteredList(
        subcategoryId: subcategoryId,
        userId: userId,
        page: page,
        pageSize: searchPaginationController.state.pageSize,
        search: query,
      );

      if (generation != _searchGeneration || query != _searchQuery) return;

      final hasMore = response.pagination.page < response.pagination.totalPages;
      final newData = replace
          ? _withoutExistingFarmerIds(
              existing: const <RegisteredFarmersList>[],
              incoming: response.registeredFarmers,
            )
          : _withoutExistingFarmerIds(
              existing: searchPaginationController.state.data,
              incoming: response.registeredFarmers,
            );

      if (replace) {
        searchPaginationController.state = Pagination<RegisteredFarmersList>(
          data: newData,
          currentPage: response.pagination.page + 1,
          pageSize: searchPaginationController.state.pageSize,
          isLoading: false,
          isLoadingMore: false,
          hasMore: hasMore,
        );
      } else {
        searchPaginationController.appendData(
          newData,
          hasMoreOverride: hasMore,
        );
      }
      _searchError = null;
    } catch (e) {
      if (generation != _searchGeneration || query != _searchQuery) return;
      debugPrint('Error searching registered list: $e');
      _searchError = 'Unable to search. Please try again.';
      searchPaginationController.setError();
    } finally {
      if (generation == _searchGeneration && query == _searchQuery) {
        searchPaginationController.stopInitialLoading();
        searchPaginationController.stopLoadMore();
        notifyListeners();
      }
    }
  }

  Future<void> _loadNextSearchPage() async {
    if (searchPaginationController.state.isLoading ||
        searchPaginationController.state.isLoadingMore ||
        !searchPaginationController.state.hasMore ||
        _subcategoryId == null ||
        _searchQuery.length < _minimumServerSearchLength) {
      return;
    }

    searchPaginationController.startLoadMore();
    notifyListeners();

    await _fetchSearchPage(
      subcategoryId: _subcategoryId!,
      query: _searchQuery,
      page: searchPaginationController.state.currentPage,
      generation: _searchGeneration,
      replace: false,
    );
  }

  List<RegisteredFarmersList> _withoutExistingFarmerIds({
    required List<RegisteredFarmersList> existing,
    required List<RegisteredFarmersList> incoming,
  }) {
    final seen = existing.map((farmer) => farmer.farmerId).toSet();
    final result = <RegisteredFarmersList>[];

    for (final farmer in incoming) {
      if (seen.add(farmer.farmerId)) {
        result.add(farmer);
      }
    }

    return result;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
