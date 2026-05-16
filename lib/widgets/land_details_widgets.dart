import 'package:flutter/material.dart';

import '../models/api/api_models.dart';
import '../utils/app_colors.dart';

class LandDetailsSection extends StatelessWidget {
  const LandDetailsSection({
    super.key,
    required this.lands,
    required this.onLandTap,
  });

  final List<LandDetail> lands;
  final void Function(LandDetail land, int index, String title) onLandTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Land Details - (${lands.length})',
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        if (lands.isEmpty)
          const EmptyLandDetailsView()
        else
          ...lands.indexed.map(
            (entry) {
              final title = landDisplayTitle(entry.$2, entry.$1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LandDetailCard(
                  land: entry.$2,
                  title: title,
                  onTap: () => onLandTap(entry.$2, entry.$1, title),
                ),
              );
            },
          ),
      ],
    );
  }
}

class LandDetailCard extends StatelessWidget {
  const LandDetailCard({
    super.key,
    required this.land,
    required this.title,
    required this.onTap,
  });

  final LandDetail land;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code =
        land.landCode?.trim().isNotEmpty == true ? land.landCode!.trim() : '-';

    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      code,
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMedium,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyLandDetailsView extends StatelessWidget {
  const EmptyLandDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: AppColors.light,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 360),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.veryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/ic-land-green.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) {
                  // TODO: Add assets/images/ic-land-green.png to project assets.
                  return const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.primary,
                    size: 76,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No land added yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below\nto add land.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddNewLandButton extends StatelessWidget {
  const AddNewLandButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/ic-land-green.png',
                  width: 30,
                  height: 30,
                  color: AppColors.white,
                  errorBuilder: (_, __, ___) {
                    // TODO: Add assets/images/ic-land-green.png to project assets.
                    return const Icon(
                      Icons.landscape_outlined,
                      color: AppColors.white,
                      size: 18,
                    );
                  },
                ),
                const SizedBox(width: 1),
                const Text(
                  'Add New Land',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BottomUpdateButton extends StatelessWidget {
  const BottomUpdateButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

String landDisplayTitle(LandDetail land, int index) {
  if (land.landTitle?.trim().isNotEmpty == true) {
    return land.landTitle!.trim();
  }
  return 'Land ${_numberWord(index + 1)}';
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final metric in metrics) {
      var distance = 0.0;
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

String _numberWord(int value) {
  return switch (value) {
    1 => 'One',
    2 => 'Two',
    3 => 'Three',
    4 => 'Four',
    5 => 'Five',
    6 => 'Six',
    7 => 'Seven',
    8 => 'Eight',
    9 => 'Nine',
    10 => 'Ten',
    _ => value.toString(),
  };
}
