import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';

class OnboardingScreen1 extends StatefulWidget {
  const OnboardingScreen1({super.key});

  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthRepository().currentUser != null) {
        context.go('/');
      } else {
        // Precache the heavy images for the 3rd screen in the background
        for (int i = 1; i <= 12; i++) {
          final ext = i == 2 ? 'png' : 'jpg';
          precacheImage(AssetImage('assets/onboarding3/$i.$ext'), context);
        }
      }
    });
  }

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Discover Beautiful and Amazing Illustrations',
      'subtitle':
          'Explore unique artwork from talented creators around the world, all in one inspiring place.',
      'type': 'single',
      'image': 'assets/onboarding1/onboard1.png',
    },
    {
      'title': 'Share Your Creativity With the World',
      'subtitle':
          'Upload your illustrations and showcase your talent to a global audience.',
      'type': 'grid',
      'images': [
        'assets/onboarding2/first.png',
        'assets/onboarding2/second.png',
        'assets/onboarding2/third.png',
        'assets/onboarding2/fourth.png',
      ],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Page View for illustrations
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 64,
                        ),
                        child: Column(
                          children: [
                            // Image Container
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: slide['type'] == 'single'
                                    ? Image.asset(
                                        slide['image'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : Center(
                                        child: GridView.builder(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                                childAspectRatio:
                                                    0.9, // Make images slightly taller to fill space nicely
                                              ),
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: 4,
                                          itemBuilder: (context, gridIndex) {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Image.asset(
                                                slide['images'][gridIndex],
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Text Content
                            Text(
                              slide['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                slide['subtitle'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.black.withValues(alpha: 0.6),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Page Indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_slides.length, (
                                dotIndex,
                              ) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  height: 6,
                                  width: dotIndex == _currentPage ? 24 : 8,
                                  decoration: BoxDecoration(
                                    color: dotIndex == _currentPage
                                        ? AppColors.black
                                        : AppColors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: 48,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56, // Adjusted button height
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < _slides.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              // Go to the third screen (new NFT grid)
                              context.push('/onboarding3');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black,
                            foregroundColor: AppColors.creamLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage < _slides.length - 1
                                ? 'Next'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Skip Button
            Positioned(
              top: 0,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _currentPage == 0 ? 1.0 : 0.0,
                child: TextButton(
                  onPressed: () {
                    if (_currentPage == 0) {
                      context.push('/onboarding3');
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.black.withValues(alpha: 0.6),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
