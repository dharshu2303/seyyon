import 'package:flutter/material.dart';

class VelIcon extends StatelessWidget {
  final double size;
  final Color color;

  const VelIcon({super.key, this.size = 32, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VelPainter(color: color),
      ),
    );
  }
}

class _VelPainter extends CustomPainter {
  final Color color;

  _VelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Spearhead (leaf / flame shape) ──
    // The vel head is a pointed leaf shape taking top ~55% of height
    final headTop = h * 0.02;
    final headBottom = h * 0.55;
    final headWidth = w * 0.32;

    final headPath = Path();
    // Start at the sharp tip
    headPath.moveTo(cx, headTop);
    // Right curve of the leaf
    headPath.cubicTo(
      cx + headWidth * 0.3, h * 0.12, // control point 1
      cx + headWidth, h * 0.30, // control point 2 (widest bulge)
      cx + headWidth * 0.6, headBottom, // end at bottom-right
    );
    // Bottom curve inward to center
    headPath.quadraticBezierTo(
      cx, headBottom - h * 0.04, // slight upward curve
      cx - headWidth * 0.6, headBottom, // bottom-left
    );
    // Left curve of the leaf (mirror)
    headPath.cubicTo(
      cx - headWidth, h * 0.30, // control point 2
      cx - headWidth * 0.3, h * 0.12, // control point 1
      cx, headTop, // back to tip
    );
    headPath.close();
    canvas.drawPath(headPath, paint);

    // ── Center ridge line on the spearhead ──
    final ridgePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, headTop + h * 0.06),
      Offset(cx, headBottom - h * 0.04),
      ridgePaint,
    );

    // ── Small decorative guard / collar where head meets shaft ──
    final guardY = headBottom + h * 0.01;
    final guardW = w * 0.12;
    final guardPath = Path();
    guardPath.moveTo(cx - guardW, guardY);
    guardPath.lineTo(cx + guardW, guardY);
    guardPath.lineTo(cx + guardW * 0.7, guardY + h * 0.025);
    guardPath.lineTo(cx - guardW * 0.7, guardY + h * 0.025);
    guardPath.close();
    canvas.drawPath(guardPath, paint);

    // ── Shaft ──
    final shaftTop = guardY + h * 0.025;
    final shaftBottom = h * 0.96;
    final shaftWidth = w * 0.05;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - shaftWidth, shaftTop, cx + shaftWidth, shaftBottom),
        Radius.circular(shaftWidth),
      ),
      paint,
    );

    // ── Bottom tip of shaft ──
    final tipPath = Path();
    tipPath.moveTo(cx - shaftWidth * 1.5, shaftBottom - h * 0.01);
    tipPath.lineTo(cx, h * 0.99);
    tipPath.lineTo(cx + shaftWidth * 1.5, shaftBottom - h * 0.01);
    tipPath.close();
    canvas.drawPath(tipPath, paint);
  }

  @override
  bool shouldRepaint(covariant _VelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
