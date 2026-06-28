import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _captionOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Subtle scale bounce for the logo
    _logoScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 1.05,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.05,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
        );

    // Logo slides up from center
    // We will use an animation value from 0.0 to 1.0 and multiply it by pixels
    _logoSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1.0))
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    // Text slides up
    _textSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1.0))
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    // Caption fades in slowly
    _captionOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Wait for animation to finish, plus a short hold, then navigate
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    if (isLoggedIn) {
      context.go('/');
    } else {
      context.go('/onboarding1');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.creamBg,
        body: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Logo
                  Transform.translate(
                    // move up by up to 80 pixels
                    offset: Offset(0, -80 * _logoSlide.value.dy),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Image.asset(
                        'assets/native_splashlogo/SplashLogo.png',
                        width: 150,
                        height: 150,
                      ),
                    ),
                  ),

                  // Text and Caption
                  Transform.translate(
                    // starts 80 pixels lower, moves up to 90 pixels below center
                    offset: Offset(0, 120 - (30 * _textSlide.value.dy)),
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ArtSharing',
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: _captionOpacity.value,
                            child: Text(
                              'Discover & Share Masterpieces',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
