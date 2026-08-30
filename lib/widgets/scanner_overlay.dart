import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  final Color color;
  final bool active;

  const ScannerOverlay({
    super.key,
    this.color = const Color(0xFF2DD4BF),
    this.active = true,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = widget.active ? _controller.value : 0.0;
        return CustomPaint(
          painter: _CornerBracketPainter(
            color: widget.color,
            pulse: pulse,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double pulse;

  _CornerBracketPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = Size(size.width * 0.72, size.width * 0.72);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize.width,
      height: frameSize.height,
    );

    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final backdrop = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, backdrop, hole),
      scrimPaint,
    );

    final glowOpacity = 0.45 + (pulse * 0.4);
    final bracketPaint = Paint()
      ..color = color.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final len = rect.width * 0.16;
    final r = 20.0;

    void corner(Offset origin, double dx, double dy) {
      final path = Path();
      if (dx > 0 && dy > 0) {
        path.moveTo(origin.dx, origin.dy + len);
        path.lineTo(origin.dx, origin.dy + r);
        path.quadraticBezierTo(
            origin.dx, origin.dy, origin.dx + r, origin.dy);
        path.lineTo(origin.dx + len, origin.dy);
      } else if (dx < 0 && dy > 0) {
        path.moveTo(origin.dx, origin.dy + len);
        path.lineTo(origin.dx, origin.dy + r);
        path.quadraticBezierTo(
            origin.dx, origin.dy, origin.dx - r, origin.dy);
        path.lineTo(origin.dx - len, origin.dy);
      } else if (dx > 0 && dy < 0) {
        path.moveTo(origin.dx, origin.dy - len);
        path.lineTo(origin.dx, origin.dy - r);
        path.quadraticBezierTo(
            origin.dx, origin.dy, origin.dx + r, origin.dy);
        path.lineTo(origin.dx + len, origin.dy);
      } else {
        path.moveTo(origin.dx, origin.dy - len);
        path.lineTo(origin.dx, origin.dy - r);
        path.quadraticBezierTo(
            origin.dx, origin.dy, origin.dx - r, origin.dy);
        path.lineTo(origin.dx - len, origin.dy);
      }
      canvas.drawPath(path, bracketPaint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    // Scanning line sweep.
    final lineY = rect.top + rect.height * pulse;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(rect.left, lineY - 1, rect.width, 2));
    canvas.drawRect(Rect.fromLTWH(rect.left, lineY - 1, rect.width, 2), linePaint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.color != color;
}
