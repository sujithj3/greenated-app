import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../models/category/category_models.dart';
import '../../models/flow_type.dart';
import '../../services/form_config_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/category/subcategory_view_model.dart';
import '../../widgets/shimmer_loading.dart';

class SubcategoryView extends StatefulWidget {
  const SubcategoryView({super.key});

  @override
  State<SubcategoryView> createState() => _SubcategoryViewState();
}

class _SubcategoryViewState extends State<SubcategoryView> {
  late final SubcategoryViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SubcategoryViewModel(context.read<FormConfigService>());
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
    final categoryName = args['category'] as String? ?? '';
    final selectionMode = args['selectionMode'] as bool? ?? false;
    final flowType = args['flowType'] as FlowType? ?? FlowType.listing;
    final catData = AppCategories.styleFor(categoryName);
    final isRegistration = flowType == FlowType.registration;
    final isPickMode = selectionMode || isRegistration;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPickMode ? 'Select Subcategory' : categoryName),
        backgroundColor: catData?.color ?? AppColors.primary,
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final category = _vm.getCategoryByName(categoryName);
          return _buildBody(
            context: context,
            categoryName: categoryName,
            category: category,
            catData: catData,
            isRegistration: isRegistration,
            isPickMode: isPickMode,
            flowType: flowType,
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required String categoryName,
    required CategoryModel? category,
    required CategoryData? catData,
    required bool isRegistration,
    required bool isPickMode,
    required FlowType flowType,
  }) {
    if (_vm.isLoading && category == null) {
      return const ShimmerSubcategoryList();
    }

    if (_vm.error != null && category == null) {
      return _SubcategoryFeedbackState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load subcategories',
        message: _vm.error!,
        actionLabel: 'Retry',
        onAction: () => _vm.fetchCategories(forceRefresh: true),
      );
    }

    if (category == null) {
      return _SubcategoryFeedbackState(
        icon: Icons.category_outlined,
        title: 'Category not found',
        message: 'The selected category is unavailable right now.',
        actionLabel: 'Refresh',
        onAction: () => _vm.fetchCategories(forceRefresh: true),
      );
    }

    final subcategories = category.subcategories;
    if (subcategories.isEmpty) {
      return _SubcategoryFeedbackState(
        icon: Icons.list_alt_outlined,
        title: 'No subcategories available',
        message: 'This category does not have any subcategories yet.',
        actionLabel: 'Refresh',
        onAction: () => _vm.fetchCategories(forceRefresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _vm.fetchCategories(forceRefresh: true),
      child: Column(
        children: <Widget>[
          if (!isPickMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              color:
                  (catData?.color ?? AppColors.primary).withValues(alpha: 0.1),
              child: Row(
                children: <Widget>[
                  Icon(
                    catData?.icon ?? Icons.category,
                    color: catData?.color ?? AppColors.primary,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.categoryName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: catData?.color ?? AppColors.primary,
                        ),
                      ),
                      Text(
                        '${category.subcategoryCount} subcategories',
                        style: const TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subcategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final subcategory = subcategories[index];
                return _SubcategoryTile(
                  subcategory: subcategory,
                  categoryName: categoryName,
                  catData: catData,
                  selectionMode: isPickMode,
                  onTap: () {
                    if (isPickMode && !isRegistration) {
                      Navigator.pop(context, subcategory.subcategoryName);
                      return;
                    }

                    if (isRegistration) {
                      Navigator.pushNamed(
                        context,
                        '/farmer-form',
                        arguments: <String, dynamic>{
                          'category': categoryName,
                          'subcategory': subcategory.subcategoryName,
                          'subcategoryId': subcategory.subcategoryId,
                        },
                      );
                      return;
                    }

                    Navigator.pushNamed(
                      context,
                      '/registered-farmers',
                      arguments: {
                        'flowType': flowType,
                        'subcategoryId': subcategory.subcategoryId,
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.subcategory,
    required this.categoryName,
    required this.catData,
    required this.selectionMode,
    required this.onTap,
  });

  final SubcategoryModel subcategory;
  final String categoryName;
  final CategoryData? catData;
  final bool selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = catData?.color ?? AppColors.primary;
    final subtitle = selectionMode
        ? categoryName
        : '${subcategory.farmerCount} farmers · ${subcategory.landCount ?? 0} lands';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Icon(catData?.icon ?? Icons.category, color: color, size: 22),
        ),
        title: Text(
          subcategory.subcategoryName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
        ),
        trailing: selectionMode
            ? const Icon(Icons.check_circle_outline,
                color: AppColors.primary)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${subcategory.farmerCount}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textMedium),
                ],
              ),
      ),
    );
  }
}

class _SubcategoryFeedbackState extends StatelessWidget {
  const _SubcategoryFeedbackState({
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
