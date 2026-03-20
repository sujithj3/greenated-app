import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class FarmerListScreen extends StatelessWidget {
  const FarmerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final String? navSubcategory = args?['subcategory'] as String?;
    final String? navCategory = args?['category'] as String?;
    final bool viewOnly = args?['viewOnly'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(navSubcategory ?? navCategory ?? 'All Farmers'),
      ),
      body: const Center(
        child: Text('No data found'),
      ),
      floatingActionButton: viewOnly
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/farmer-form'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
    );
  }
}
