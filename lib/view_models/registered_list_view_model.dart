import 'package:flutter/foundation.dart';
import '../core/pagination/pagination_controller.dart';
import '../models/registered_farmer.dart';
import '../repositories/registered_list_repository.dart';
import '../services/auth_service.dart';

class RegisteredListViewModel extends ChangeNotifier {
  final RegisteredListRepository _repository;
  final AuthService _authService;
  final PaginationController<RegisteredFarmer> paginationController;

  RegisteredListViewModel({
    required RegisteredListRepository repository,
    required AuthService authService,
  })  : _repository = repository,
        _authService = authService,
        paginationController = PaginationController<RegisteredFarmer>();

  int? _subcategoryId;

  bool get isLoading => paginationController.state.isLoading;
  bool get isLoadingMore => paginationController.state.isLoadingMore;
  List<RegisteredFarmer> get farmers => paginationController.state.data;

  Future<void> loadFirstPage(int subcategoryId) async {
    final userId = _authService.userId;
    if (userId == null) return;

    _subcategoryId = subcategoryId;
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

      final hasMore = response.pagination.page < response.pagination.totalPages;

      paginationController.appendData(
        response.farmers,
        hasMoreOverride: hasMore,
      );
    } catch (e) {
      debugPrint('Error fetching registered list: $e');
      paginationController.setError();
    } finally {
      paginationController.stopInitialLoading();
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (paginationController.state.isLoadingMore || 
        !paginationController.state.hasMore || 
        _subcategoryId == null) {
      return;
    }

    final userId = _authService.userId;
    if (userId == null) return;

    paginationController.startLoadMore();
    notifyListeners();

    try {
      final response = await _repository.fetchRegisteredList(
        subcategoryId: _subcategoryId!,
        userId: userId,
        page: paginationController.state.currentPage,
        pageSize: paginationController.state.pageSize,
      );

      final hasMore = response.pagination.page < response.pagination.totalPages;

      paginationController.appendData(
        response.farmers,
        hasMoreOverride: hasMore,
      );
    } catch (e) {
      debugPrint('Error fetching more registered list: $e');
      paginationController.setError();
    } finally {
      paginationController.stopLoadMore();
      notifyListeners();
    }
  }
}
