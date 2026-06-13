import 'package:flutter/material.dart';

/// Competra marka logo rozeti: hafif parlayan, içinde futbol topu ikonu olan
/// bir kap. Splash ve auth ekranları arasında görsel tutarlılık sağlar.
///
/// [borderRadius] `null` verilirse tam yuvarlak çizilir.
class BrandLogoBadge extends StatelessWidget {
  const BrandLogoBadge({
    super.key,
    this.size = 64,
    this.borderRadius = 16,
  });

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = borderRadius == null
        ? BoxShape.circle
        : BoxShape.rectangle;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        color: scheme.surface,
        borderRadius:
            borderRadius == null ? null : BorderRadius.circular(borderRadius!),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.secondary.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.sports_soccer,
        size: size * 0.5,
        color: scheme.secondary,
      ),
    );
  }
}
