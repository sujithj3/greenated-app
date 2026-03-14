import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shimmer_loading.dart';

class SubcategoryScreen extends StatefulWidget {
  const SubcategoryScreen({super.key});

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure categories (with subcategories) are loaded from mock/real API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FormConfigService>().fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String category = args['category'] as String? ?? '';
    final bool selectionMode = args['selectionMode'] as bool? ?? false;
    final bool registrationFlow = args['registrationFlow'] as bool? ?? false;

    final catData = AppCategories.all[category];
    final svc = context.watch<FormConfigService>();
    final subcategories = svc.getSubcategoryNames(category);
    final fs = context.read<FirestoreService>();

    final bool isPickMode = selectionMode || registrationFlow;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPickMode ? 'Select Subcategory' : category),
        backgroundColor: catData?.color ?? AppColors.primary,
      ),
      body: Column(
        children: [
          // Category header banner
          if (!isPickMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              color: (catData?.color ?? AppColors.primary).withOpacity(0.1),
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

          // Subcategory list
          Expanded(
            child: svc.isLoading
                ? const ShimmerSubcategoryList()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: subcategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final sub = subcategories[i];
                      return _SubcategoryTile(
                        subcategory: sub,
                        category: category,
                        catData: catData,
                        selectionMode: isPickMode,
                        fs: fs,
                        onTap: () {
                          if (selectionMode) {
                            Navigator.pop(context, sub);
                          } else {
                            // navigate directly to farmer registration form
                            final subData = svc.getCategoryByName(category)?.findSubcategory(sub);
                            Navigator.pushNamed(
                              context,
                              '/farmer-form',
                              arguments: {
                                'category': category,
                                'subcategory': sub,
                                'subcategoryId': subData?.id,
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
      // FAB removed — subcategory tap directly triggers registration
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final String subcategory;
  final String category;
  final CategoryData? catData;
  final bool selectionMode;
  final FirestoreService fs;
  final VoidCallback onTap;

  const _SubcategoryTile({
    required this.subcategory,
    required this.category,
    required this.catData,
    required this.selectionMode,
    required this.fs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = catData?.color ?? AppColors.primary;

    return StreamBuilder<List>(
      stream: fs.getFarmersByCategoryAndSub(category, subcategory),
      builder: (_, snap) {
        final count = snap.data?.length ?? 0;

        return Card(
          child: ListTile(
            onTap: onTap,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
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
                            color: color.withOpacity(0.12),
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
