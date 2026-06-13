import 'package:flutter/material.dart';

/// "Field & Glory" temasının futbol sahası çizgisi dokusunu çizen arka plan.
///
/// Tasarımdaki gibi çok düşük opaklıkta yatay çizgiler + üstte hafif bir
/// vinyet (vignette) efekti uygular. Renkleri temadan alır.
class PitchPatternBackground extends StatelessWidget {
  const PitchPatternBackground({
    super.key,
    this.child,
    this.lineSpacing = 40,
  });

  final Widget? child;

  /// Çizgiler arası dikey boşluk (logical piksel).
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.2,
          colors: [
            scheme.surface,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _PitchLinePainter(
          lineColor: scheme.onSurface.withValues(alpha: 0.03),
          spacing: lineSpacing,
        ),
        child: child,
      ),
    );
  }
}

class _PitchLinePainter extends CustomPainter {
  _PitchLinePainter({required this.lineColor, required this.spacing});

  final Color lineColor;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchLinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.spacing != spacing;
}
