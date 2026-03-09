import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/form_config_service.dart';
import '../../config/app_constants.dart';
import '../../widgets/shimmer_loading.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
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
    // selectionMode = true means this screen is used to PICK a category
    // (e.g. from FarmerFormScreen). Otherwise it navigates to subcategories.
    final bool selectionMode = args['selectionMode'] as bool? ?? false;
    final bool registrationFlow = args['registrationFlow'] as bool? ?? false;

    final fs = context.read<FirestoreService>();
    final svc = context.watch<FormConfigService>();

    final String title = registrationFlow
        ? 'Select Category'
        : selectionMode
            ? 'Select Category'
            : 'Farm Categories';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: svc.isLoading
          ? const ShimmerCategoryGrid()
          : StreamBuilder<Map<String, int>>(
              stream: fs.getCategoryCounts(),
              builder: (_, snap) {
                final counts = snap.data ?? {};
                final categories = AppCategories.all.entries.toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final name = categories[i].key;
                    final data = categories[i].value;
                    final count = counts[name] ?? 0;

                    return _CategoryCard(
                      name: name,
                      data: data,
                      farmerCount: count,
                      onTap: () {
                        if (selectionMode) {
                          Navigator.pop(context, name);
                        } else if (registrationFlow) {
                          Navigator.pushNamed(
                            context,
                            '/subcategories',
                            arguments: {
                              'category': name,
                              'registrationFlow': true,
                            },
                          );
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/subcategories',
                            arguments: {
                              'category': name,
                              'selectionMode': false,
                            },
                          );
                        }
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
  final String name;
  final CategoryData data;
  final int farmerCount;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.data,
    required this.farmerCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              data.color.withOpacity(0.85),
              data.color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$farmerCount farmers',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.list, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${data.subcategories.length} subcategories',
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
