// Registered farmers list view — browses existing registrations.
//
// Displays a paginated, searchable list of farmers registered under the given
// subcategoryId, with infinite scroll and an expandable search bar. Selecting
// an item opens its FarmerDetailView.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flow_type.dart';
import '../../utils/app_colors.dart';
import '../../view_models/registered_list_view_model.dart';
import '../../models/registered_farmers_list.dart';
import '../../widgets/shimmer_loading.dart';

class RegisteredListView extends StatefulWidget {
  final FlowType flowType;
  final int subcategoryId;
  final String category;
  final String subcategory;

  const RegisteredListView({
    super.key,
    required this.flowType,
    required this.subcategoryId,
    this.category = '',
    this.subcategory = '',
  });

  @override
  State<RegisteredListView> createState() => _RegisteredListViewState();
}

class _RegisteredListViewState extends State<RegisteredListView> {
  static const Duration _searchAnimationDuration = Duration(milliseconds: 250);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<RegisteredListViewModel>()
          .loadFirstPage(widget.subcategoryId);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<RegisteredListViewModel>().loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegistration = widget.flowType == FlowType.registration;

    return Scaffold(
      floatingActionButton: isRegistration
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/farmer-form',
                  arguments: <String, dynamic>{
                    'category': widget.category,
                    'subcategory': widget.subcategory,
                    'subcategoryId': widget.subcategoryId,
                  },
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Register Farmer'),
            )
          : null,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: AnimatedSwitcher(
          duration: _searchAnimationDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                axis: Axis.horizontal,
                axisAlignment: -1,
                sizeFactor: animation,
                child: child,
              ),
            );
          },
          child: _isSearchExpanded
              ? _buildSearchField()
              : const Text(
                  'Registered List',
                  key: ValueKey('registered-list-title'),
                ),
        ),
        actions: [
          AnimatedSwitcher(
            duration: _searchAnimationDuration,
            child: _isSearchExpanded
                ? TextButton(
                    key: const ValueKey('registered-list-cancel'),
                    onPressed: _cancelSearch,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('registered-list-search'),
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: _expandSearch,
                  ),
          ),
        ],
      ),
      body: Consumer<RegisteredListViewModel>(
        builder: (context, viewModel, child) {
          final farmers = viewModel.visibleFarmers;
          final isInitialLoading = viewModel.isSearchMode
              ? viewModel.isSearching && farmers.isEmpty
              : viewModel.isLoading;

          if (isInitialLoading) {
            return const ShimmerRegisteredList();
          }

          if (!viewModel.isSearchMode &&
              viewModel.listError != null &&
              farmers.isEmpty) {
            return _buildScrollableState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load registered farmers',
              subtitle: viewModel.listError!,
              actionLabel: 'Retry',
              onAction: () => viewModel.loadFirstPage(widget.subcategoryId),
            );
          }

          if (farmers.isEmpty) {
            return _buildScrollableState(
              icon: viewModel.isSearchMode
                  ? Icons.search_off_outlined
                  : Icons.people_alt_outlined,
              title: viewModel.isSearchMode
                  ? 'No farmers found'
                  : 'No registered farmers',
              subtitle: viewModel.isSearchMode
                  ? 'Try searching with another farmer name, code, or mobile number.'
                  : 'Tap Register Farmer to add a farmer.',
              topMessage: viewModel.isSearchMode ? viewModel.searchError : null,
              onTopRetry: viewModel.isSearchMode
                  ? () => viewModel.refresh(widget.subcategoryId)
                  : null,
              onRefresh: () => viewModel.refresh(widget.subcategoryId),
            );
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.refresh(widget.subcategoryId),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              slivers: [
                if (viewModel.isSearchMode && viewModel.searchError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _SearchErrorBanner(
                        message: viewModel.searchError!,
                        onRetry: () => viewModel.refresh(widget.subcategoryId),
                      ),
                    ),
                  ),
                if (viewModel.isSearchMode && viewModel.isSearching)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final farmer = farmers[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == farmers.length - 1 ? 0 : 12,
                          ),
                          child: _buildFarmerCard(farmer),
                        );
                      },
                      childCount: farmers.length,
                    ),
                  ),
                ),
                if (viewModel.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      key: const ValueKey('registered-list-search-field'),
      valueListenable: _searchController,
      builder: (context, value, child) {
        return SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            cursorColor: AppColors.primary,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              height: 1.2,
            ),
            textInputAction: TextInputAction.search,
            onChanged: _handleSearchChanged,
            decoration: InputDecoration(
              hintText: 'Name, Farmer ID',
              hintStyle: TextStyle(
                color: AppColors.textMedium.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textMedium,
                size: 20,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textMedium,
                        size: 20,
                      ),
                      onPressed: _clearSearchText,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
      },
    );
  }

  void _expandSearch() {
    if (_isSearchExpanded) return;
    setState(() => _isSearchExpanded = true);

    Future<void>.delayed(_searchAnimationDuration, () {
      if (mounted && _isSearchExpanded) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  Future<void> _cancelSearch() async {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _isSearchExpanded = false);
    _jumpToTop();
    await context
        .read<RegisteredListViewModel>()
        .clearSearch(widget.subcategoryId);
  }

  Future<void> _clearSearchText() async {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _jumpToTop();
    await context
        .read<RegisteredListViewModel>()
        .clearSearch(widget.subcategoryId);
    if (mounted && _isSearchExpanded) {
      _searchFocusNode.requestFocus();
    }
  }

  void _handleSearchChanged(String value) {
    _jumpToTop();
    context
        .read<RegisteredListViewModel>()
        .updateSearchQuery(widget.subcategoryId, value);
  }

  void _jumpToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 0) return;
    _scrollController.jumpTo(0);
  }

  Widget _buildScrollableState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    String? topMessage,
    VoidCallback? onTopRetry,
    Future<void> Function()? onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh ??
          () async {
            await context
                .read<RegisteredListViewModel>()
                .loadFirstPage(widget.subcategoryId);
          },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (topMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SearchErrorBanner(
                  message: topMessage,
                  onRetry: onTopRetry,
                ),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyRegisteredListState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(RegisteredFarmersList farmer) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/farmer-detail',
            arguments: {
              'subcategoryId': widget.subcategoryId,
              'farmerId': farmer.farmerId,
            },
          );
          if (result == true && mounted) {
            context
                .read<RegisteredListViewModel>()
                .loadFirstPage(widget.subcategoryId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmer.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    // const SizedBox(height: 1),
                    Text(
                      farmer.farmerCode,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (farmer.registeredByName != null &&
                        farmer.registeredByName!.isNotEmpty)
                      Text(
                        'Registered by: ${farmer.registeredByName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                  ],
                ),
              ),
              // const SizedBox(width: 8),
              // Text(
              //   farmer.formName,
              //   style: const TextStyle(
              //     fontSize: 14,
              //     fontWeight: FontWeight.w500,
              //     color: AppColors.primary,
              //   ),
              //   textAlign: TextAlign.right,
              // ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMedium, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchErrorBanner extends StatelessWidget {
  const _SearchErrorBanner({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRegisteredListState extends StatelessWidget {
  const _EmptyRegisteredListState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textMedium),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
