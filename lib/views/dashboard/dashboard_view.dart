import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/dashboard/dashboard_view_model.dart';
import '../../widgets/popup_form.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardViewModel(
        ctx.read<AuthService>(),
        ctx.read<FirestoreService>(),
      ),
      child: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          final phone = vm.displayPhone.isNotEmpty ? vm.displayPhone : 'User';

          return Scaffold(
            drawer: _buildDrawer(context, vm, phone),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 160,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
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
                          Text('Good ${vm.greeting}, ',
                              style: const TextStyle(
                                  color: AppColors.light, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(phone,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    title: const Text('Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
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
                        _StatsRow(vm: vm),
                        const SizedBox(height: 24),
                        const Text('Quick Actions',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark)),
                        const SizedBox(height: 12),
                        _QuickActions(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Recent Registrations',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark)),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/farmer-list'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _RecentFarmers(vm: vm),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/farmer-form'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Register Farmer',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(
      BuildContext context, DashboardViewModel vm, String phone) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppColors.dark, AppColors.primary]),
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
              context, Icons.person_add, 'Register Farmer', '/farmer-form'),
          _drawerItem(context, Icons.people, 'Farmers List', '/farmer-list'),
          _drawerItem(context, Icons.category, 'Categories', '/categories'),
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
                await vm.signOut();
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
      BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        if (ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DashboardViewModel vm;
  const _StatsRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: vm.totalCount,
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
            stream: vm.activeCount,
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
            stream: vm.categoryCounts,
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

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QAction(Icons.person_add, 'Register\nFarmer', AppColors.primary,
          () => Navigator.pushNamed(context, '/farmer-form')),
      _QAction(Icons.people, 'View\nFarmers', AppColors.medium,
          () => Navigator.pushNamed(context, '/farmer-list')),
      _QAction(Icons.category, 'Categories', AppColors.dark,
          () => Navigator.pushNamed(context, '/categories')),
      _QAction(Icons.map, 'Land\nMap', AppColors.accent,
          () => Navigator.pushNamed(context, '/land-measurement')),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      children: actions.map((a) {
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
                Text(a.label,
                    style: TextStyle(
                        fontSize: 10,
                        color: a.color,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
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

class _RecentFarmers extends StatelessWidget {
  final DashboardViewModel vm;
  const _RecentFarmers({required this.vm});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FarmerModel>>(
      stream: vm.recentFarmers,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator()),
          );
        }
        final farmers = (snap.data ?? []).take(5).toList();
        if (farmers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.veryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: AppColors.light),
                SizedBox(height: 12),
                Text('No farmers registered yet.',
                    style: TextStyle(color: AppColors.textMedium)),
                SizedBox(height: 4),
                Text('Tap the button below to add one.',
                    style:
                        TextStyle(color: AppColors.textMedium, fontSize: 12)),
              ],
            ),
          );
        }
        return Column(
          children: farmers
              .map((f) => _FarmerTile(
                    farmer: f,
                    onTap: () => Navigator.pushNamed(context, '/farmer-detail',
                        arguments: f.id),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _FarmerTile extends StatelessWidget {
  final FarmerModel farmer;
  final VoidCallback onTap;
  const _FarmerTile({required this.farmer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.light,
          child: Text(farmer.initials,
              style: const TextStyle(
                  color: AppColors.dark, fontWeight: FontWeight.w700)),
        ),
        title: Text(farmer.name ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Text('${farmer.category} · ${farmer.landArea} ${farmer.landUnit}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: farmer.status == 'Active'
                    ? AppColors.veryLight
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(farmer.status,
                  style: TextStyle(
                      fontSize: 11,
                      color: farmer.status == 'Active'
                          ? AppColors.primary
                          : Colors.grey,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM').format(farmer.registrationDate),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMedium)),
          ],
        ),
      ),
    );
  }
}
