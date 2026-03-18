import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // commented out – only used by _RecentFarmers
import 'package:provider/provider.dart';
// import '../../models/farmer/farmer_model.dart'; // commented out – only used by _RecentFarmers
import '../../models/flow_type.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../widgets/popup_form.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fs = context.read<FirestoreService>();
    final phone = auth.displayPhone.isNotEmpty ? auth.displayPhone : 'User';

    return Scaffold(
      drawer: _buildDrawer(context, auth, phone),
      body: CustomScrollView(
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
                  // ── Stats Row ──────────────────────────────────────────
                  _StatsRow(fs: fs),
                  const SizedBox(height: 24),

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
                  _CategoriesGrid(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildDrawer(BuildContext context, AuthService auth, String phone) {
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
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (_) => false);
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

// ─── Stats Row ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final FirestoreService fs;
  const _StatsRow({required this.fs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: fs.getTotalCount(),
            builder: (_, snap) => _StatCard(
              label: 'Total Farmers',
              value: '${snap.data ?? 0}',
              icon: Icons.people,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<int>(
            stream: fs.getActiveCount(),
            builder: (_, snap) => _StatCard(
              label: 'Active',
              value: '${snap.data ?? 0}',
              icon: Icons.check_circle_outline,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<Map<String, int>>(
            stream: fs.getCategoryCounts(),
            builder: (_, snap) => _StatCard(
              label: 'Categories',
              value: '${snap.data?.length ?? 0}',
              icon: Icons.category,
              color: AppColors.medium,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMedium),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Categories Grid ───────────────────────────────────────────────────────
class _CategoriesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categories = AppCategories.all.entries.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final name = categories[i].key;
        final data = categories[i].value;

        return _CategoryTile(
          name: name,
          data: data,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/subcategories',
              arguments: {
                'category': name,
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
  final CategoryData data;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.data,
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
              data.color.withValues(alpha: 0.85),
              data.color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.3),
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

// ─── Quick Actions (hidden – kept for future use) ──────────────────────────
// ignore: unused_element
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QAction(Icons.person_add, 'New\nRegister', AppColors.primary,
          () => Navigator.pushNamed(context, '/categories',
              arguments: {'flowType': FlowType.registration})),
      _QAction(Icons.people, 'View\nFarmers', AppColors.medium,
          () => Navigator.pushNamed(context, '/farmer-list')),
      _QAction(Icons.category, 'Categories', AppColors.dark,
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
