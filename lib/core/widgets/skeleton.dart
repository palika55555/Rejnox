import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Kostra zoznamu počas načítania. Drží rozloženie, aby obsah po načítaní
/// neposkočil, a jemne pulzuje (bez pulzu pri vypnutých animáciách).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Načítava sa',
      liveRegion: true,
      child: ExcludeSemantics(
        child: _Pulse(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding:
                padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => SkeletonTile(lineWidth: i.isEven ? .7 : .5),
          ),
        ),
      ),
    );
  }
}

/// Riadok kostry: kruh (avatar) a dva pruhy textu.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.lineWidth = .7});

  /// Šírka prvého riadku ako podiel dostupnej šírky.
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const _Bone(width: 44, height: 44, circle: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: c.maxWidth * lineWidth, height: 14),
                  const SizedBox(height: AppSpacing.sm),
                  _Bone(width: c.maxWidth * .9, height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.circle = false});

  final double width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHi,
        borderRadius: BorderRadius.circular(circle ? height : AppRadius.xs),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: .55,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}
