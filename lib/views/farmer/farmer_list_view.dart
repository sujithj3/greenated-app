import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../view_models/farmer/farmer_list_view_model.dart';

/// Legacy view — Firestore stream replaced with 'No data found' placeholder.
/// Retains routing, AppBar, and FAB for future API wiring.
class FarmerListView extends StatefulWidget {
  const FarmerListView({super.key});

  @override
  State<FarmerListView> createState() => _FarmerListViewState();
}

class _FarmerListViewState extends State<FarmerListView> {
  late final FarmerListViewModel _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _vm = FarmerListViewModel();
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _vm.init(args);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_vm.title),
        ),
        body: const Center(
          child: Text('No data found'),
        ),
        floatingActionButton: _vm.viewOnly
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/farmer-form'),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
      ),
    );
  }
}
