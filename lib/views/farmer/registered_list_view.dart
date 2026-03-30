import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flow_type.dart';
import '../../utils/app_colors.dart';
import '../../view_models/registered_list_view_model.dart';
import '../../models/registered_farmer.dart';
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
  final ScrollController _scrollController = ScrollController();

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
        title: const Text('Registered List'),
      ),
      body: Consumer<RegisteredListViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerRegisteredList();
          }

          if (viewModel.farmers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await viewModel.loadFirstPage(widget.subcategoryId);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_outlined,
                              size: 64, color: AppColors.textMedium),
                          const SizedBox(height: 16),
                          const Text('No records found.',
                              style: TextStyle(
                                  fontSize: 18, color: AppColors.textMedium)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                viewModel.loadFirstPage(widget.subcategoryId),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await viewModel.loadFirstPage(widget.subcategoryId);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  viewModel.farmers.length + (viewModel.isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == viewModel.farmers.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final farmer = viewModel.farmers[index];
                return _buildFarmerCard(farmer);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFarmerCard(RegisteredFarmer farmer) {
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
              'submissionId': farmer.submissionId,
            },
          );
          if (result == true && context.mounted) {
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
                    const SizedBox(height: 4),
                    Text(
                      farmer.mobileNumber,
                      style: const TextStyle(
                        fontSize: 14,
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
