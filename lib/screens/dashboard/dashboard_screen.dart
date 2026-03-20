import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // commented out – only used by _RecentFarmers
import 'package:provider/provider.dart';
// import '../../models/farmer/farmer_model.dart'; // commented out – only used by _RecentFarmers
import '../../models/flow_type.dart';
import '../../services/auth_service.dart';
import '../../services/form_config_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../widgets/popup_form.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final categoriesService = context.watch<FormConfigService>();
    final phone = auth.displayPhone.isNotEmpty ? auth.displayPhone : 'User';

    if (!categoriesService.isLoading &&
        categoriesService.categories.isEmpty &&
        categoriesService.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<FormConfigService>().fetchCategories();
        }
      });
    }

    return Scaffold(
      drawer: _buildDrawer(context, auth, phone),
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<FormConfigService>().fetchCategories(forceRefresh: true),
        child: CustomScrollView(
        slivers: [
          // ── SliverAppBar ──────────────────────────────────────────────
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
                      'Good ${_greeting()}, 👋',
                      style: const TextStyle(
                        color: AppColors.light,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
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
                  // ── Quick Actions (hidden for now) ────────────────────
                  // const Text(
                  //   'Quick Actions',
                  //   style: TextStyle(
                  //     fontSize: 16,
                  //     fontWeight: FontWeight.w700,
                  //     color: AppColors.dark,
                  //   ),
                  // ),
                  // const SizedBox(height: 12),
                  // _QuickActions(),
                  // const SizedBox(height: 24),

                  // ── Recent Registrations (hidden – replaced by categories grid) ──
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     const Text(
                  //       'Recent Registrations',
                  //       style: TextStyle(
                  //         fontSize: 16,
                  //         fontWeight: FontWeight.w700,
                  //         color: AppColors.dark,
                  //       ),
                  //     ),
                  //     TextButton(
                  //       onPressed: () =>
                  //           Navigator.pushNamed(context, '/farmer-list'),
                  //       child: const Text('See All'),
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 8),
                  // _RecentFarmers(fs: fs),
                  // const SizedBox(height: 24),

                  // ── Categories Grid ────────────────────────────────────
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CategoriesGrid(service: categoriesService),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
        ),
      ),

      // ── Register Farmer FAB (hidden) ─────────────────────────────────
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () => Navigator.pushNamed(context, '/categories',
      //       arguments: {'flowType': FlowType.registration}),
      //   backgroundColor: AppColors.primary,
      //   icon: const Icon(Icons.person_add, color: Colors.white),
      //   label: const Text('Register Farmer',
      //       style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      // ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthService auth,
    String phone,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.dark, AppColors.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.light,
                  child: Icon(Icons.eco, color: AppColors.dark, size: 28),
                ),
                const SizedBox(height: 10),
                const Text('FARMER REGISTRATION',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                Text(phone,
                    style:
                        const TextStyle(color: AppColors.light, fontSize: 12)),
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
                await context.read<AuthService>().signOut();
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

// ─── Categories Grid ───────────────────────────────────────────────────────

class _CategoriesGrid extends StatelessWidget {
  final FormConfigService service;

  const _CategoriesGrid({required this.service});

  @override
  Widget build(BuildContext context) {
    if (service.isLoading && service.categories.isEmpty) {
      return const SizedBox(
        height: 260,
        child: ShimmerCategoryGrid(),
      );
    }

    if (service.error != null && service.categories.isEmpty) {
      return _DashboardCategoryState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load categories',
        message: service.error!,
        actionLabel: 'Retry',
        onAction: () => service.fetchCategories(forceRefresh: true),
      );
    }

    if (service.categories.isEmpty) {
      return _DashboardCategoryState(
        icon: Icons.category_outlined,
        title: 'No categories available',
        message: 'Categories from the backend will appear here.',
        actionLabel: 'Refresh',
        onAction: () => service.fetchCategories(forceRefresh: true),
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
      itemCount: service.categories.length,
      itemBuilder: (_, i) {
        final category = service.categories[i];
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

// ─── Quick Actions (hidden – kept for future use) ──────────────────────────
// ignore: unused_element
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QAction(
          Icons.person_add,
          'New\nRegister',
          AppColors.primary,
          () => Navigator.pushNamed(context, '/categories',
              arguments: {'flowType': FlowType.registration})),
      _QAction(Icons.people, 'View\nFarmers', AppColors.medium,
          () => Navigator.pushNamed(context, '/farmer-list')),
      _QAction(
          Icons.category,
          'Categories',
          AppColors.dark,
          () => Navigator.pushNamed(context, '/categories',
              arguments: {'flowType': FlowType.listing})),
      _QAction(Icons.map, 'Land\nMap', AppColors.accent,
          () => Navigator.pushNamed(context, '/land-measurement')),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      children: actions.map((a) => _buildAction(a)).toList(),
    );
  }

  Widget _buildAction(_QAction a) {
    return InkWell(
      onTap: a.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: a.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, color: a.color, size: 28),
            const SizedBox(height: 6),
            Text(
              a.label,
              style: TextStyle(
                  fontSize: 10, color: a.color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QAction(this.icon, this.label, this.color, this.onTap);
}

// ─── Recent Farmers (hidden – kept for future use) ─────────────────────────
// class _RecentFarmers extends StatelessWidget {
//   final FirestoreService fs;
//   const _RecentFarmers({required this.fs});
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<List<FarmerModel>>(
//       stream: fs.getFarmers(),
//       builder: (_, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Center(
//             child: Padding(
//               padding: EdgeInsets.all(24),
//               child: CircularProgressIndicator(),
//             ),
//           );
//         }
//         final farmers = (snap.data ?? []).take(5).toList();
//         if (farmers.isEmpty) {
//           return _EmptyState();
//         }
//         return Column(
//           children: farmers
//               .map((f) => _FarmerTile(
//                     farmer: f,
//                     onTap: () => Navigator.pushNamed(context, '/farmer-detail',
//                         arguments: f.id),
//                   ))
//               .toList(),
//         );
//       },
//     );
//   }
// }
//
// class _EmptyState extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: AppColors.veryLight,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: const Column(
//         children: [
//           Icon(Icons.people_outline, size: 48, color: AppColors.light),
//           SizedBox(height: 12),
//           Text('No farmers registered yet.',
//               style: TextStyle(color: AppColors.textMedium)),
//           SizedBox(height: 4),
//           Text('Tap the button below to add one.',
//               style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
//         ],
//       ),
//     );
//   }
// }
//
// class _FarmerTile extends StatelessWidget {
//   final FarmerModel farmer;
//   final VoidCallback onTap;
//   const _FarmerTile({required this.farmer, required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 8),
//       child: ListTile(
//         onTap: onTap,
//         leading: CircleAvatar(
//           backgroundColor: AppColors.light,
//           child: Text(
//             farmer.initials,
//             style: const TextStyle(
//                 color: AppColors.dark, fontWeight: FontWeight.w700),
//           ),
//         ),
//         title: Text(farmer.name ?? 'Unknown',
//             style: const TextStyle(fontWeight: FontWeight.w600)),
//         subtitle:
//             Text('${farmer.category} · ${farmer.landArea} ${farmer.landUnit}'),
//         trailing: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//               decoration: BoxDecoration(
//                 color: farmer.status == 'Active'
//                     ? AppColors.veryLight
//                     : Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 farmer.status,
//                 style: TextStyle(
//                   fontSize: 11,
//                   color: farmer.status == 'Active'
//                       ? AppColors.primary
//                       : Colors.grey,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               DateFormat('dd MMM').format(farmer.registrationDate),
//               style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
