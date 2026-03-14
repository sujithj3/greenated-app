import 'package:flutter/material.dart';

// ─── Shimmer animation wrapper ───────────────────────────────────────────────

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 3.0 * _controller.value, 0),
              end: Alignment(0.0 + 3.0 * _controller.value, 0),
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

// ─── Shimmer block placeholder ───────────────────────────────────────────────

class ShimmerBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ─── Category grid shimmer ───────────────────────────────────────────────────

class ShimmerCategoryGrid extends StatelessWidget {
  const ShimmerCategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBlock(width: 48, height: 48, borderRadius: 12),
              const Spacer(),
              const ShimmerBlock(width: 100, height: 14, borderRadius: 4),
              const SizedBox(height: 8),
              const ShimmerBlock(width: 70, height: 10, borderRadius: 4),
              const SizedBox(height: 4),
              const ShimmerBlock(width: 90, height: 10, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subcategory list shimmer ────────────────────────────────────────────────

class ShimmerSubcategoryList extends StatelessWidget {
  const ShimmerSubcategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            children: [
              ShimmerBlock(width: 44, height: 44, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBlock(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBlock(width: 100, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Form skeleton shimmer ───────────────────────────────────────────────────

class ShimmerFormSkeleton extends StatelessWidget {
  const ShimmerFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Section 1 header
          _shimmerSectionHeader(),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),

          const SizedBox(height: 24),

          // Section 2 header
          _shimmerSectionHeader(),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),

          const SizedBox(height: 24),

          // Section 3 header
          _shimmerSectionHeader(),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 48, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: ShimmerBlock(height: 52, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBlock(height: 52, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 52, borderRadius: 12),

          const SizedBox(height: 24),

          // Section 4 header
          _shimmerSectionHeader(),
          const SizedBox(height: 12),
          const ShimmerBlock(height: 48, borderRadius: 12),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                  flex: 3,
                  child: ShimmerBlock(height: 52, borderRadius: 12)),
              SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: ShimmerBlock(height: 52, borderRadius: 12)),
            ],
          ),

          const SizedBox(height: 32),
          const ShimmerBlock(height: 52, borderRadius: 12),
        ],
      ),
    );
  }

  static Widget _shimmerSectionHeader() {
    return Row(
      children: [
        const ShimmerBlock(width: 18, height: 18, borderRadius: 4),
        const SizedBox(width: 8),
        const ShimmerBlock(width: 120, height: 14, borderRadius: 4),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1.5, color: const Color(0xFFE0E0E0)),
        ),
      ],
    );
  }
}
