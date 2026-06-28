import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import 'custom_add_button.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight,
        border: Border(top: BorderSide(color: AppColors.lightGrey, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(
              context,
              assetPath: 'assets/icons/home.png',
              label: 'Home',
              index: 0,
              route: '/',
            ),
            _buildNavItem(
              context,
              icon: currentIndex == 1 ? Icons.search : Icons.search_outlined,
              label: 'Discovery',
              index: 1,
              route: '/search',
            ),

            // Upload Button
            GestureDetector(
              onTap: () => context.push('/upload'),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: CustomAddButton(),
              ),
            ),

            _buildNavItem(
              context,
              assetPath: 'assets/icons/trophy.png',
              label: 'Top',
              index: 3,
              route: '/top-art',
            ),
            _buildNavItem(
              context,
              assetPath: 'assets/icons/profile.png',
              label: 'Profile',
              index: 4,
              route: '/profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    IconData? icon,
    String? assetPath,
    required String label,
    required int index,
    required String route,
  }) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath,
                width: 22,
                height: 22,
                color: isActive ? AppColors.coral : AppColors.black,
              )
            else if (icon != null)
              Icon(
                icon,
                color: isActive ? AppColors.coral : AppColors.black,
                size:
                    26, // Increased slightly to match the visual weight of the PNGs
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? AppColors.coral : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
