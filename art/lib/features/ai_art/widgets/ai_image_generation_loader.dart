import 'dart:math' as math;
import 'package:flutter/material.dart';

class AIImageGenerationLoader extends StatefulWidget {
  final double width;
  final double height;
  final Color backgroundColor;
  final Color dotColor;
  final double dotSpacing;
  final double animationSpeed;

  const AIImageGenerationLoader({
    Key? key,
    this.width = double.infinity,
    this.height = 300,
    this.backgroundColor = const Color(0xFF2B2727),
    this.dotColor = const Color(0x47FFFFFF), // rgba(255,255,255,0.28)
    this.dotSpacing = 16.0,
    this.animationSpeed = 1.0,
  }) : super(key: key);

  @override
  State<AIImageGenerationLoader> createState() =>
      _AIImageGenerationLoaderState();
}

class _AIImageGenerationLoaderState extends State<AIImageGenerationLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (6000 / widget.animationSpeed).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Abstract faint texture background could be added here
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final renderWidth = constraints.maxWidth.isInfinite ? 400.0 : constraints.maxWidth;
                  final renderHeight = constraints.maxHeight.isInfinite ? 800.0 : constraints.maxHeight;
                  
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(renderWidth, renderHeight),
                        painter: _DotMatrixPainter(
                          progress: _controller.value,
                          dotColor: widget.dotColor,
                          dotSpacing: widget.dotSpacing,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Positioned(
              top: 20,
              left: 20,
              child: Text(
                'Creating image',
                style: TextStyle(
                  fontFamily: 'Inter', // Fallback to system font if not loaded
                  color: Color(0xFFE8E8E8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final double progress;
  final Color dotColor;
  final double dotSpacing;

  _DotMatrixPainter({
    required this.progress,
    required this.dotColor,
    required this.dotSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final t = progress * math.pi * 2;

    int cols = (size.width / dotSpacing).ceil() + 1;
    int rows = (size.height / dotSpacing).ceil() + 1;

    // Safety fallback to prevent ANRs due to layout infinity
    if (cols > 100) cols = 100;
    if (rows > 100) rows = 100;

    double offsetX = (size.width - ((cols - 1) * dotSpacing)) / 2;
    double offsetY = (size.height - ((rows - 1) * dotSpacing)) / 2;

    final int r = dotColor.red;
    final int g = dotColor.green;
    final int b = dotColor.blue;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        double px = offsetX + x * dotSpacing;
        double py = offsetY + y * dotSpacing;

        double nx = x / cols;
        double ny = y / rows;

        double w1 = math.sin(nx * 5.0 + ny * 4.0 - t * 2.0);
        double w2 = math.sin(nx * -3.0 + ny * 6.0 + t * 1.5);
        double w3 = math.sin(nx * 2.0 + ny * -2.0 - t);

        double noise = (w1 + w2 + w3) / 3.0; 
        noise = (noise + 1.0) / 2.0; 

        noise = noise * noise * (3 - 2 * noise);

        double radius = 1.0 + noise * 2.5;

        double opacity = 0.12 + noise * (0.45 - 0.12);

        paint.color = Color.fromRGBO(r, g, b, opacity);

        canvas.drawCircle(Offset(px, py), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
