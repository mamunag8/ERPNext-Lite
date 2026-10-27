import 'package:flutter/material.dart';

/// Official ERPNext vector logo rendered with CustomPaint using the exact
/// Frappe / ERPNext SVG geometry (`viewBox="0 0 118 118"`).
class ErpNextLogo extends StatelessWidget {
  const ErpNextLogo({
    super.key,
    this.size = 40,
    this.backgroundColor = const Color(0xFF0089FF),
    this.foregroundColor = Colors.white,
    this.borderRadius,
  });

  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ErpNextLogoPainter(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _ErpNextLogoPainter extends CustomPainter {
  const _ErpNextLogoPainter({
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderRadius,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final double? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double scaleX = w / 118.0;
    final double scaleY = h / 118.0;
    final double r = borderRadius ?? (w * (22.0 / 118.0));

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(r)),
      bgPaint,
    );

    final Paint fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Official ERPNext top horizontal bar:
    // M78.8631 38.557 H38.6199 V28.0872 H78.8631 V38.557 Z
    final Rect topBar = Rect.fromLTRB(
      38.6199 * scaleX,
      28.0872 * scaleY,
      78.8631 * scaleX,
      38.5570 * scaleY,
    );
    canvas.drawRect(topBar, fgPaint);

    // Official ERPNext lower 'E' stem & bars:
    // M38.6199 52.6257 H76.9 V63.0955 H51.3799 V77.4915 H79.1903 V87.9612 H38.6199 Z
    final Path lowerE = Path()
      ..moveTo(38.6199 * scaleX, 52.6257 * scaleY)
      ..lineTo(76.9000 * scaleX, 52.6257 * scaleY)
      ..lineTo(76.9000 * scaleX, 63.0955 * scaleY)
      ..lineTo(51.3799 * scaleX, 63.0955 * scaleY)
      ..lineTo(51.3799 * scaleX, 77.4915 * scaleY)
      ..lineTo(79.1903 * scaleX, 77.4915 * scaleY)
      ..lineTo(79.1903 * scaleX, 87.9612 * scaleY)
      ..lineTo(38.6199 * scaleX, 87.9612 * scaleY)
      ..close();
    canvas.drawPath(lowerE, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ErpNextLogoPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}
