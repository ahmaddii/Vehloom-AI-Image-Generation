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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late AnimationController _dotsController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;
  late Animation<double> _glowScale;

  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  late Animation<double> _captionOpacity;
  late Animation<Offset> _captionSlide;

  late Animation<double> _dotsOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Glow pulse loops independently, gives a "breathing" premium feel
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _glowOpacity = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowScale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Logo: soft bounce-in pop, feels alive not mechanical
    _logoScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.75,
              end: 1.06,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 65,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.06,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 35,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.45),
          ),
        );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Title slides up + fades in, starts once logo has mostly settled
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    // Caption follows shortly after title, small stagger
    _captionSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _captionOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    // Loading dots fade in last, bottom of screen
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2700), () {
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
    _glowController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final progress = (_dotsController.value - (index * 0.2)) % 1.0;
        final scale = progress < 0.5
            ? 0.6 + (progress * 2 * 0.6)
            : 1.2 - ((progress - 0.5) * 2 * 0.6);
        return Transform.scale(
          scale: scale.clamp(0.6, 1.2),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.creamBg,
        body: SizedBox.expand(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _controller,
              _glowController,
              _dotsController,
            ]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Soft pulsing glow behind logo
                  Transform.scale(
                    scale: _glowScale.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(
                              alpha: _glowOpacity.value * 0.35,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Logo + text column, centered as a unit
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Image.asset(
                            'assets/native_splashlogo/SplashLogo.png',
                            width: 150,
                            height: 150,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SlideTransition(
                        position: _textSlide,
                        child: Opacity(
                          opacity: _textOpacity.value,
                          child: Text(
                            'Vehloom',
                            style: GoogleFonts.inter(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SlideTransition(
                        position: _captionSlide,
                        child: Opacity(
                          opacity: _captionOpacity.value,
                          child: Text(
                            'Where Creativity Blooms',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Loading dots, bottom of screen
                  Positioned(
                    bottom: 60,
                    child: Opacity(
                      opacity: _dotsOpacity.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, _buildDot),
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
