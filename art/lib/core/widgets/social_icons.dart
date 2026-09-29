import 'package:flutter/material.dart';

/// Authentic Instagram gradient logo icon widget.
class InstagramLogoIcon extends StatelessWidget {
  final double size;

  const InstagramLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final strokeWidth = size * 0.085;
    final lensSize = size * 0.32;
    final dotSize = size * 0.09;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Gradient (Official Instagram Brand Colors)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xFFF9CE34), // Yellow
                  Color(0xFFEE2A7B), // Pink/Red
                  Color(0xFF6228D7), // Purple
                ],
              ),
            ),
          ),
          // Outer Camera Frame
          Container(
            width: size * 0.68,
            height: size * 0.68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.2),
              border: Border.all(color: Colors.white, width: strokeWidth),
            ),
          ),
          // Lens Circle
          Container(
            width: lensSize,
            height: lensSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: strokeWidth),
            ),
          ),
          // Top Right Flash Dot
          Positioned(
            top: size * 0.24,
            right: size * 0.24,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Authentic Website / Globe gradient icon widget.
class WebsiteGlobeIcon extends StatelessWidget {
  final double size;

  const WebsiteGlobeIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0072FF), // Vibrant Blue
            Color(0xFF00C6FF), // Cyan
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.language_rounded,
          color: Colors.white,
          size: size * 0.68,
        ),
      ),
    );
  }
}
