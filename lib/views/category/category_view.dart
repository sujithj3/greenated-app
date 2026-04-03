import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../models/category/category_models.dart';
import '../../models/flow_type.dart';
import '../../services/form_config_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/category/category_view_model.dart';
import '../../widgets/shimmer_loading.dart';

class CategoryView extends StatefulWidget {
  const CategoryView({super.key});

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  late final CategoryViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CategoryViewModel(context.read<FormConfigService>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.fetchCategories();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final selectionMode = args['selectionMode'] as bool? ?? false;
    final flowType = args['flowType'] as FlowType? ?? FlowType.listing;
    final isRegistration = flowType == FlowType.registration;
    final title =
        (isRegistration || selectionMode) ? 'Select Category' : 'VCM Projects';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _buildBody(
          context: context,
          selectionMode: selectionMode,
          flowType: flowType,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool selectionMode,
    required FlowType flowType,
  }) {
    if (_vm.isLoading && _vm.categories.isEmpty) {
      return const ShimmerCategoryGrid();
    }

    if (_vm.error != null && _vm.categories.isEmpty) {
      return _CategoryFeedbackState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load categories',
        message: _vm.error!,
        actionLabel: 'Retry',
        onAction: () => _vm.fetchCategories(forceRefresh: true),
      );
    }

    if (_vm.categories.isEmpty) {
      return _CategoryFeedbackState(
        icon: Icons.category_outlined,
        title: 'No categories available',
        message: 'Categories will appear here once the backend returns data.',
        actionLabel: 'Refresh',
        onAction: () => _vm.fetchCategories(forceRefresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _vm.fetchCategories(forceRefresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
        ),
        itemCount: _vm.categories.length,
        itemBuilder: (_, index) {
          final category = _vm.categories[index];
          final data = AppCategories.styleFor(category.categoryName);

          return _CategoryCard(
            category: category,
            data: data,
            onTap: () {
              if (selectionMode) {
                Navigator.pop(context, category.categoryName);
                return;
              }

              Navigator.pushNamed(
                context,
                '/subcategories',
                arguments: <String, dynamic>{
                  'category': category.categoryName,
                  'flowType': flowType,
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.data,
    required this.onTap,
  });

  final CategoryModel category;
  final CategoryData? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = data?.color ?? AppColors.primary;
    final icon = data?.icon ?? Icons.category;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: <Color>[
              color.withValues(alpha: 0.85),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Text(
                category.categoryName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // const SizedBox(height: 4),
              // Row(
              //   children: <Widget>[
              //     const Icon(Icons.layers_outlined,
              //         color: Colors.white70, size: 14),
              //     const SizedBox(width: 4),
              //     Text(
              //       '${category.totalLandCount ?? 0} lands',
              //       style: const TextStyle(color: Colors.white70, fontSize: 12),
              //     ),
              //   ],
              // ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const Icon(Icons.list, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${category.subcategoryCount} ${category.subcategoryCount <= 1 ? 'subcategory' : 'subcategories'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFeedbackState extends StatelessWidget {
  const _CategoryFeedbackState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.textMedium),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
