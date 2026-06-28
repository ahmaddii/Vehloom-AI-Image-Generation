import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../data/repositories/auth_repository.dart';

class OnboardingScreen3 extends StatefulWidget {
  const OnboardingScreen3({super.key});

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3>
    with SingleTickerProviderStateMixin {
  final List<String> _nftImages = [
    'assets/onboarding3/1.jpg',
    'assets/onboarding3/2.png',
    'assets/onboarding3/3.jpg',
    'assets/onboarding3/4.jpg',
    'assets/onboarding3/5.jpg',
    'assets/onboarding3/6.jpg',
    'assets/onboarding3/7.jpg',
    'assets/onboarding3/8.jpg',
    'assets/onboarding3/9.jpg',
    'assets/onboarding3/10.jpg',
    'assets/onboarding3/11.jpg',
    'assets/onboarding3/12.jpg',
  ];

  double _dragPosition = 0.0;
  bool _isDragging = false;
  late ScrollController _scrollController;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker((elapsed) {
      if (_scrollController.hasClients) {
        // Scroll exactly 10 pixels per second regardless of frame rate
        final double targetOffset = elapsed.inMicroseconds * (10.0 / 1000000.0);
        _scrollController.jumpTo(targetOffset);
      }
    });
    _ticker.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthRepository().currentUser != null) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: PreferencesService().darkModeEnabled ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.creamBg,
        body: Stack(
          children: [
            // Top Grid of Images
            Positioned(
              top: -80,
              left: -50,
              right: -50,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Transform.rotate(
                angle: -0.15,
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: AssetImage(
                            _nftImages[index % _nftImages.length],
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Gradient Fade to Black
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.creamBg.withValues(alpha: 0.0),
                      AppColors.creamBg.withValues(alpha: 0.2),
                      AppColors.creamBg.withValues(alpha: 0.8),
                      AppColors.creamBg,
                      AppColors.creamBg,
                    ],
                    stops: const [0.0, 0.35, 0.55, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Text and Button Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore\nInspire &\nConnect',
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Join a global community of artists.\nShare your masterpieces with the world.',
                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.7),
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Slider Button
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const double capsuleWidth = 152.0;
                        final double maxDrag =
                            constraints.maxWidth -
                            capsuleWidth -
                            8; // 8 is padding

                        return Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.creamLight,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: Stack(
                            children: [
                              // Background Chevrons
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const AnimatedChevrons(),
                                ),
                              ),

                              // Draggable Capsule
                              AnimatedPositioned(
                                duration: Duration(
                                  milliseconds: _isDragging ? 0 : 300,
                                ),
                                curve: Curves.easeOutCubic,
                                left: _dragPosition + 4, // 4 padding from left
                                top: 4,
                                bottom: 4,
                                child: GestureDetector(
                                  onHorizontalDragStart: (_) {
                                    setState(() {
                                      _isDragging = true;
                                    });
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    setState(() {
                                      _dragPosition += details.delta.dx;
                                      if (_dragPosition < 0) _dragPosition = 0;
                                      if (_dragPosition > maxDrag)
                                        _dragPosition = maxDrag;
                                    });
                                  },
                                  onHorizontalDragEnd: (details) {
                                    setState(() {
                                      _isDragging = false;
                                      if (_dragPosition > maxDrag * 0.75) {
                                        // Snap to end and navigate
                                        _dragPosition = maxDrag;
                                        Future.delayed(
                                          const Duration(milliseconds: 200),
                                          () {
                                            if (!context.mounted) return;
                                            context.go('/auth-options');
                                          },
                                        );
                                      } else {
                                        // Snap back to start
                                        _dragPosition = 0.0;
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: capsuleWidth,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.black,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'Get Started',
                                      style: TextStyle(
                                        color: AppColors.creamBg,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedChevrons extends StatefulWidget {
  const AnimatedChevrons({super.key});

  @override
  State<AnimatedChevrons> createState() => _AnimatedChevronsState();
}

class _AnimatedChevronsState extends State<AnimatedChevrons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            double opacity = 0.3;

            double progress = (_controller.value - delay);
            if (progress < 0) progress += 1.0;

            if (progress < 0.4) {
              opacity = 0.3 + (progress / 0.4) * 0.7;
            } else if (progress < 0.8) {
              opacity = 1.0 - ((progress - 0.4) / 0.4) * 0.7;
            }

            return Icon(
              Icons.chevron_right,
              color: AppColors.black.withValues(alpha: opacity.clamp(0.3, 1.0)),
              size: 24,
            );
          }),
        );
      },
    );
  }
}
