import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preferences_service.dart';

class AuthOptionsScreen extends StatefulWidget {
  const AuthOptionsScreen({super.key});

  @override
  State<AuthOptionsScreen> createState() => _AuthOptionsScreenState();
}

class _AuthOptionsScreenState extends State<AuthOptionsScreen>
    with TickerProviderStateMixin {
  final List<String> _nftImages = [
    'assets/auth_options/auth1.png',
    'assets/auth_options/auth2.png',
    'assets/auth_options/auth3.jpg',
    'assets/auth_options/auth4.png',
    'assets/onboarding3/4.jpg',
    'assets/onboarding3/6.jpg',
  ];

  late ScrollController _scrollController;
  late Ticker _ticker;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Staggered animations for different elements
  late final AnimationController _staggerController;
  late final Animation<double> _headingAnimation;
  late final Animation<double> _subtitleAnimation;
  late final Animation<double> _emailButtonAnimation;
  late final Animation<double> _socialButtonsAnimation;
  late final Animation<double> _footerAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker((elapsed) {
      if (_scrollController.hasClients) {
        final double targetOffset = elapsed.inMicroseconds * (10.0 / 1000000.0);
        _scrollController.jumpTo(targetOffset);
      }
    });
    _ticker.start();

    // Main entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();

    // Staggered animations for content elements
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _subtitleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
      ),
    );

    _emailButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
      ),
    );

    _socialButtonsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
      ),
    );

    _footerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.6, 0.95, curve: Curves.easeOut),
      ),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    _entranceController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic theme colors
    final textColor = AppColors.black;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = AppColors.creamBg;
    final surfaceColor = AppColors.creamLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: PreferencesService().darkModeEnabled
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Top Grid of Images with Overlay
            Positioned(
              top: -80,
              left: -50,
              right: -50,
              height: MediaQuery.of(context).size.height * 0.65,
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
                        borderRadius: BorderRadius.circular(18),
                        image: DecorationImage(
                          image: AssetImage(
                            _nftImages[index % _nftImages.length],
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Gradient Fade to Black - more sophisticated
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColor.withOpacity(0.0),
                      bgColor.withOpacity(0.15),
                      bgColor.withOpacity(0.4),
                      bgColor.withOpacity(0.7),
                      bgColor.withOpacity(0.95),
                      bgColor,
                    ],
                    stops: const [0.0, 0.3, 0.45, 0.6, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Content on top
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Staggered Header Animation
                        FadeTransition(
                          opacity: _headingAnimation,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              20 * (1 - _headingAnimation.value),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Let\'s Get Started',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: textColor,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Staggered Subtitle Animation
                        FadeTransition(
                          opacity: _subtitleAnimation,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              16 * (1 - _subtitleAnimation.value),
                            ),
                            child: Text(
                              'Join a community of AI artists and collectors.',
                              style: TextStyle(
                                fontSize: 15.5,
                                color: textColor.withOpacity(0.7),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Staggered Email Button Animation
                        FadeTransition(
                          opacity: _emailButtonAnimation,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              16 * (1 - _emailButtonAnimation.value),
                            ),
                            child: _premiumButton(
                              height: 56,
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              icon: Icons.mail_outline_rounded,
                              label: 'Continue with Email',
                              onPressed: () => context.push('/signup'),
                              shadowColor: primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Staggered Social Buttons Animation
                        FadeTransition(
                          opacity: _socialButtonsAnimation,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              12 * (1 - _socialButtonsAnimation.value),
                            ),
                            child: Column(
                              children: [
                                // Google Button
                                _socialButton(
                                  leading: Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textColor.withOpacity(0.85),
                                    ),
                                  ),
                                  label: 'Continue with Google',
                                  textColor: textColor,
                                  surfaceColor: surfaceColor,
                                  onTap: () {},
                                ),

                                const SizedBox(height: 12),

                                // Apple Button
                                _socialButton(
                                  leading: Icon(
                                    Icons.apple,
                                    size: 22,
                                    color: textColor.withOpacity(0.85),
                                  ),
                                  label: 'Continue with Apple',
                                  textColor: textColor,
                                  surfaceColor: surfaceColor,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Staggered Footer Animation
                        FadeTransition(
                          opacity: _footerAnimation,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              12 * (1 - _footerAnimation.value),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account ? ',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/login'),
                                  child: Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumButton({
    required double height,
    required Color backgroundColor,
    required Color foregroundColor,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color shadowColor,
  }) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shadowColor: shadowColor.withOpacity(0.4),
          side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: foregroundColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton({
    required Widget leading,
    required String label,
    required Color textColor,
    required Color surfaceColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          side: BorderSide(color: textColor.withOpacity(0.2), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: surfaceColor.withOpacity(0.7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
