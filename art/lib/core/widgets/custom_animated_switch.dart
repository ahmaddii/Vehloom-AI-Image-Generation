import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAnimatedSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? activeIcon;
  final IconData? inactiveIcon;
  final Color activeColor;

  const CustomAnimatedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeIcon,
    this.inactiveIcon,
    this.activeColor = AppColors.coral,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 56,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? activeColor : AppColors.creamDark,

        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: value ? 28 : 2,
              right: value ? 2 : 28,
              top: 2,
              bottom: 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.creamBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: activeIcon != null || inactiveIcon != null
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return RotationTransition(
                            turns: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          value ? activeIcon : inactiveIcon,
                          key: ValueKey<bool>(value),
                          size: 14,
                          color: value ? activeColor : AppColors.darkGrey,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
