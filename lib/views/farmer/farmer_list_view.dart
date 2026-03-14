import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../view_models/farmer/farmer_list_view_model.dart';

class FarmerListView extends StatefulWidget {
  const FarmerListView({super.key});

  @override
  State<FarmerListView> createState() => _FarmerListViewState();
}

class _FarmerListViewState extends State<FarmerListView> {
  final _searchCtrl = TextEditingController();
  late final FarmerListViewModel _vm;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _vm = FarmerListViewModel(context.read<FirestoreService>());
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _vm.init(args);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_vm.title),
          bottom: _vm.hasNavFilter
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: _buildSearchBar(),
                ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              tooltip: 'Filter',
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'all', child: Text('All Farmers')),
                const PopupMenuItem(
                    value: 'Active', child: Text('Active Only')),
                const PopupMenuItem(
                    value: 'Inactive', child: Text('Inactive Only')),
              ],
              onSelected: (v) => _vm.setStatusFilter(v == 'all' ? null : v),
            ),
          ],
        ),
        body: StreamBuilder<List<FarmerModel>>(
          stream: _vm.farmersStream,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: AppColors.error)),
              );
            }

            final farmers = _vm.applyFilters(snap.data ?? []);

            if (farmers.isEmpty) {
              return _EmptyList(
                query: _vm.searchQuery,
                viewOnly: _vm.viewOnly,
                onRegister: () => Navigator.pushNamed(context, '/farmer-form'),
              );
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.veryLight,
                  child: Text(
                    '${farmers.length} farmer${farmers.length != 1 ? 's' : ''} found',
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: farmers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _FarmerCard(
                      farmer: farmers[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/farmer-detail',
                        arguments: farmers[i].id,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => _vm.setSearch(v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name, phone, village...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          suffixIcon: _vm.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchCtrl.clear();
                    _vm.setSearch('');
                  },
                )
              : null,
          fillColor: Colors.white.withValues(alpha: 0.2),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final FarmerModel farmer;
  final VoidCallback onTap;
  const _FarmerCard({required this.farmer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catData = AppCategories.all[farmer.category];
    final color = catData?.color ?? AppColors.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(farmer.initials,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farmer.name ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textDark)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.phone,
                          size: 13, color: AppColors.textMedium),
                      const SizedBox(width: 4),
                      Text(farmer.phone ?? 'N/A',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Tag(label: farmer.category, color: color),
                      const SizedBox(width: 6),
                      if (farmer.subcategory.isNotEmpty)
                        _Tag(
                            label: farmer.subcategory, color: AppColors.medium),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: farmer.status),
                  const SizedBox(height: 6),
                  Text('${farmer.landArea} ${farmer.landUnit}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd MMM yy').format(farmer.registrationDate),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMedium)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : Colors.grey)),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String query;
  final bool viewOnly;
  final VoidCallback onRegister;
  const _EmptyList({
    required this.query,
    this.viewOnly = false,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(query.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 72, color: AppColors.light),
          const SizedBox(height: 16),
          Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : viewOnly
                      ? 'No data found'
                      : 'No farmers registered yet',
              style:
                  const TextStyle(fontSize: 16, color: AppColors.textMedium)),
          const SizedBox(height: 8),
          if (query.isEmpty && !viewOnly) ...[
            const Text('Tap the button to register the first farmer.',
                style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.person_add),
              label: const Text('Register Farmer'),
            ),
          ],
        ],
      ),
    );
  }
}
