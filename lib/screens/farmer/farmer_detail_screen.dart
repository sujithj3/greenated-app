import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/farmer/farmer_model.dart';
import '../../services/firestore_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../widgets/popup_form.dart';

class FarmerDetailScreen extends StatelessWidget {
  final String farmerId;
  const FarmerDetailScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return FutureBuilder<FarmerModel?>(
      future: fs.getFarmerById(farmerId),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final farmer = snap.data;
        if (farmer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Farmer Detail')),
            body: const Center(child: Text('Farmer not found.')),
          );
        }

        return _FarmerDetailView(farmer: farmer, fs: fs);
      },
    );
  }
}

class _FarmerDetailView extends StatelessWidget {
  final FarmerModel farmer;
  final FirestoreService fs;
  const _FarmerDetailView({required this.farmer, required this.fs});

  @override
  Widget build(BuildContext context) {
    final catData = AppCategories.all[farmer.category];
    final color = catData?.color ?? AppColors.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha:0.8), color],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha:0.2),
                      child: Text(
                        farmer.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      farmer.name ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(status: farmer.status),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/farmer-form',
                  arguments: {'farmer': farmer},
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),

          // ── Content ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick info row
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.phone,
                          label: farmer.phone ?? 'N/A',
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: catData?.icon ?? Icons.category,
                          label: farmer.category,
                          color: color),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Personal details card
                  _DetailCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    rows: [
                      _DetailRow(
                          'Full Name', farmer.name ?? 'Unknown', Icons.badge_outlined),
                      _DetailRow('Phone', farmer.phone ?? 'N/A', Icons.phone_outlined),
                      _DetailRow('Address', farmer.address,
                          Icons.location_on_outlined),
                      if (farmer.village.isNotEmpty)
                        _DetailRow(
                            'Village', farmer.village, Icons.house_outlined),
                      if (farmer.district.isNotEmpty)
                        _DetailRow(
                            'District', farmer.district, Icons.map_outlined),
                      if (farmer.state.isNotEmpty)
                        _DetailRow('State', farmer.state, Icons.flag_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Farm details card
                  _DetailCard(
                    title: 'Farm Details',
                    icon: Icons.eco_outlined,
                    rows: [
                      _DetailRow('Category', farmer.category,
                          catData?.icon ?? Icons.category_outlined),
                      _DetailRow('Subcategory', farmer.subcategory,
                          Icons.playlist_add_check_outlined),
                      _DetailRow(
                          'Land Area',
                          '${farmer.landArea} ${farmer.landUnit}',
                          Icons.square_foot_outlined),
                      _DetailRow(
                          'Status', farmer.status, Icons.toggle_on_outlined),
                      _DetailRow(
                          'Registered On',
                          DateFormat('dd MMMM yyyy')
                              .format(farmer.registrationDate),
                          Icons.calendar_today_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Land map card (if coordinates exist)
                  if (farmer.landCoordinates.isNotEmpty) ...[
                    _LandMapCard(farmer: farmer),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/farmer-form',
                            arguments: {'farmer': farmer},
                          ),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleStatus(context),
                          icon: Icon(
                            farmer.status == 'Active'
                                ? Icons.pause_circle_outline
                                : Icons.check_circle_outline,
                          ),
                          label: Text(farmer.status == 'Active'
                              ? 'Deactivate'
                              : 'Activate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: farmer.status == 'Active'
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showPopupConfirm(
      context,
      title: 'Delete Farmer',
      message:
          'Are you sure you want to permanently delete ${farmer.name ?? 'this farmer'}\'s record? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.error,
    );
    if (confirmed == true && context.mounted) {
      await fs.deleteFarmer(farmer.id!);
      if (context.mounted) {
        context.showSnack('Farmer record deleted.');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleStatus(BuildContext context) async {
    final newStatus = farmer.status == 'Active' ? 'Inactive' : 'Active';
    await fs.updateFarmer(farmer.copyWith(status: newStatus));
    if (context.mounted) {
      context.showSnack('Status updated to $newStatus.', success: true);
      Navigator.pop(context); // refresh by going back
    }
  }
}

// ─── Land Map Card ───────────────────────────────────────────────────────────
class _LandMapCard extends StatefulWidget {
  final FarmerModel farmer;
  const _LandMapCard({required this.farmer});

  @override
  State<_LandMapCard> createState() => _LandMapCardState();
}

class _LandMapCardState extends State<_LandMapCard> {
  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = widget.farmer.landCoordinates
        .map((c) => LatLng(c['lat']!, c['lng']!))
        .toList();

    if (points.isEmpty) return const SizedBox.shrink();

    final center = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.landscape, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Land Boundary',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.farmer.landArea} ${widget.farmer.landUnit}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: center, zoom: 16),
                mapType: MapType.hybrid,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                polygons: {
                  Polygon(
                    polygonId: const PolygonId('land'),
                    points: points,
                    fillColor: AppColors.primary.withValues(alpha:0.25),
                    strokeColor: AppColors.primary,
                    strokeWidth: 2,
                  ),
                },
                markers: points.asMap().entries.map((e) {
                  return Marker(
                    markerId: MarkerId('pt_${e.key}'),
                    position: e.value,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  );
                }).toSet(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Card ─────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;
  const _DetailCard(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.dark,
                    )),
              ],
            ),
            const Divider(height: 20),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DetailRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMedium),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMedium, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small Widgets ───────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha:0.5)),
      ),
      child: Text(status,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
