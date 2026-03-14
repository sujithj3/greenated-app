import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/category/subcategory_view_model.dart';

class SubcategoryView extends StatelessWidget {
  const SubcategoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String category = args['category'] as String? ?? '';
    final bool selectionMode = args['selectionMode'] as bool? ?? false;
    final bool registrationFlow = args['registrationFlow'] as bool? ?? false;
    final catData = AppCategories.all[category];

    return ChangeNotifierProvider(
      create: (ctx) => SubcategoryViewModel(
        ctx.read<FirestoreService>(),
        ctx.read<FormConfigService>(),
      ),
      child: Consumer<SubcategoryViewModel>(
        builder: (context, vm, _) {
          final subcategories = vm.getSubcategoryNames(category);

          return Scaffold(
            appBar: AppBar(
              title: Text(selectionMode ? 'Select Subcategory' : category),
              backgroundColor: catData?.color ?? AppColors.primary,
            ),
            body: Column(
              children: [
                if (!selectionMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    color: (catData?.color ?? AppColors.primary)
                        .withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        Icon(
                          catData?.icon ?? Icons.category,
                          color: catData?.color ?? AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: catData?.color ?? AppColors.primary,
                              ),
                            ),
                            Text(
                              '${subcategories.length} subcategories',
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
                    itemBuilder: (_, i) {
                      final sub = subcategories[i];
                      return _SubcategoryTile(
                        subcategory: sub,
                        category: category,
                        catData: catData,
                        selectionMode: selectionMode,
                        countStream:
                            vm.getFarmersByCategoryAndSub(category, sub),
                        onTap: () {
                          if (selectionMode) {
                            Navigator.pop(context, sub);
                          } else if (registrationFlow) {
                            // Registration flow → open farmer form
                            Navigator.pushNamed(
                              context,
                              '/farmer-form',
                              arguments: {
                                'category': category,
                                'subcategory': sub,
                              },
                            );
                          } else {
                            // Browse flow → show farmer list
                            Navigator.pushNamed(
                              context,
                              '/farmer-list',
                              arguments: {
                                'category': category,
                                'subcategory': sub,
                                'viewOnly': true,
                              },
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: registrationFlow
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/farmer-form',
                      arguments: {'category': category},
                    ),
                    backgroundColor: catData?.color ?? AppColors.primary,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Register Farmer',
                        style: TextStyle(color: Colors.white)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final String subcategory;
  final String category;
  final CategoryData? catData;
  final bool selectionMode;
  final Stream<List> countStream;
  final VoidCallback onTap;

  const _SubcategoryTile({
    required this.subcategory,
    required this.category,
    required this.catData,
    required this.selectionMode,
    required this.countStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = catData?.color ?? AppColors.primary;

    return StreamBuilder<List>(
      stream: countStream,
      builder: (_, snap) {
        final count = snap.data?.length ?? 0;

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
              subcategory,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              selectionMode ? category : '$count farmers registered',
              style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
            trailing: selectionMode
                ? const Icon(Icons.check_circle_outline,
                    color: AppColors.primary)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count',
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
      },
    );
  }
}
