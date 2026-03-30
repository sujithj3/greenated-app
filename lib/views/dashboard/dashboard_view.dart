import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../models/flow_type.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/dashboard/dashboard_view_model.dart';
import '../../widgets/popup_form.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final DashboardViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = DashboardViewModel(
      context.read<AuthService>(),
      context.read<FormConfigService>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _vm.categories.isEmpty && !_vm.isCategoriesLoading) {
        _vm.fetchCategories();
      }
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          drawer: _buildDrawer(context),
          body: RefreshIndicator(
            onRefresh: () => _vm.fetchCategories(forceRefresh: true),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 160,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  title: const Text('Dashboard',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  centerTitle: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.dark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Good ${_vm.greeting}, 👋',
                            style: const TextStyle(
                              color: AppColors.light,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _vm.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CategoriesGrid(vm: _vm),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.dark, AppColors.primary],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 5,
                  bottom: -35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/greenated-logo-white.png',
                        width: screenWidth * 0.45,
                        fit: BoxFit.contain,
                      ),
                      // const SizedBox(height: 10),
                      // const Text('FARMER REGISTRATION',
                      //     style: TextStyle(
                      //         color: Colors.white,
                      //         fontSize: 18,
                      //         fontWeight: FontWeight.w800,
                      //         letterSpacing: 2)),
                      // Text(_vm.displayPhone,
                      //     style:
                      //         const TextStyle(color: AppColors.light, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _drawerItem(context, Icons.dashboard, 'Dashboard', '/dashboard'),
          _drawerItem(
              context, Icons.person_add, 'Register Farmer', '/categories',
              arguments: {'flowType': FlowType.registration}),
          _drawerItem(context, Icons.people, 'Farmers List', '/farmer-list'),
          _drawerItem(context, Icons.category, 'Categories', '/categories',
              arguments: {'flowType': FlowType.listing}),
          _drawerItem(
              context, Icons.map, 'Land Measurement', '/land-measurement'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await showPopupConfirm(
                context,
                title: 'Logout',
                message: 'Are you sure you want to logout?',
              );
              if (confirmed == true && context.mounted) {
                await _vm.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, IconData icon, String label, String route,
      {Object? arguments}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        if (ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route, arguments: arguments);
        }
      },
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  final DashboardViewModel vm;

  const _CategoriesGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isCategoriesLoading && vm.categories.isEmpty) {
      return const ShimmerCategoryGrid();
    }

    if (vm.categoriesError != null && vm.categories.isEmpty) {
      return _DashboardCategoryState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load categories',
        message: vm.categoriesError!,
        actionLabel: 'Retry',
        onAction: () => vm.fetchCategories(forceRefresh: true),
      );
    }

    if (vm.categories.isEmpty) {
      return _DashboardCategoryState(
        icon: Icons.category_outlined,
        title: 'No categories available',
        message: 'Categories from the backend will appear here.',
        actionLabel: 'Refresh',
        onAction: () => vm.fetchCategories(forceRefresh: true),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: vm.categories.length,
      itemBuilder: (_, i) {
        final category = vm.categories[i];
        final data = AppCategories.styleFor(category.categoryName);

        return _CategoryTile(
          name: category.categoryName,
          data: data,
          subcategoryCount: category.subcategoryCount,
          landCount: category.totalLandCount ?? 0,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/subcategories',
              arguments: {
                'category': category.categoryName,
                'flowType': FlowType.registration,
              },
            );
          },
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final CategoryData? data;
  final int subcategoryCount;
  final int landCount;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.data,
    required this.subcategoryCount,
    required this.landCount,
    required this.onTap,
  });

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
            colors: [
              color.withValues(alpha: 0.85),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
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
            children: [
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
                  const Icon(Icons.layers_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$landCount lands',
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
                    '$subcategoryCount subcategories',
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

class _DashboardCategoryState extends StatelessWidget {
  const _DashboardCategoryState({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textMedium),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
