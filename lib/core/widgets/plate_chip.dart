import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Štítok vo farbe kotúča (napr. "Drep 4×6").
class PlateChip extends StatelessWidget {
  const PlateChip(this.label, {super.key, this.plate});

  final String label;

  /// Bez kotúča = neutrálny štítok (napr. "+2 cviky").
  final Plate? plate;

  @override
  Widget build(BuildContext context) {
    final color = plate?.color ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plate != null) ...[PlateDot(plate!), const SizedBox(width: 6)],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PlateDot extends StatelessWidget {
  const PlateDot(this.plate, {super.key, this.size = 7});

  final Plate plate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: plate.color, shape: BoxShape.circle),
    );
  }
}
